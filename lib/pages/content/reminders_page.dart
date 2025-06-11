import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> _tasks = [];
  final _audioPlayer = AudioPlayer();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
    _initializeNotifications();
    _loadTasks();
  }

  void _initializeTimezone() {
    tz.initializeTimeZones();
  }

  Future<void> _initializeNotifications() async {
    print('🔧 Initializing RemindersPage notifications...');
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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
      requestCriticalPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create enhanced notification channel for Android
    await _createEnhancedNotificationChannel();

    // Test initial notification
    await _testInitialNotification();
  }

  Future<void> _requestAllPermissions() async {
    print('🔐 Requesting all necessary permissions...');

    if (Platform.isAndroid) {
      // Request notification permission for Android 13+
      final notificationStatus = await Permission.notification.status;
      print('📱 Notification permission status: $notificationStatus');
      if (!notificationStatus.isGranted) {
        final result = await Permission.notification.request();
        print('📱 Notification permission request result: $result');
      }

      // Request exact alarm permission for Android 12+
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      print('⏰ Exact alarm permission status: $alarmStatus');
      if (!alarmStatus.isGranted) {
        final alarmResult = await Permission.scheduleExactAlarm.request();
        print('⏰ Exact alarm permission request result: $alarmResult');
      }

      // Request battery optimization exemption
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      print('🔋 Battery optimization status: $batteryStatus');
      if (!batteryStatus.isGranted) {
        final batteryResult = await Permission.ignoreBatteryOptimizations.request();
        print('🔋 Battery optimization request result: $batteryResult');
      }
    }

    // For iOS, request permissions through the plugin
    if (Platform.isIOS) {
      final result = await flutterLocalNotificationsPlugin
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

  Future<void> _createEnhancedNotificationChannel() async {
    print('📺 Creating enhanced task notification channel...');

    // High-priority channel for critical reminders
    const AndroidNotificationChannel highPriorityChannel = AndroidNotificationChannel(
      'reminder_channel_high',
      'High Priority Reminders',
      description: 'Critical reminder notifications that bypass Do Not Disturb',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF87CEEB),
    );

    // Regular channel for standard reminders
    const AndroidNotificationChannel regularChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Reminder Notifications',
      description: 'Standard reminder notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF87CEEB),
    );

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(highPriorityChannel);
    await androidImplementation?.createNotificationChannel(regularChannel);

    print('✅ Enhanced notification channels created');
  }

  Future<void> _testInitialNotification() async {
    print('🧪 Testing initial notification...');
    try {
      await flutterLocalNotificationsPlugin.show(
        9999,
        'Harmonia Ready',
        '✅ Task notifications are active!\n🔔 You\'ll receive reminders at scheduled times.',
        _buildEnhancedNotificationDetails(
          'Notifications are working properly!',
          isHighPriority: false,
        ),
      );
      print('✅ Initial notification sent successfully');
    } catch (e) {
      print('❌ Error sending initial notification: $e');
    }
  }

  // Generate unique notification ID based on task details
  int _generateNotificationId(int taskIndex, DateTime date, String time) {
    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final timeStr = time.replaceAll(':', '');
    final combined = '$taskIndex$dateStr$timeStr';

    // Take last 8 digits to ensure it fits in int range and avoid conflicts
    final id = int.parse(combined.substring(combined.length > 8 ? combined.length - 8 : 0));
    print('🆔 Generated notification ID: $id for task $taskIndex at $date $time');
    return id;
  }

  NotificationDetails _buildEnhancedNotificationDetails(
      String taskContent, {
        bool isHighPriority = false,
        String? audioPath,
      }) {
    final channelId = isHighPriority ? 'reminder_channel_high' : 'reminder_channel';
    final channelName = isHighPriority ? 'High Priority Reminders' : 'Reminder Notifications';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Task reminder notifications',
        importance: isHighPriority ? Importance.max : Importance.high,
        priority: isHighPriority ? Priority.max : Priority.high,
        ticker: 'Harmonia Reminder',
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        enableVibration: true,
        playSound: true,
        autoCancel: false,
        ongoing: isHighPriority,

        // Enhanced visibility settings
        fullScreenIntent: isHighPriority,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,

        // Rich content styling
        styleInformation: BigTextStyleInformation(
          taskContent,
          htmlFormatBigText: false,
          contentTitle: '🔔 Harmonia Reminder',
          htmlFormatContentTitle: false,
          summaryText: 'Tap to view details',
        ),

        // Action buttons
        actions: [
          const AndroidNotificationAction(
            'mark_done',
            'Mark Done ✅',
            titleColor: Color(0xFF4CAF50),
          ),
          const AndroidNotificationAction(
            'snooze',
            'Snooze 5min ⏰',
            titleColor: Color(0xFF2196F3),
          ),
        ],

        // Additional settings for background delivery
        enableLights: true,
        ledColor: const Color(0xFF87CEEB),
        ledOnMs: 1000,
        ledOffMs: 500,

        // Wake screen for important reminders
        timeoutAfter: isHighPriority ? 60000 : 30000,
      ),
      iOS: DarwinNotificationDetails(
        sound: audioPath != null ? audioPath : 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        interruptionLevel: isHighPriority
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
        categoryIdentifier: 'REMINDER_CATEGORY',
        threadIdentifier: 'reminder_thread',
      ),
    );
  }

  void _onNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    final actionId = notificationResponse.actionId;

    print('🔔 Task notification interaction:');
    print('   Action: $actionId');
    print('   Payload: $payload');

    // Handle action buttons
    if (actionId == 'mark_done') {
      _markTaskDoneFromNotification(payload);
    } else if (actionId == 'snooze') {
      _snoozeTaskFromNotification(payload);
    } else {
      // Regular tap - play audio if available
      if (payload != null && payload.isNotEmpty) {
        final parts = payload.split('|');
        if (parts.length > 4 && parts[4].isNotEmpty) {
          _playRecording(parts[4]);
        }
      }
    }
  }

  Future<void> _markTaskDoneFromNotification(String? taskData) async {
    print('✅ Marking task done from notification: $taskData');
    if (taskData != null) {
      final parts = taskData.split('|');
      if (parts.isNotEmpty) {
        final taskId = int.tryParse(parts[0]);
        if (taskId != null && taskId < _tasks.length) {
          await _updateTaskStatus(taskId, true);
        }
      }
    }
  }

  Future<void> _snoozeTaskFromNotification(String? taskData) async {
    print('⏰ Snoozing task from notification: $taskData');
    if (taskData != null) {
      final parts = taskData.split('|');
      if (parts.length >= 4) {
        final taskId = int.tryParse(parts[0]);
        final title = parts[1];
        final snoozeTime = DateTime.now().add(const Duration(minutes: 5));

        if (taskId != null) {
          // Schedule a snooze notification
          await _scheduleNotification(
            id: taskId + 50000, // Different ID for snooze
            title: title,
            body: 'Snoozed reminder: $title',
            scheduledDate: snoozeTime,
            time: '${snoozeTime.hour.toString().padLeft(2, '0')}:${snoozeTime.minute.toString().padLeft(2, '0')}',
            audioPath: parts.length > 4 ? parts[4] : null,
            isHighPriority: true,
          );
        }
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String time,
    String? audioPath,
    bool isHighPriority = false,
  }) async {
    try {
      print('📅 Scheduling task notification:');
      print('   ID: $id');
      print('   Title: $title');
      print('   Priority: ${isHighPriority ? "HIGH" : "NORMAL"}');
      print('   Date: $scheduledDate');
      print('   Time: $time');

      // Parse time
      final timeComponents = time.split(':');
      final hour = int.parse(timeComponents[0]);
      final minute = int.parse(timeComponents[1]);

      // Create the scheduled date with specific time
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      );

      print('   Full scheduled DateTime: $scheduledDateTime');
      print('   Current DateTime: ${DateTime.now()}');
      print('   Is in future: ${scheduledDateTime.isAfter(DateTime.now())}');

      // Only schedule if the time is in the future
      if (scheduledDateTime.isAfter(DateTime.now())) {
        // Enhanced task content for notification
        final enhancedContent = '''
📋 Task: $title
📅 Scheduled: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}
⏰ Time: $time
${body.isNotEmpty ? '\n📝 Details: $body' : ''}
${audioPath != null && audioPath.isNotEmpty ? '\n🎵 Audio reminder attached' : ''}

Tap to open app • Use buttons to take action
        '''.trim();

        final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
          scheduledDateTime,
          tz.local,
        );

        print('   TZ DateTime: $scheduledTZ');
        print('   Local timezone: ${tz.local}');

        // Create task data for payload
        final taskData = '$id|$title|${scheduledDate.toIso8601String()}|$time|${audioPath ?? ''}';

        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          '🔔 Harmonia: $title',
          enhancedContent,
          scheduledTZ,
          _buildEnhancedNotificationDetails(
            enhancedContent,
            isHighPriority: isHighPriority,
            audioPath: audioPath,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: taskData,
          // REMOVED: matchDateTimeComponents - this was causing daily repeats
        );

        print('✅ Task notification scheduled successfully for: $scheduledDateTime');
      } else {
        print('⚠️ Task time has already passed: $scheduledDateTime');
      }
    } catch (e) {
      print('❌ Error scheduling task notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling notification: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    print('🗑️ Cancelled task notification ID: $id');
  }

  Future<void> _loadTasks() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tasks.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(contents);

        setState(() {
          _tasks = csvTable
              .map((row) => {
            'text': row[0],
            'date': DateTime.parse(row[1]),
            'time': row[2],
            'type': row[3],
            'audioPath': row[4],
            'isCompleted': row[5] == 'true',
          })
              .toList();

          // Sort tasks by date and time
          _tasks.sort((a, b) {
            DateTime dateA = a['date'] as DateTime;
            DateTime dateB = b['date'] as DateTime;
            int dateCompare = dateA.compareTo(dateB);
            if (dateCompare != 0) return dateCompare;

            List<String> timeA = a['time'].toString().split(':');
            List<String> timeB = b['time'].toString().split(':');
            int hourA = int.parse(timeA[0]);
            int hourB = int.parse(timeB[0]);
            if (hourA != hourB) return hourA.compareTo(hourB);

            int minA = int.parse(timeA[1]);
            int minB = int.parse(timeB[1]);
            return minA.compareTo(minB);
          });
        });

        print('📖 Loaded ${_tasks.length} tasks from CSV');
        // Schedule notifications for all incomplete tasks
        await _scheduleAllNotifications();
      }
    } catch (e) {
      print('❌ Error loading tasks: $e');
    }
  }

  Future<void> _scheduleAllNotifications() async {
    print('⏰ Scheduling all task notifications...');

    // Cancel all existing task notifications (use a wider range to be safe)
    for (int i = 0; i < 100000; i++) {
      await flutterLocalNotificationsPlugin.cancel(i);
    }

    int scheduledCount = 0;
    final now = DateTime.now();

    // Schedule notifications for incomplete tasks
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!task['isCompleted']) {
        final taskDate = task['date'] as DateTime;
        final isToday = taskDate.day == now.day &&
            taskDate.month == now.month &&
            taskDate.year == now.year;

        // Generate unique ID for this specific task
        final notificationId = _generateNotificationId(i, taskDate, task['time']);

        await _scheduleNotification(
          id: notificationId,
          title: task['text'],
          body: 'Reminder: ${task['text']}',
          scheduledDate: task['date'],
          time: task['time'],
          audioPath: task['audioPath'],
          isHighPriority: isToday, // Today's tasks get high priority
        );
        scheduledCount++;
      }
    }

    print('✅ Scheduled $scheduledCount task notifications');

    // Debug: Show scheduled notifications
    final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    print('📊 Total pending notifications: ${pending.length}');
  }

  Future<void> _playRecording(String? audioPath) async {
    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(audioPath));
        } else {
          print('Audio file not found: $audioPath');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio file not found')),
            );
          }
        }
      } catch (e) {
        print('Error playing audio: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error playing audio')),
          );
        }
      }
    }
  }

  Future<void> _updateTaskStatus(int index, bool? value) async {
    setState(() {
      _tasks[index]['isCompleted'] = value;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tasks.csv');

      final rows = _tasks
          .map((task) => [
        task['text'],
        task['date'].toIso8601String(),
        task['time'],
        task['type'],
        task['audioPath'],
        task['isCompleted'].toString(),
      ])
          .toList();

      final csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      // Update notifications
      final task = _tasks[index];
      final taskDate = task['date'] as DateTime;
      final notificationId = _generateNotificationId(index, taskDate, task['time']);

      if (value == true) {
        // Cancel notification for completed task
        await _cancelNotification(notificationId);
        print('✅ Cancelled notification for completed task: ${task['text']}');
      } else {
        // Reschedule notification for uncompleted task
        final now = DateTime.now();
        final isToday = taskDate.day == now.day &&
            taskDate.month == now.month &&
            taskDate.year == now.year;

        await _scheduleNotification(
          id: notificationId,
          title: task['text'],
          body: 'Reminder: ${task['text']}',
          scheduledDate: task['date'],
          time: task['time'],
          audioPath: task['audioPath'],
          isHighPriority: isToday,
        );
        print('🔄 Rescheduled notification for task: ${task['text']}');
      }
    } catch (e) {
      print('❌ Error updating task: $e');
    }
  }

  Color _getTaskColor(DateTime date, String time) {
    final now = DateTime.now();
    final taskDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    if (taskDate.isBefore(today)) {
      return Colors.grey[200]!; // Past day
    }

    if (taskDate.isAfter(today)) {
      return const Color(0xFFE3F2FD); // Light blue for future tasks
    }

    // For today's tasks
    final timeComponents = time.split(':');
    final taskHour = int.parse(timeComponents[0]);
    final taskMinute = int.parse(timeComponents[1]);

    final currentTime = TimeOfDay.now();
    final taskInMinutes = taskHour * 60 + taskMinute;
    final currentInMinutes = currentTime.hour * 60 + currentTime.minute;

    if (taskInMinutes < currentInMinutes) {
      return const Color(0xFFFFEBEE); // Light red for passed tasks
    }

    return const Color(0xFFE8F5E9); // Light green for upcoming tasks
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: const Color(0xFF87CEEB),
      ),
      body: _tasks.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add tasks to receive notifications\nat their scheduled times',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final isToday = task['date'].day == DateTime.now().day &&
              task['date'].month == DateTime.now().month &&
              task['date'].year == DateTime.now().year;

          return Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _getTaskColor(task['date'], task['time']),
            child: ListTile(
              title: Text(
                task['text'],
                style: TextStyle(
                  decoration: task['isCompleted']
                      ? TextDecoration.lineThrough
                      : null,
                  color: task['isCompleted'] ? Colors.grey : Colors.black87,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${task['date'].day}/${task['date'].month}/${task['date'].year}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${task['time']} (${task['type']})',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!task['isCompleted'])
                        Icon(
                          isToday ? Icons.priority_high : Icons.notifications_active,
                          size: 16,
                          color: isToday ? Colors.red : Colors.orange,
                        ),
                      if (isToday && !task['isCompleted'])
                        const Text(
                          ' HIGH',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              leading: Checkbox(
                value: task['isCompleted'],
                onChanged: (value) => _updateTaskStatus(index, value),
              ),
              trailing: task['audioPath'] != null &&
                  task['audioPath'].isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _playRecording(task['audioPath']),
              )
                  : null,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}