import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

enum TaskType { daily, medical, important }

class ReminderTask {
  String text;
  final DateTime date;
  final TimeOfDay time;
  final TaskType type;
  final String? audioPath;
  bool isCompleted;

  ReminderTask({
    required this.text,
    required this.date,
    required this.time,
    required this.type,
    this.audioPath,
    this.isCompleted = false,
  });
}

class AddRemindersPage extends StatefulWidget {
  final bool isDarkMode;

  const AddRemindersPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<AddRemindersPage> createState() => _AddRemindersPageState();
}

class _AddRemindersPageState extends State<AddRemindersPage> {
  final TextEditingController _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedPath;
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();
  TaskType _selectedType = TaskType.daily;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${directory.path}/task_audio_$timestamp.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordedPath = path;
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _playRecordedAudio(String? audioPath) async {
    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(audioPath));
        } else {
          print('Audio file not found: $audioPath');
        }
      } catch (e) {
        print('Error playing audio: $e');
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
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
        });
      }
    } catch (e) {
      print('Error loading tasks: $e');
    }
  }

  Future<void> _deleteTask(int index) async {
    try {
      // Delete associated audio file if exists
      if (_tasks[index]['audioPath'] != null &&
          _tasks[index]['audioPath'].isNotEmpty) {
        final audioFile = File(_tasks[index]['audioPath']);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }

      setState(() {
        _tasks.removeAt(index);
      });

      // Save updated tasks list
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task deleted successfully')),
      );
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  Future<void> _saveTask() async {
    if (_controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a task description')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tasks.csv');

      List<List<dynamic>> rows = [];
      if (await file.exists()) {
        final contents = await file.readAsString();
        rows = const CsvToListConverter().convert(contents);
      }

      rows.add([
        _controller.text,
        _selectedDate.toIso8601String(),
        '${_selectedTime.hour}:${_selectedTime.minute}',
        _selectedType.toString().split('.').last,
        _recordedPath ?? '',
        'false',
      ]);

      final csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      // Clear form and refresh tasks
      setState(() {
        _controller.clear();
        _selectedTime = TimeOfDay.now();
        _selectedDate = DateTime.now();
        _selectedType = TaskType.daily;
        _recordedPath = null;
      });

      await _loadTasks();

      // Navigate to home page and back to refresh it
      Navigator.pushReplacementNamed(context, '/home').then((_) {
        Navigator.pushNamed(context, '/settings/add_reminders');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task saved successfully')),
      );
    } catch (e) {
      print('Error saving task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving task')),
      );
    }
  }

  Future<void> _editTask(int index) async {
    _controller.text = _tasks[index]['text'];
    _selectedDate = _tasks[index]['date'];
    _selectedTime = TimeOfDay(
      hour: int.parse(_tasks[index]['time'].split(':')[0]),
      minute: int.parse(_tasks[index]['time'].split(':')[1]),
    );
    _selectedType = TaskType.values.firstWhere(
      (type) => type.toString().split('.').last == _tasks[index]['type'],
    );
    _recordedPath = _tasks[index]['audioPath'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Task Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: Icon(Icons.calendar_today),
                      label: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selectTime(context),
                      icon: Icon(Icons.access_time),
                      label: Text('${_selectedTime.format(context)}'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _updateTask(index);
                        Navigator.pop(context);
                      },
                      child: Text('Update Task'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _deleteTask(index);
                        Navigator.pop(context);
                      },
                      child: Text('Delete Task'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateTask(int index) async {
    try {
      _tasks[index]['text'] = _controller.text;
      _tasks[index]['date'] = _selectedDate;
      _tasks[index]['time'] = '${_selectedTime.hour}:${_selectedTime.minute}';

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

      setState(() {
        _controller.clear();
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
        _selectedType = TaskType.daily;
        _recordedPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task updated successfully')),
      );
    } catch (e) {
      print('Error updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Reminder'),
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Form Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Task',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          widget.isDarkMode ? Colors.white : Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter task description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: Icon(Icons.calendar_today),
                          label: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _selectTime(context),
                          icon: Icon(Icons.access_time),
                          label: Text('${_selectedTime.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<TaskType>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Task Type',
                      border: OutlineInputBorder(),
                    ),
                    items: TaskType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (TaskType? value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed:
                            _isRecording ? _stopRecording : _startRecording,
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        color: _isRecording ? Colors.red : Colors.blue,
                        iconSize: 32,
                      ),
                      if (_recordedPath != null && !_isRecording)
                        IconButton(
                          onPressed: () => _playRecordedAudio(_recordedPath),
                          icon: Icon(Icons.play_arrow),
                          color: Colors.blue,
                          iconSize: 32,
                        ),
                      if (_isRecording)
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('Recording...',
                              style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveTask,
                    child: Text('Add Task'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),

            // Tasks List Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Tasks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          widget.isDarkMode ? Colors.white : Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Dismissible(
                        key: UniqueKey(),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 16),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) => _deleteTask(index),
                        child: Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(task['text']),
                            subtitle: Text(
                              '${task['date'].day}/${task['date'].month}/${task['date'].year} at ${task['time']} (${task['type']})',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (task['audioPath'] != null &&
                                    task['audioPath'].isNotEmpty)
                                  IconButton(
                                    icon: Icon(Icons.play_arrow),
                                    onPressed: () =>
                                        _playRecordedAudio(task['audioPath']),
                                  ),
                              ],
                            ),
                            onLongPress: () => _editTask(index),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
