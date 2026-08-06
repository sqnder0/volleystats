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
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
