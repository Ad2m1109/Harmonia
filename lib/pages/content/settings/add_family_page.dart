import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AddFamilyPage extends StatefulWidget {
  final bool isDarkMode;

  const AddFamilyPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<AddFamilyPage> createState() => _AddFamilyPageState();
}

class _AddFamilyPageState extends State<AddFamilyPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final List<Map<String, dynamic>> _familyMembers = [];
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/family_members.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(contents);

        setState(() {
          _familyMembers.clear();
          for (var row in csvTable) {
            _familyMembers.add({
              'name': row[0],
              'relation': row[1],
              'imagePath': row[2],
              'voicePath': row[3],
            });
          }
        });
      }
    } catch (e) {
      print('Error loading family members: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${directory.path}/family_voice_$timestamp.m4a';

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
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(audioPath));
      } catch (e) {
        print('Error playing audio: $e');
      }
    }
  }

  Future<void> _saveFamilyMember() async {
    if (_nameController.text.isEmpty || _relationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter name and relation')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      String? imagePath;
      String? voicePath;

      if (_imageFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        imagePath = '${directory.path}/family_${timestamp}.jpg';
        await _imageFile!.copy(imagePath);
      }

      if (_recordedPath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        voicePath = '${directory.path}/family_voice_$timestamp.m4a';
        await File(_recordedPath!).copy(voicePath);
      }

      final memberData = {
        'name': _nameController.text,
        'relation': _relationController.text,
        'imagePath': imagePath ?? '',
        'voicePath': voicePath ?? '',
      };

      setState(() {
        _familyMembers.add(memberData);
      });

      // Save to CSV
      final file = File('${directory.path}/family_members.csv');
      final rows = _familyMembers
          .map((member) => [
                member['name'],
                member['relation'],
                member['imagePath'],
                member['voicePath'],
              ])
          .toList();

      final csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      _nameController.clear();
      _relationController.clear();
      setState(() {
        _imageFile = null;
        _recordedPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Family member added successfully')),
      );

      // Add this line to pop with result
      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving family member: $e');
    }
  }

  Future<void> _deleteFamilyMember(int index) async {
    try {
      if (_familyMembers[index]['imagePath'].isNotEmpty) {
        final imageFile = File(_familyMembers[index]['imagePath']);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }

      if (_familyMembers[index]['voicePath'].isNotEmpty) {
        final voiceFile = File(_familyMembers[index]['voicePath']);
        if (await voiceFile.exists()) {
          await voiceFile.delete();
        }
      }

      setState(() {
        _familyMembers.removeAt(index);
      });

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/family_members.csv');
      final rows = _familyMembers
          .map((member) => [
                member['name'],
                member['relation'],
                member['imagePath'],
                member['voicePath'],
              ])
          .toList();

      final csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Family member removed')),
      );
    } catch (e) {
      print('Error deleting family member: $e');
    }
  }

  Future<void> _editFamilyMember(int index) async {
    _nameController.text = _familyMembers[index]['name'];
    _relationController.text = _familyMembers[index]['relation'];
    if (_familyMembers[index]['imagePath'].isNotEmpty) {
      _imageFile = File(_familyMembers[index]['imagePath']);
    }

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
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: _imageFile != null
                      ? ClipOval(
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.add_a_photo, size: 40),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _relationController,
                decoration: InputDecoration(
                  labelText: 'Relation',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Brother, Sister, Father...',
                ),
              ),
              SizedBox(height: 16),
              _buildVoiceControls(),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _updateFamilyMember(index);
                        Navigator.pop(context);
                      },
                      child: Text('Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _deleteFamilyMember(index);
                        Navigator.pop(context);
                      },
                      child: Text('Delete'),
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

    // Clear the form after editing
    _nameController.clear();
    _relationController.clear();
    setState(() {
      _imageFile = null;
    });
  }

  Future<void> _updateFamilyMember(int index) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      String? imagePath = _familyMembers[index]['imagePath'] as String;
      String? voicePath = _familyMembers[index]['voicePath'] as String;

      // If a new image was selected
      if (_imageFile != null && _imageFile!.path != imagePath) {
        // Delete old image if it exists
        if (imagePath != null && imagePath.isNotEmpty) {
          final oldFile = File(imagePath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        // Save new image
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        imagePath = '${directory.path}/family_${timestamp}.jpg';
        await _imageFile!.copy(imagePath);
      }

      // If a new voice recording exists
      if (_recordedPath != null && _recordedPath != voicePath) {
        // Delete old voice recording if it exists
        if (voicePath != null && voicePath.isNotEmpty) {
          final oldVoiceFile = File(voicePath);
          if (await oldVoiceFile.exists()) {
            await oldVoiceFile.delete();
          }
        }

        // Save new voice recording
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        voicePath = '${directory.path}/family_voice_$timestamp.m4a';
        await File(_recordedPath!).copy(voicePath);
      }

      setState(() {
        _familyMembers[index] = {
          'name': _nameController.text,
          'relation': _relationController.text,
          'imagePath': imagePath ?? '',
          'voicePath': voicePath ?? '',
        };
      });

      // Save to CSV
      final file = File('${directory.path}/family_members.csv');
      final rows = _familyMembers
          .map((member) => [
                member['name'],
                member['relation'],
                member['imagePath'],
                member['voicePath'],
              ])
          .toList();

      final csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Family member updated successfully')),
      );
    } catch (e) {
      print('Error updating family member: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating family member')),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Hero(
              tag: imagePath,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
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
            ],
          ),
          if (_isRecording)
            Center(
              child: Text(
                'Recording...',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Family Member'),
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Add member form
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_imageFile != null) {
                          _showFullScreenImage(context, _imageFile!.path);
                        } else {
                          _pickImage();
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: _imageFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(Icons.add_a_photo, size: 40),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _relationController,
                      decoration: InputDecoration(
                        labelText: 'Relation',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Brother, Sister, Father...',
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildVoiceControls(),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveFamilyMember,
                      child: Text('Add Family Member'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            // Family members list
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _familyMembers.length,
              itemBuilder: (context, index) {
                final member = _familyMembers[index];
                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteFamilyMember(index),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (member['imagePath'].isNotEmpty) {
                          _showFullScreenImage(context, member['imagePath']);
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: member['imagePath'].isNotEmpty
                              ? DecorationImage(
                                  image: FileImage(File(member['imagePath'])),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: member['imagePath'].isEmpty
                            ? Icon(Icons.person)
                            : null,
                      ),
                    ),
                    title: Text(member['name']),
                    subtitle: Text(member['relation']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (member['voicePath']?.isNotEmpty ?? false)
                          IconButton(
                            icon: Icon(Icons.play_arrow),
                            onPressed: () =>
                                _playRecordedAudio(member['voicePath']),
                          ),
                      ],
                    ),
                    onLongPress: () => _editFamilyMember(index),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
