import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class EnhancedNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const int _hourlyNotificationCount = 24;
  static const String _hourlyPrefKey = 'hourly_notifications_enabled';

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> setHourlyNotifications(bool enabled) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hourlyPrefKey, enabled);

    if (enabled) {
      await rescheduleHourlyNotifications();
    } else {
      await cancelHourlyNotifications();
    }
  }

  static Future<void> rescheduleHourlyNotifications() async {
    await cancelHourlyNotifications();

    final now = tz.TZDateTime.now(tz.local);
    for (int i = 1; i <= _hourlyNotificationCount; i++) {
      final scheduledTime = now.add(Duration(minutes: i));
      await _notificationsPlugin.zonedSchedule(
        i,
        'Take a moment to reflect 💭',
        'Your wellness check-in is here. How are you feeling?',
        tz.TZDateTime(tz.local, scheduledTime.year, scheduledTime.month,
            scheduledTime.day, scheduledTime.hour),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hourly_channel_id',
            'Hourly Notifications',
            channelDescription: 'Hourly wellness reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily at hour
      );
    }
  }

  static Future<void> cancelHourlyNotifications() async {
    for (int i = 1; i <= _hourlyNotificationCount; i++) {
      await _notificationsPlugin.cancel(i);
    }
  }

  static Future<void> checkAndRescheduleIfNeeded() async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    final hourlyPending = pending.where((n) => n.id <= _hourlyNotificationCount).length;

    if (hourlyPending < 12) {
      await rescheduleHourlyNotifications();
    }
  }

  static Future<Map<String, int>> getNotificationStats() async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    final hourly = pending.where((n) => n.id <= _hourlyNotificationCount).length;
    final quickReminders = pending.where((n) => n.id == 999).length;

    return {
      'hourly': hourly,
      'quickReminders': quickReminders,
      'total': pending.length,
    };
  }

  static Future<void> scheduleQuickTest() async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(minutes: 2));

    await _notificationsPlugin.zonedSchedule(
      999,
      'Test Notification 🚀',
      'This is a 2-minute test to confirm background delivery!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel_id',
          'Test Notifications',
          channelDescription: 'Temporary test reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
