import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> _tasks = [];
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadTasks();
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
            // Compare dates first
            DateTime dateA = a['date'] as DateTime;
            DateTime dateB = b['date'] as DateTime;
            int dateCompare = dateA.compareTo(dateB);
            if (dateCompare != 0) return dateCompare;

            // If same date, compare times
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
      }
    } catch (e) {
      print('Error loading tasks: $e');
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio file not found')),
          );
        }
      } catch (e) {
        print('Error playing audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio')),
        );
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
    } catch (e) {
      print('Error updating task: $e');
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
      return Color(0xFFE3F2FD); // Light blue for future tasks
    }

    // For today's tasks
    final timeComponents = time.split(':');
    final taskHour = int.parse(timeComponents[0]);
    final taskMinute = int.parse(timeComponents[1]);

    final currentTime = TimeOfDay.now();
    final taskInMinutes = taskHour * 60 + taskMinute;
    final currentInMinutes = currentTime.hour * 60 + currentTime.minute;

    if (taskInMinutes < currentInMinutes) {
      return Color(0xFFFFEBEE); // Light red for passed tasks
    }

    return Color(0xFFE8F5E9); // Light green for upcoming tasks
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reminders'),
        backgroundColor: Color(0xFF87CEEB),
      ),
      body: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final isToday = task['date'].day == DateTime.now().day &&
              task['date'].month == DateTime.now().month &&
              task['date'].year == DateTime.now().year;

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _getTaskColor(task['date'], task['time']),
            child: ListTile(
              title: Text(
                task['text'],
                style: TextStyle(
                  decoration:
                      task['isCompleted'] ? TextDecoration.lineThrough : null,
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
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '${task['time']} (${task['type']})',
                        style: TextStyle(
                          color: Colors.grey[600],
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
              trailing:
                  task['audioPath'] != null && task['audioPath'].isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.play_arrow),
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
