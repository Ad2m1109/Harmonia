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

    // Request notification permissions
    await _requestNotificationPermissions();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
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

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Test immediate notification
    await _testImmediateTaskNotification();
  }

  Future<void> _testImmediateTaskNotification() async {
    print('🧪 Testing immediate task notification...');
    try {
      await flutterLocalNotificationsPlugin.show(
        9999,
        'Harmonia Task Test',
        'Task notifications are working! 🎉',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminder Notifications',
            channelDescription: 'Test task notifications',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print('✅ Immediate task notification sent successfully');
    } catch (e) {
      print('❌ Error sending immediate task notification: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    print('📺 Creating task notification channel...');
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminder_channel',
      'Reminder Notifications',
      description: 'Notifications for scheduled reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    print('✅ Task notification channel created');
  }

  Future<void> _requestNotificationPermissions() async {
    print('🔐 Requesting notification permissions...');

    // Request notification permission for Android 13+
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      print('📱 Notification permission status: $status');
      if (status.isDenied) {
        final result = await Permission.notification.request();
        print('📱 Notification permission request result: $result');
      }

      // Request exact alarm permission for Android 12+
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      print('⏰ Exact alarm permission status: $alarmStatus');
      if (alarmStatus.isDenied) {
        final alarmResult = await Permission.scheduleExactAlarm.request();
        print('⏰ Exact alarm permission request result: $alarmResult');
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
      );
      print('🍎 iOS notification permissions result: $result');
    }
  }

  void _onNotificationTap(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    print('🔔 Task notification tapped: ${notificationResponse.payload}');
    if (payload != null && payload.isNotEmpty) {
      // Play audio if available
      _playRecording(payload);
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String time,
    String? audioPath,
  }) async {
    try {
      print('📅 Scheduling task notification:');
      print('   ID: $id');
      print('   Title: $title');
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
        // Enhanced Android notification settings for background delivery
        final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'reminder_channel',
          'Reminder Notifications',
          channelDescription: 'Notifications for scheduled reminders',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Reminder',
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          autoCancel: true,
          // Enhanced settings for background delivery
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
          styleInformation: BigTextStyleInformation(
            'Reminder: $title\n$body\nScheduled for $time',
            htmlFormatBigText: false,
            contentTitle: 'Harmonia Reminder',
            htmlFormatContentTitle: false,
          ),
        );

        const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        );

        final NotificationDetails platformChannelSpecifics =
        NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics,
        );

        final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
          scheduledDateTime,
          tz.local,
        );

        print('   TZ DateTime: $scheduledTZ');
        print('   Local timezone: ${tz.local}');

        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          'Harmonia Reminder: $title',
          '$body\nScheduled for $time',
          scheduledTZ,
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: audioPath ?? '',
        );

        print('✅ Task notification scheduled successfully for: $scheduledDateTime');
      } else {
        print('⚠️ Task time has already passed: $scheduledDateTime');
      }
    } catch (e) {
      print('❌ Error scheduling task notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling notification: $e')),
        );
      }
    }
  }

  // Add quick test function for 2-minute notification
  Future<void> _scheduleQuickTestNotification() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 2));

    await _scheduleNotification(
      id: 99998,
      title: 'Quick Test Task',
      body: 'This is a 2-minute test reminder!',
      scheduledDate: testTime,
      time: '${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}',
      audioPath: null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test notification scheduled for 2 minutes from now!')),
      );
    }
  }

  // Debug function to check pending notifications
  Future<void> _debugPendingNotifications() async {
    try {
      final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('📋 === TASK NOTIFICATIONS DEBUG ===');
      print('📊 Total pending notifications: ${pending.length}');

      final taskNotifications = pending.where((n) => n.id < 10000).toList();
      print('📋 Task notifications (ID < 10000): ${taskNotifications.length}');

      for (var notification in taskNotifications) {
        print('🔹 ID: ${notification.id}');
        print('   Title: ${notification.title}');
        print('   Body: ${notification.body}');
        print('---');
      }
      print('📋 === END TASK DEBUG ===');
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
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

    // Cancel existing task notifications (but preserve hourly notifications by using specific range)
    for (int i = 0; i < 1000; i++) {
      await flutterLocalNotificationsPlugin.cancel(i);
    }

    int scheduledCount = 0;
    // Schedule notifications for incomplete tasks
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!task['isCompleted']) {
        await _scheduleNotification(
          id: i,
          title: task['text'],
          body: 'Reminder: ${task['text']}',
          scheduledDate: task['date'],
          time: task['time'],
          audioPath: task['audioPath'],
        );
        scheduledCount++;
      }
    }

    print('✅ Scheduled $scheduledCount task notifications');
    await _debugPendingNotifications();
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
      if (value == true) {
        // Cancel notification for completed task
        await _cancelNotification(index);
        print('✅ Cancelled notification for completed task: ${_tasks[index]['text']}');
      } else {
        // Reschedule notification for uncompleted task
        final task = _tasks[index];
        await _scheduleNotification(
          id: index,
          title: task['text'],
          body: 'Reminder: ${task['text']}',
          scheduledDate: task['date'],
          time: task['time'],
          audioPath: task['audioPath'],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _debugPendingNotifications,
            tooltip: 'Debug Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: _scheduleQuickTestNotification,
            tooltip: 'Test 2-min Notification',
          ),
        ],
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
                        const Icon(
                          Icons.notifications_active,
                          size: 16,
                          color: Colors.orange,
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