import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';

class HourlyNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // List of motivational messages for hourly notifications
  static const List<String> _motivationalMessages = [
    "Time to check in! Let's remember together 💙",
    "Your memories are waiting! Join us for a moment of reflection ✨",
    "Take a mindful break - let's create beautiful memories together 🌟",
    "Ready for some peaceful moments? Your journal is calling 📝",
    "Time for a gentle reminder - you're doing great! 💪",
    "Let's pause and reflect together - your wellness journey matters 🧘‍♀️",
    "A moment of mindfulness awaits you - join us! 🌸",
    "Your mental wellness check-in is ready - let's remember together 💚",
    "Time to nurture your mind - your Harmonia family is here! 🤗",
    "Take a breath, take a moment - let's reflect together 🌺",
    "Your daily dose of mindfulness is here! Ready to remember? 🕯️",
    "Mental wellness time! Let's create positive memories together 🌈",
    "Pause, breathe, remember - your journey continues with us 🦋",
    "Time for self-care! Your reflective moment awaits 💖",
    "Let's take a mindful break together - you deserve this time 🌙",
    "Your wellness companion is calling - ready to remember? ⭐",
    "Time to check in with yourself - we're here to support you 🤲",
    "A gentle reminder: you matter, and your memories do too 💝",
    "Mental health moment! Let's reflect and grow together 🌱",
    "Your peaceful pause is ready - join us for remembering 🕊️"
  ];

  // Initialize the notification service
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    await _createHourlyNotificationChannel();
  }

  // Create notification channel for hourly notifications
  static Future<void> _createHourlyNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'hourly_reminder_channel',
      'Hourly Wellness Reminders',
      description: 'Hourly motivational reminders to use the app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Schedule hourly notifications
  static Future<void> scheduleHourlyNotifications() async {
    // Cancel existing hourly notifications first
    await cancelHourlyNotifications();

    final now = DateTime.now();

    // Schedule notifications for the next 48 hours to ensure continuity
    for (int i = 1; i <= 48; i++) {
      final scheduledTime = now.add(Duration(hours: i));

      // Get a random motivational message
      final randomMessage = _motivationalMessages[
      Random().nextInt(_motivationalMessages.length)];

      await _scheduleHourlyNotification(
        id: 10000 + i,
        title: "Harmonia - Let's Remember Together",
        body: randomMessage,
        scheduledTime: scheduledTime,
      );
    }

    print('Scheduled 48 hourly notifications starting from: ${now.add(Duration(hours: 1))}');
  }

  // Schedule a single hourly notification
  static Future<void> _scheduleHourlyNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'hourly_reminder_channel',
        'Hourly Wellness Reminders',
        channelDescription: 'Hourly motivational reminders to use the app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(body),
        // These settings help with background delivery
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'hourly_reminder',
      );
    } catch (e) {
      print('Error scheduling hourly notification: $e');
    }
  }

  // Cancel all hourly notifications
  static Future<void> cancelHourlyNotifications() async {
    // Cancel notifications with IDs 10001 to 10048
    for (int i = 1; i <= 48; i++) {
      await _notificationsPlugin.cancel(10000 + i);
    }
    print('Cancelled all hourly notifications');
  }

  // Reschedule hourly notifications
  static Future<void> rescheduleHourlyNotifications() async {
    await scheduleHourlyNotifications();
  }

  // Check if we need to reschedule
  static Future<void> checkAndRescheduleIfNeeded() async {
    try {
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();

      final hourlyNotifications = pendingNotifications.where(
              (notification) => notification.id >= 10001 && notification.id <= 10048
      ).toList();

      // If we have less than 24 hourly notifications pending, reschedule
      if (hourlyNotifications.length < 24) {
        print('Rescheduling hourly notifications - only ${hourlyNotifications.length} pending');
        await rescheduleHourlyNotifications();
      } else {
        print('Hourly notifications are properly scheduled - ${hourlyNotifications.length} pending');
      }
    } catch (e) {
      print('Error checking notifications: $e');
      await rescheduleHourlyNotifications();
    }
  }

  // Enable or disable hourly notifications
  static Future<void> setHourlyNotifications(bool enabled) async {
    if (enabled) {
      await scheduleHourlyNotifications();
    } else {
      await cancelHourlyNotifications();
    }
  }
}