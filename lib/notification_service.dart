import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

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

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Shows an immediate notification that a favorite team's match result is
  /// in. Uses its own Android channel, separate from the daily-summary
  /// reminders, so it isn't affected by [scheduleDailySummaries]'s
  /// cancelAll() and can be toggled independently in Settings.
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

  static Future<void> scheduleDailySummaries(
    List<Map<String, dynamic>> matches,
    TimeOfDay preferredTime,
  ) async {
    await cancelAll();

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
          );
        }
      }
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
  }) async {
    // SCHEDULE_EXACT_ALARM is a special permission on Android 13+ that the
    // user must separately grant (declaring it in the manifest isn't
    // enough) - without it, exactAllowWhileIdle throws. A daily summary
    // doesn't need to-the-minute precision, so just degrade to inexact
    // scheduling rather than crash.
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'match_reminders',
          'Match Reminders',
          channelDescription: 'Daily summary of volleyball matches',
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
