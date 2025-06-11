import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:io';

class EnhancedNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // List of motivational messages for 10-minute notifications
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
    "Your peaceful pause is ready - join us for remembering 🕊️",
    "Every 10 minutes is a new chance to remember and grow 🌱",
    "Quick wellness check! How are you feeling right now? 😊",
    "Your mental health journey continues - one step at a time 👣",
    "Time for a micro-meditation! Just breathe with us 🌊",
    "Small moments, big impact - let's reflect together 💫",
    "Your wellness reminder is here - you're worth this time ⏰",
    "Quick mindfulness moment! Join us for inner peace 🕉️",
    "Every 10 minutes brings new possibilities - embrace them! 🌅",
    "Short break, lasting impact - your mind deserves care 🧠",
    "Frequent wellness checks keep you thriving! 🌺"
  ];

  // Initialize the enhanced notification service
  static Future<void> initialize() async {
    print('🔧 Initializing Enhanced 10-Minute Notification Service...');

    // Request all necessary permissions first
    await _requestAllPermissions();

    // Enhanced Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Enhanced iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // For critical alerts
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 10-minute notification tapped: ${response.payload}');
        _handleNotificationTap(response);
      },
    );

    await _createEnhancedNotificationChannels();

    // Test immediate notification
    await _testImmediateNotification();

    print('✅ Enhanced 10-Minute Notification Service initialized');
  }

  // Request all necessary permissions for background notifications
  static Future<void> _requestAllPermissions() async {
    print('🔐 Requesting all necessary permissions for 10-minute notifications...');

    if (Platform.isAndroid) {
      // Request notification permission for Android 13+
      final notificationStatus = await Permission.notification.status;
      print('📱 Notification permission status: $notificationStatus');
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }

      // Request exact alarm permission for Android 12+
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      print('⏰ Exact alarm permission status: $alarmStatus');
      if (!alarmStatus.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }

      // Request battery optimization exemption
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      print('🔋 Battery optimization status: $batteryStatus');
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    if (Platform.isIOS) {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
      print('🍎 iOS notification permissions result: $result');
    }
  }

  // Handle notification tap
  static void _handleNotificationTap(NotificationResponse response) {
    final actionId = response.actionId;

    if (actionId == 'open_app') {
      print('📱 User chose to open app from notification');
      // Handle opening the app
    } else if (actionId == 'snooze_10') {
      print('⏰ User chose to snooze for 10 minutes');
      // Handle snooze functionality
    } else {
      print('👆 Regular notification tap - opening app');
      // Handle regular tap
    }
  }

  // Create enhanced notification channels
  static Future<void> _createEnhancedNotificationChannels() async {
    print('📺 Creating enhanced 10-minute notification channels...');

    // High-frequency wellness channel
    const AndroidNotificationChannel wellnessChannel = AndroidNotificationChannel(
      'wellness_10min_channel',
      '10-Minute Wellness Reminders',
      description: 'Frequent wellness check-ins every 10 minutes',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Critical wellness channel for important reminders
    const AndroidNotificationChannel criticalWellnessChannel = AndroidNotificationChannel(
      'wellness_critical_channel',
      'Critical Wellness Reminders',
      description: 'Important wellness reminders that bypass Do Not Disturb',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(wellnessChannel);
    await androidImplementation?.createNotificationChannel(criticalWellnessChannel);

    print('✅ Enhanced 10-minute notification channels created');
  }

  // Test immediate notification
  static Future<void> _testImmediateNotification() async {
    print('🧪 Testing immediate 10-minute notification...');
    try {
      await _notificationsPlugin.show(
        99999,
        '🌟 Harmonia Wellness Ready',
        '✅ 10-minute wellness reminders are active!\n🔔 You\'ll receive gentle reminders every 10 minutes, even when the app is closed.\n\n💡 Close the app to test background delivery!',
        _buildEnhancedNotificationDetails(
          '🌟 Your wellness journey starts now!\n\n✅ 10-minute reminders: ACTIVE\n🔔 Background delivery: ENABLED\n💙 Mental health support: READY\n\n💡 Tip: Close the app and wait for your next reminder!',
          isCritical: true,
        ),
      );
      print('✅ Immediate 10-minute notification sent successfully');
    } catch (e) {
      print('❌ Error sending immediate notification: $e');
    }
  }

  // Build enhanced notification details
  static NotificationDetails _buildEnhancedNotificationDetails(
      String content, {
        bool isCritical = false,
      }) {
    final channelId = isCritical ? 'wellness_critical_channel' : 'wellness_10min_channel';
    final channelName = isCritical ? 'Critical Wellness Reminders' : '10-Minute Wellness Reminders';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '10-minute wellness reminder notifications',
        importance: isCritical ? Importance.max : Importance.high,
        priority: isCritical ? Priority.max : Priority.high,
        ticker: 'Harmonia Wellness',
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        enableVibration: true,
        playSound: true,
        autoCancel: false, // Keep notification visible
        ongoing: isCritical, // Makes critical notifications persistent

        // Enhanced visibility settings
        fullScreenIntent: isCritical,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,

        // Rich content styling
        styleInformation: BigTextStyleInformation(
          content,
          htmlFormatBigText: false,
          contentTitle: '🌟 Harmonia Wellness',
          htmlFormatContentTitle: false,
          summaryText: 'Tap for mindful moment',
        ),

        // Action buttons
        actions: [
          const AndroidNotificationAction(
            'open_app',
            'Open App 📱',
          ),
          const AndroidNotificationAction(
            'snooze_10',
            'Snooze 10min ⏰',
          ),
        ],

        // Additional settings for background delivery
        enableLights: true,
        ledOnMs: 1000,
        ledOffMs: 500,

        // Wake screen for wellness reminders
        timeoutAfter: isCritical ? 60000 : 30000,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        interruptionLevel: isCritical
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
        categoryIdentifier: 'WELLNESS_CATEGORY',
        threadIdentifier: 'wellness_thread',
      ),
    );
  }

  // Schedule 10-minute notifications
  static Future<void> schedule10MinuteNotifications() async {
    print('⏰ Scheduling 10-minute wellness notifications...');

    // Cancel existing 10-minute notifications first
    await cancel10MinuteNotifications();

    final now = DateTime.now();
    int scheduledCount = 0;

    // Schedule notifications for the next 24 hours (144 notifications = 24 hours * 6 per hour)
    // This ensures continuous coverage
    for (int i = 1; i <= 144; i++) {
      final scheduledTime = now.add(Duration(minutes: i *10));

      // Get a random motivational message
      final randomMessage = _motivationalMessages[
      Random().nextInt(_motivationalMessages.length)];

      // Determine if this should be a critical notification (every hour)
      final isCritical = i % 6 == 0; // Every 6th notification (every hour)

      await _schedule10MinuteNotification(
        id: 20000 + i,
        title: isCritical ? "🌟 Harmonia - Wellness Hour!" : "💙 Harmonia - Quick Check-in",
        body: randomMessage,
        scheduledTime: scheduledTime,
        isCritical: isCritical,
      );

      scheduledCount++;
    }

    print('✅ Scheduled $scheduledCount 10-minute notifications starting from: ${now.add(Duration(minutes: 10))}');
    await _debugPendingNotifications();
  }

  // Schedule a single 10-minute notification
  static Future<void> _schedule10MinuteNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool isCritical = false,
  }) async {
    try {
      // Enhanced content for 10-minute notifications
      final enhancedContent = '''
💙 $body

⏰ Time: ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}
🧘‍♀️ Take a moment for yourself
${isCritical ? '🌟 Special wellness hour reminder!' : '💫 Quick mindfulness check'}

Tap to open Harmonia for your wellness moment
      '''.trim();

      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        enhancedContent,
        scheduledTZ,
        _buildEnhancedNotificationDetails(
          enhancedContent,
          isCritical: isCritical,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'wellness_10min_${isCritical ? 'critical' : 'regular'}',
      );

      if (isCritical) {
        print('🌟 Critical 10-minute notification scheduled for: $scheduledTime');
      }
    } catch (e) {
      print('❌ Error scheduling 10-minute notification: $e');
    }
  }

  // Cancel all 10-minute notifications
  static Future<void> cancel10MinuteNotifications() async {
    print('🗑️ Cancelling all 10-minute notifications...');

    // Cancel notifications with IDs 20001 to 20144
    for (int i = 1; i <= 144; i++) {
      await _notificationsPlugin.cancel(20000 + i);
    }
    print('✅ Cancelled all 10-minute notifications');
  }

  // Reschedule 10-minute notifications
  static Future<void> reschedule10MinuteNotifications() async {
    print('🔄 Rescheduling 10-minute notifications...');
    await schedule10MinuteNotifications();
  }

  // Check if we need to reschedule
  static Future<void> checkAndRescheduleIfNeeded() async {
    try {
      final pendingNotifications = await _notificationsPlugin.pendingNotificationRequests();

      final tenMinuteNotifications = pendingNotifications.where(
              (notification) => notification.id >= 20001 && notification.id <= 20144
      ).toList();

      // If we have less than 72 notifications pending (12 hours worth), reschedule
      if (tenMinuteNotifications.length < 72) {
        print('🔄 Rescheduling 10-minute notifications - only ${tenMinuteNotifications.length} pending');
        await reschedule10MinuteNotifications();
      } else {
        print('✅ 10-minute notifications are properly scheduled - ${tenMinuteNotifications.length} pending');
      }
    } catch (e) {
      print('❌ Error checking 10-minute notifications: $e');
      await reschedule10MinuteNotifications();
    }
  }

  // Enable or disable 10-minute notifications
  static Future<void> set10MinuteNotifications(bool enabled) async {
    if (enabled) {
      print('✅ Enabling 10-minute wellness notifications...');
      await schedule10MinuteNotifications();
    } else {
      print('❌ Disabling 10-minute wellness notifications...');
      await cancel10MinuteNotifications();
    }
  }

  // Debug function to check pending notifications
  static Future<void> _debugPendingNotifications() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print('📋 === 10-MINUTE NOTIFICATIONS DEBUG ===');
      print('📊 Total pending notifications: ${pending.length}');

      final tenMinuteNotifications = pending.where((n) => n.id >= 20001 && n.id <= 20144).toList();
      print('⏰ 10-minute notifications: ${tenMinuteNotifications.length}');

      final criticalNotifications = tenMinuteNotifications.where((n) =>
      n.payload?.contains('critical') == true).length;
      print('🌟 Critical notifications: $criticalNotifications');

      print('📋 === END 10-MINUTE DEBUG ===');
    } catch (e) {
      print('❌ Error getting pending 10-minute notifications: $e');
    }
  }

  // Schedule a quick test notification (1 minute)
  static Future<void> scheduleQuickTest() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 1));

    await _schedule10MinuteNotification(
      id: 29999,
      title: "🧪 Test: 10-Minute Wellness",
      body: "This is a 1-minute test of your 10-minute wellness reminders! Close the app to test background delivery.",
      scheduledTime: testTime,
      isCritical: true,
    );

    print('🧪 Test 10-minute notification scheduled for 1 minute from now');
  }

  // Get notification statistics
  static Future<Map<String, int>> getNotificationStats() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final tenMinuteNotifications = pending.where((n) => n.id >= 20001 && n.id <= 20144).toList();
      final criticalCount = tenMinuteNotifications.where((n) =>
      n.payload?.contains('critical') == true).length;

      return {
        'total': pending.length,
        'tenMinute': tenMinuteNotifications.length,
        'critical': criticalCount,
        'regular': tenMinuteNotifications.length - criticalCount,
      };
    } catch (e) {
      print('❌ Error getting notification stats: $e');
      return {'total': 0, 'tenMinute': 0, 'critical': 0, 'regular': 0};
    }
  }

  // Legacy methods for backward compatibility
  @Deprecated('Use schedule10MinuteNotifications() instead')
  static Future<void> scheduleHourlyNotifications() async {
    await schedule10MinuteNotifications();
  }

  @Deprecated('Use cancel10MinuteNotifications() instead')
  static Future<void> cancelHourlyNotifications() async {
    await cancel10MinuteNotifications();
  }

  @Deprecated('Use reschedule10MinuteNotifications() instead')
  static Future<void> rescheduleHourlyNotifications() async {
    await reschedule10MinuteNotifications();
  }

  @Deprecated('Use set10MinuteNotifications() instead')
  static Future<void> setHourlyNotifications(bool enabled) async {
    await set10MinuteNotifications(enabled);
  }
}