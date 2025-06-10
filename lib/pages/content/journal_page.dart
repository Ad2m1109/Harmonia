import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class JournalEntry {
  String content; // Changed from final to allow editing
  final DateTime date;
  final bool isVoice;
  final String? audioPath;

  JournalEntry({
    required this.content,
    required this.date,
    this.isVoice = false,
    this.audioPath,
  });
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  List<JournalEntry> _entries = [];
  String? _currentAudioPath;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/journal_entries.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(contents);

        setState(() {
          _entries = csvTable.map((row) {
            return JournalEntry(
              content: row[0],
              date: DateTime.parse(row[1]),
              isVoice: row[2] == 'true',
              audioPath: row[3] == '' ? null : row[3],
            );
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading entries: $e');
    }
  }

  Future<void> _saveEntries() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/journal_entries.csv');

      List<List<dynamic>> rows = _entries
          .map((entry) => [
                entry.content,
                entry.date.toIso8601String(),
                entry.isVoice.toString(),
                entry.audioPath ?? '',
              ])
          .toList();

      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);
    } catch (e) {
      print('Error saving entries: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/journal_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
          _currentAudioPath = path;
        });
      }
    } catch (e) {
      print('Error recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        setState(() {
          _entries.add(JournalEntry(
            content: 'Voice Note',
            date: DateTime.now(),
            isVoice: true,
            audioPath: path,
          ));
        });
        await _saveEntries();
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      print('Error playing recording: $e');
    }
  }

  void _addTextEntry() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _entries.add(JournalEntry(
          content: _controller.text,
          date: DateTime.now(),
        ));
        _controller.clear();
      });
      _saveEntries();
    }
  }

  void _showEntryOptions(int index) {
    final entry = _entries[index];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isVoice)
              ListTile(
                leading: Icon(Icons.edit, color: Color(0xFF4A9B8E)),
                title: Text('Rename Voice Note'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(index);
                },
              ),
            if (!entry.isVoice)
              ListTile(
                leading: Icon(Icons.edit, color: Color(0xFF4A9B8E)),
                title: Text('Edit Text'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(index);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteEntry(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(int index) {
    final TextEditingController editingController = TextEditingController();
    editingController.text = _entries[index].content;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Voice Note'),
        content: TextField(
          controller: editingController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _entries[index].content = editingController.text;
              });
              _saveEntries();
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index) {
    final TextEditingController editingController = TextEditingController();
    editingController.text = _entries[index].content;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Text'),
        content: TextField(
          controller: editingController,
          maxLines: null,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _entries[index].content = editingController.text;
              });
              _saveEntries();
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteEntry(int index) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    // Only proceed with deletion if user confirmed
    if (confirm == true) {
      final entry = _entries[index];
      if (entry.isVoice && entry.audioPath != null) {
        final audioFile = File(entry.audioPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }

      setState(() {
        _entries.removeAt(index);
      });
      _saveEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: Color(0xFF87CEEB),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'How are you feeling today?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A9B8E),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Write your thoughts here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                IconButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : Color(0xFF4A9B8E),
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          if (_isRecording)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Recording...',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _addTextEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A9B8E),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text('Save Text'),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[_entries.length - 1 - index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Icon(
                      entry.isVoice ? Icons.mic : Icons.text_fields,
                      color: Color(0xFF4A9B8E),
                    ),
                    title: Text(entry.content),
                    subtitle: Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                    ),
                    trailing: entry.isVoice
                        ? IconButton(
                            icon: Icon(Icons.play_arrow),
                            onPressed: () => _playRecording(entry.audioPath!),
                          )
                        : null,
                    onLongPress: () =>
                        _showEntryOptions(_entries.length - 1 - index),
                  ),
                );
              },
            ),
          ),
        ],
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
