import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harmonia/pages/content/journal_page.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

enum SaveLocation {
  appDocuments,
  downloads,
  external,
}

class GameEntry {
  final DateTime timestamp;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String difficultyLevel;
  final int currentScore;
  final int totalQuestions;
  final int streakCount;
  final String feedback;

  GameEntry({
    required this.timestamp,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.difficultyLevel,
    required this.currentScore,
    required this.totalQuestions,
    required this.streakCount,
    required this.feedback,
  });
}

class DailyFilesPage extends StatefulWidget {
  final List<JournalEntry> entries;
  final bool isDarkMode;

  const DailyFilesPage({
    super.key,
    required this.entries,
    required this.isDarkMode,
  });

  @override
  State<DailyFilesPage> createState() => _DailyFilesPageState();
}

class _DailyFilesPageState extends State<DailyFilesPage> {
  List<JournalEntry> _entries = [];
  List<GameEntry> _gameEntries = [];
  final _audioPlayer = AudioPlayer();
  String _selectedDataType = 'All'; // 'All', 'Journal', 'Memory Game'

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    await Future.wait([
      _loadJournalEntries(),
      _loadGameEntries(),
    ]);
  }

  Future<void> _loadJournalEntries() async {
    try {
      if (widget.entries.isNotEmpty) {
        setState(() {
          _entries = widget.entries;
        });
      } else {
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
      }
    } catch (e) {
      print('Error loading journal entries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load journal entries')),
        );
      }
    }
  }

  Future<void> _loadGameEntries() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/memory_game_history.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(contents);

        // Skip header row if it exists
        if (csvTable.isNotEmpty && csvTable[0].contains('Timestamp')) {
          csvTable.removeAt(0);
        }

        setState(() {
          _gameEntries = csvTable.map((row) {
            return GameEntry(
              timestamp: DateTime.parse(row[0]),
              question: row[1],
              userAnswer: row[2],
              correctAnswer: row[3],
              isCorrect: row[4] == 'true',
              difficultyLevel: row[5],
              currentScore: int.parse(row[6].toString()),
              totalQuestions: int.parse(row[7].toString()),
              streakCount: int.parse(row[8].toString()),
              feedback: row[9],
            );
          }).toList();
        });

        print('Loaded ${_gameEntries.length} memory game entries');
      }
    } catch (e) {
      print('Error loading memory game entries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load memory game data')),
        );
      }
    }
  }

  Future<void> _playRecording(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      print('Error playing recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play voice note')),
        );
      }
    }
  }

  Future<void> _saveEntriesToFile() async {
    // Show save location chooser dialog
    final selectedLocation = await _showSaveLocationDialog();
    if (selectedLocation == null) return;

    try {
      Directory? targetDirectory;
      String locationDescription = '';

      switch (selectedLocation) {
        case SaveLocation.appDocuments:
          targetDirectory = await getApplicationDocumentsDirectory();
          locationDescription = 'App Documents (Always Available)';
          break;

        case SaveLocation.downloads:
          if (Platform.isAndroid) {
            // Try downloads folder (requires permission on older Android)
            var hasPermission = await _requestStoragePermission();
            if (hasPermission) {
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                targetDirectory = Directory('${externalDir.path}/Download');
                locationDescription = 'Downloads Folder';
              }
            }
          }
          // Fallback to app documents if Downloads not available
          if (targetDirectory == null) {
            targetDirectory = await getApplicationDocumentsDirectory();
            locationDescription = 'App Documents (Downloads location not accessible)';
          }
          break;

        case SaveLocation.external:
          if (Platform.isAndroid) {
            var hasPermission = await _requestStoragePermission();
            if (hasPermission) {
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                targetDirectory = Directory(externalDir.path);
                locationDescription = 'External Storage';
              }
            }
          }
          // Fallback to app documents if external not available
          if (targetDirectory == null) {
            targetDirectory = await getApplicationDocumentsDirectory();
            locationDescription = 'App Documents (External storage not accessible)';
          }
          break;
      }

      if (targetDirectory == null) {
        throw Exception('No valid save location found');
      }

      print('Selected save location: $locationDescription');
      print('Target directory: ${targetDirectory.path}');

      // Ensure directory exists
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
        print('Created directory: ${targetDirectory.path}');
      }

      // Test write permissions
      await _testDirectoryWritePermission(targetDirectory);

      // Convert data to CSV based on selected type
      List<List<dynamic>> rows = [];
      String fileName = '';

      if (_selectedDataType == 'All') {
        // Export both journal entries and memory game data
        rows.add(<dynamic>['Type', 'Timestamp', 'Content/Question', 'Additional Info', 'Success/Voice', 'Audio Path/Difficulty']);

        // Add journal entries
        rows.addAll(_entries.map((entry) => <dynamic>[
          'Journal',
          entry.date.toIso8601String(),
          entry.content,
          '',
          entry.isVoice.toString(),
          entry.audioPath ?? '',
        ]).toList());

        // Add memory game entries
        rows.addAll(_gameEntries.map((entry) => <dynamic>[
          'Memory Game',
          entry.timestamp.toIso8601String(),
          entry.question,
          'Answer: ${entry.userAnswer} | Correct: ${entry.correctAnswer}',
          entry.isCorrect.toString(),
          entry.difficultyLevel,
        ]).toList());

        fileName = 'harmonia_all_data';
      } else if (_selectedDataType == 'Journal') {
        // Export only journal entries
        rows.add(<dynamic>['Content', 'Date', 'IsVoice', 'AudioPath']);
        rows.addAll(_entries.map((entry) => <dynamic>[
          entry.content,
          entry.date.toIso8601String(),
          entry.isVoice.toString(),
          entry.audioPath ?? '',
        ]).toList());

        fileName = 'journal_entries';
      } else {
        // Export only memory game data
        rows.add(<dynamic>['Timestamp', 'Question', 'User Answer', 'Correct Answer', 'Is Correct', 'Difficulty Level', 'Current Score', 'Total Questions', 'Streak Count', 'Feedback']);
        rows.addAll(_gameEntries.map((entry) => <dynamic>[
          entry.timestamp.toIso8601String(),
          entry.question,
          entry.userAnswer,
          entry.correctAnswer,
          entry.isCorrect.toString(),
          entry.difficultyLevel,
          entry.currentScore,
          entry.totalQuestions,
          entry.streakCount,
          entry.feedback,
        ]).toList());

        fileName = 'memory_game_history';
      }

      String csv = const ListToCsvConverter().convert(rows);
      print('CSV content generated: ${csv.length} bytes');

      // Create unique file name with timestamp
      final timestamp = DateTime.now().toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-')
          .split('T')[0] + '_' +
          DateTime.now().toIso8601String()
              .split('T')[1]
              .replaceAll(':', '-')
              .split('.')[0];

      final file = File('${targetDirectory.path}/${fileName}_$timestamp.csv');
      print('Target file path: ${file.path}');

      // Write CSV file
      await file.writeAsString(csv);
      print('File written successfully');

      if (mounted) {
        String dataDescription = '';
        if (_selectedDataType == 'All') {
          dataDescription = '${_entries.length} journal entries + ${_gameEntries.length} memory game records';
        } else if (_selectedDataType == 'Journal') {
          dataDescription = '${_entries.length} journal entries';
        } else {
          dataDescription = '${_gameEntries.length} memory game records';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File saved successfully!'),
                Text(
                  'Exported: $dataDescription',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  'Location: $locationDescription',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  'Path: ${file.path}',
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy Path',
              onPressed: () => _copyFilePathToClipboard(file.path),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error saving file: $e\nStack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _testDirectoryWritePermission(Directory directory) async {
    final testFile = File('${directory.path}/test_write_permission.txt');
    try {
      await testFile.writeAsString('test');
      await testFile.delete();
      print('Directory write permission confirmed: ${directory.path}');
    } catch (e) {
      print('Directory not writable: ${directory.path}, Error: $e');
      throw Exception('Cannot write to directory: ${directory.path}');
    }
  }

  Future<void> _copyFilePathToClipboard(String filePath) async {
    try {
      await Clipboard.setData(ClipboardData(text: filePath));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path copied to clipboard')),
        );
      }
    } catch (e) {
      print('Error copying to clipboard: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Storage Access'),
          content: const Text(
            'To save to your preferred location, we need storage permission. If you prefer not to grant it, we\'ll save to the app directory instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Use App Directory'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Storage permission is required to save files to Downloads'),
          action: SnackBarAction(
            label: 'Grant Permission',
            onPressed: () async {
              await Permission.storage.request();
            },
          ),
        ),
      );
    }
  }

  Future<SaveLocation?> _showSaveLocationDialog() async {
    return showDialog<SaveLocation>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Save Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.blue),
                title: const Text('App Documents'),
                subtitle: const Text('✅ Always works, private to app'),
                onTap: () => Navigator.pop(context, SaveLocation.appDocuments),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.green),
                title: const Text('Downloads Folder'),
                subtitle: const Text('📥 Try Downloads, fallback to App Documents'),
                onTap: () => Navigator.pop(context, SaveLocation.downloads),
              ),
              if (Platform.isAndroid)
                ListTile(
                  leading: const Icon(Icons.sd_storage, color: Colors.orange),
                  title: const Text('External Storage'),
                  subtitle: const Text('📱 Try external storage, fallback to App Documents'),
                  onTap: () => Navigator.pop(context, SaveLocation.external),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.storage.status;
    print('Storage permission status: $status');

    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.storage.request();
      print('Permission request result: $status');
    }

    if (status.isPermanentlyDenied && mounted) {
      _showPermissionDialog();
      return false;
    }

    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor:
        widget.isDarkMode ? const Color(0xFF1A4B5F) : const Color(0xFF87CEEB),
        elevation: 0,
        title: const Text(
          'Daily Files',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveEntriesToFile,
            tooltip: 'Export $_selectedDataType Data (Choose Location)',
          ),
        ],
      ),
      body: Column(
        children: [
          // Data type selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(
                  color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Show: ',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Journal', 'Memory Game'].map((type) {
                        final isSelected = _selectedDataType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedDataType = type;
                              });
                            },
                            selectedColor: widget.isDarkMode ? const Color(0xFF1A4B5F) : const Color(0xFF87CEEB),
                            backgroundColor: widget.isDarkMode ? Colors.grey.shade700 : Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data display
          Expanded(
            child: _buildDataList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    if (_selectedDataType == 'All') {
      return _buildCombinedList();
    } else if (_selectedDataType == 'Journal') {
      return _buildJournalList();
    } else {
      return _buildGameList();
    }
  }

  Widget _buildCombinedList() {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    // Combine and sort all entries by date
    List<Map<String, dynamic>> combinedEntries = [];

    for (var entry in _entries) {
      combinedEntries.add({
        'type': 'journal',
        'date': entry.date,
        'data': entry,
      });
    }

    for (var entry in _gameEntries) {
      combinedEntries.add({
        'type': 'game',
        'date': entry.timestamp,
        'data': entry,
      });
    }

    combinedEntries.sort((a, b) => b['date'].compareTo(a['date']));

    if (combinedEntries.isEmpty) {
      return Center(
        child: Text(
          'No data found.',
          style: TextStyle(color: textColor, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: combinedEntries.length,
      itemBuilder: (context, index) {
        final item = combinedEntries[index];
        if (item['type'] == 'journal') {
          return _buildJournalCard(item['data'] as JournalEntry);
        } else {
          return _buildGameCard(item['data'] as GameEntry);
        }
      },
    );
  }

  Widget _buildJournalList() {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No journal entries found.',
          style: TextStyle(color: textColor, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[_entries.length - 1 - index];
        return _buildJournalCard(entry);
      },
    );
  }

  Widget _buildGameList() {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    if (_gameEntries.isEmpty) {
      return Center(
        child: Text(
          'No memory game data found.',
          style: TextStyle(color: textColor, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gameEntries.length,
      itemBuilder: (context, index) {
        final entry = _gameEntries[_gameEntries.length - 1 - index];
        return _buildGameCard(entry);
      },
    );
  }

  Widget _buildJournalCard(JournalEntry entry) {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF4A9B8E),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A9B8E).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            entry.isVoice ? Icons.mic : Icons.text_fields,
            color: const Color(0xFF4A9B8E),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4A9B8E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Journal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.content,
                style: TextStyle(color: textColor, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${entry.date.day}/${entry.date.month}/${entry.date.year} ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: textColor.withOpacity(0.6)),
          ),
        ),
        trailing: entry.isVoice && entry.audioPath != null
            ? IconButton(
          icon: const Icon(Icons.play_arrow, color: Color(0xFF4A9B8E)),
          onPressed: () => _playRecording(entry.audioPath!),
        )
            : null,
      ),
    );
  }

  Widget _buildGameCard(GameEntry entry) {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: entry.isCorrect ? Colors.green : Colors.orange,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.isCorrect ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Memory Game',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.difficultyLevel.toUpperCase(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  entry.isCorrect ? Icons.check_circle : Icons.help_outline,
                  color: entry.isCorrect ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.question,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Answer: ',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  entry.userAnswer,
                  style: TextStyle(
                    color: entry.isCorrect ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!entry.isCorrect) ...[
                  Text(
                    ' (Correct: ${entry.correctAnswer})',
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year} ${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Score: ${entry.currentScore}/${entry.totalQuestions}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}