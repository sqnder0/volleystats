import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'persistence_service.dart';
import 'date_utils.dart' as date_utils;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Shows an immediate notification that a favorite team's match result is
  /// in. Uses its own Android channel, separate from the daily-summary and
  /// match-start-reminder notifications, so it can be toggled independently
  /// in Settings without affecting them.
  static Future<void> showResultNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'match_results',
          'Match Results',
          channelDescription: 'Notifies when a followed team has a new result',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Cancels only the daily-summary notifications (ids 0-6, one per day of
  /// the upcoming week) - never cancelAll(), which would also wipe out the
  /// independently-toggled result/match-start-reminder notifications.
  static Future<void> cancelDailySummaries() async {
    for (int i = 0; i < 7; i++) {
      await _notificationsPlugin.cancel(i);
    }
  }

  static Future<void> scheduleDailySummaries(
    List<Map<String, dynamic>> matches,
    TimeOfDay preferredTime,
  ) async {
    await cancelDailySummaries();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Group matches by date
    final Map<String, List<String>> groupedMatches = {};
    for (var match in matches) {
      final dateStr = match['time'] as String; // DD/MM/YYYY
      final teamName = match['fav_name'] as String;
      groupedMatches.putIfAbsent(dateStr, () => []).add(teamName);
    }

    // Schedule for the next 7 days
    for (int i = 0; i < 7; i++) {
      final scheduledDate = today.add(Duration(days: i));
      final dateStr =
          "${scheduledDate.day.toString().padLeft(2, '0')}/${scheduledDate.month.toString().padLeft(2, '0')}/${scheduledDate.year}";

      if (groupedMatches.containsKey(dateStr)) {
        final teams = groupedMatches[dateStr]!;
        final scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          preferredTime.hour,
          preferredTime.minute,
        );

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: i,
            title: i == 0 ? "Wedstrijddag!" : "Aankomende wedstrijden",
            body:
                "Vandaag ${teams.length} ${teams.length == 1 ? 'wedstrijd' : 'wedstrijden'}: ${teams.join(', ')}",
            scheduledDateTime: scheduledDateTime,
            channelId: 'daily_summary',
            channelName: 'Daily Summary',
            channelDescription: 'Daily summary of volleyball matches',
          );
        }
      }
    }
  }

  /// Cancels only currently-tracked match-start reminders (see
  /// [PersistenceService.loadMatchReminderIds]) - never cancelAll().
  static Future<void> cancelMatchReminders() async {
    final ids = await PersistenceService.loadMatchReminderIds();
    for (final id in ids) {
      await _notificationsPlugin.cancel(id);
    }
    await PersistenceService.saveMatchReminderIds([]);
  }

  /// Schedules a reminder [leadTime] before each upcoming match's start.
  /// Matches need a 'match_code' (unique id basis), 'date_obj' (a DateTime
  /// for the match's day), 'match_time' ("HH:MM"), 'fav_name', and
  /// 'result' (skipped if non-empty - already played).
  static Future<void> scheduleMatchReminders(
    List<Map<String, dynamic>> matches, {
    Duration leadTime = const Duration(hours: 2),
  }) async {
    await cancelMatchReminders();

    final now = DateTime.now();
    final newIds = <int>[];

    for (final match in matches) {
      final matchCode = match['match_code'] as String?;
      final date = match['date_obj'] as DateTime?;
      final time = match['match_time'] as String?;
      final result = match['result'] as String? ?? '';
      if (matchCode == null || matchCode.isEmpty) continue;
      if (date == null || time == null) continue;
      if (result.isNotEmpty) continue;

      final matchDateTime = date_utils.combineDateAndTime(date, time);
      if (matchDateTime == null) continue;

      final reminderTime = matchDateTime.subtract(leadTime);
      if (!reminderTime.isAfter(now)) continue;

      final id = ('reminder_$matchCode').hashCode & 0x7FFFFFFF;
      await _scheduleNotification(
        id: id,
        title: 'Binnenkort: ${match['fav_name']}',
        body:
            '${match['home_team']} - ${match['away_team']} om $time',
        scheduledDateTime: reminderTime,
        channelId: 'match_start_reminders',
        channelName: 'Match Reminders',
        channelDescription:
            'Reminds you shortly before a followed team\'s match starts',
      );
      newIds.add(id);
    }

    await PersistenceService.saveMatchReminderIds(newIds);
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    // SCHEDULE_EXACT_ALARM is a special permission on Android 13+ that the
    // user must separately grant (declaring it in the manifest isn't
    // enough) - without it, exactAllowWhileIdle throws. Neither a daily
    // summary nor a match reminder needs to-the-minute precision, so just
    // degrade to inexact scheduling rather than crash.
    final canScheduleExact =
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
