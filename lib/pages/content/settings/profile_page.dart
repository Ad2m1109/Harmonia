import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

class Event {
  String id;
  String name;
  String date;
  String description;
  String? voicePath;
  List<String> imagePaths;

  Event({
    required this.id,
    required this.name,
    required this.date,
    this.description = '',
    this.voicePath,
    this.imagePaths = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
        'description': description,
        'voicePath': voicePath,
        'imagePaths': imagePaths,
      };

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'],
        name: json['name'],
        date: json['date'],
        description: json['description'] ?? '',
        voicePath: json['voicePath'],
        imagePaths: List<String>.from(json['imagePaths'] ?? []),
      );
}

class ProfilePage extends StatefulWidget {
  final bool isDarkMode;

  const ProfilePage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _firstNameController;
  late TextEditingController _familyNameController;
  late TextEditingController _birthdayController;
  late TextEditingController _genderController;
  late TextEditingController _descriptionController;

  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordedPath;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _genderOptions = ['Male', 'Female'];
  
  // Events related variables
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadProfileData();
    _loadProfileImage();
    _checkExistingRecording();
    _loadEvents();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController();
    _familyNameController = TextEditingController();
    _birthdayController = TextEditingController();
    _genderController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _profileFile async {
    final path = await _localPath;
    return File('$path/profile.csv');
  }

  Future<File> get _eventsFile async {
    final path = await _localPath;
    return File('$path/events.json');
  }

  Future<void> _loadProfileData() async {
    try {
      final file = await _profileFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(contents);
        if (csvTable.isNotEmpty) {
          setState(() {
            _firstNameController.text = csvTable[0][0] ?? '';
            _familyNameController.text = csvTable[0][1] ?? '';
            _birthdayController.text = csvTable[0][2] ?? '';
            _genderController.text = csvTable[0][3] ?? '';
            _descriptionController.text = csvTable[0][4] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      final file = await _eventsFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        setState(() {
          _events = jsonList.map((json) => Event.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error loading events: $e');
    }
  }

  Future<void> _saveEvents() async {
    try {
      final file = await _eventsFile;
      final jsonList = _events.map((event) => event.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving events: $e');
    }
  }

  Future<void> _saveProfile() async {
    try {
      final file = await _profileFile;
      List<List<dynamic>> rows = [
        [
          _firstNameController.text,
          _familyNameController.text,
          _birthdayController.text,
          _genderController.text,
          _descriptionController.text,
        ]
      ];

      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadProfileImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/profile_image.jpg';
    final imageFile = File(imagePath);

    if (await imageFile.exists()) {
      setState(() {
        _imageFile = imageFile;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show choice dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor:
                widget.isDarkMode ? Colors.grey[900] : Colors.white,
            title: Text(
              'Select Image Source',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color:
                        widget.isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                  title: Text(
                    'Camera',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color:
                        widget.isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                  title: Text(
                    'Gallery',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 75,
      );

      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/profile_image.jpg';

        // Clear current image first
        setState(() {
          _imageFile = null;
        });

        // Delete old file
        final existingFile = File(imagePath);
        if (await existingFile.exists()) {
          await existingFile.delete();
        }

        // Copy and set new image
        final newImage = await File(image.path).copy(imagePath);

        if (mounted) {
          setState(() {
            _imageFile = newImage;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkExistingRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    final audioPath = '${directory.path}/profile_voice.m4a';
    final exists = await File(audioPath).exists();
    setState(() {
      _hasRecording = exists;
      if (exists) _recordedPath = audioPath;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/profile_voice.m4a';

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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _hasRecording = true;
        if (path != null) _recordedPath = path;
      });
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playRecording() async {
    if (_recordedPath != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(_recordedPath!));
      } catch (e) {
        print('Error playing recording: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        isDarkMode: widget.isDarkMode,
        onEventAdded: (event) {
          setState(() {
            _events.add(event);
          });
          _saveEvents();
        },
      ),
    );
  }

  void _showEventDetails(Event event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(
        event: event,
        isDarkMode: widget.isDarkMode,
        onEventUpdated: (updatedEvent) {
          setState(() {
            final index = _events.indexWhere((e) => e.id == event.id);
            if (index != -1) {
              _events[index] = updatedEvent;
            }
          });
          _saveEvents();
        },
        onEventDeleted: () {
          setState(() {
            _events.removeWhere((e) => e.id == event.id);
          });
          _saveEvents();
        },
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
          ),
          child: ClipOval(
            child: _imageFile != null
                ? Image.memory(
                    _imageFile!.readAsBytesSync(),
                    fit: BoxFit.cover,
                    key: UniqueKey(),
                  )
                : Icon(Icons.person, size: 50, color: Colors.grey[600]),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: IconButton(
            icon: Icon(Icons.camera_alt),
            onPressed: _pickImage,
            color: widget.isDarkMode ? Colors.white : Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(Color textColor, Color primaryColor) {
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
              color: textColor,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  IconButton(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording ? Colors.red : primaryColor,
                      size: 32,
                    ),
                  ),
                  Text(
                    _isRecording ? 'Stop' : 'Record',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              if (_hasRecording)
                Column(
                  children: [
                    IconButton(
                      onPressed: _playRecording,
                      icon: Icon(
                        Icons.play_arrow,
                        color: primaryColor,
                        size: 32,
                      ),
                    ),
                    Text(
                      'Play',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_isRecording)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Recording...',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(Color textColor, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Life Events & Memories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            IconButton(
              onPressed: _showAddEventDialog,
              icon: Icon(Icons.add_circle, color: primaryColor, size: 28),
            ),
          ],
        ),
        SizedBox(height: 16),
        if (_events.isEmpty)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 48,
                  color: textColor.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'No events added yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to add your first memory',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _events.map((event) => _buildEventCard(event, textColor, primaryColor)).toList(),
          ),
      ],
    );
  }

  Widget _buildEventCard(Event event, Color textColor, Color primaryColor) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.grey.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showEventDetails(event),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: event.imagePaths.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(event.imagePaths.first),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.event,
                        color: primaryColor,
                        size: 30,
                      ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      event.date,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    if (event.description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  if (event.voicePath != null)
                    Icon(
                      Icons.mic,
                      color: primaryColor,
                      size: 20,
                    ),
                  if (event.imagePaths.isNotEmpty)
                    Icon(
                      Icons.photo,
                      color: primaryColor,
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown(Color textColor, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonFormField<String>(
        value: _genderController.text.isEmpty ? null : _genderController.text,
        hint: Text(
          'Select Gender',
          style: TextStyle(color: textColor.withOpacity(0.7)),
        ),
        style: TextStyle(color: textColor),
        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.wc_outlined, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        items: _genderOptions.map((String gender) {
          return DropdownMenuItem<String>(
            value: gender,
            child: Text(gender),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _genderController.text = newValue;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Color(0xFF2C3E50);
    final primaryColor =
        widget.isDarkMode ? Color(0xFF2A6277) : Color(0xFF87CEEB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with avatar
            Padding(
              padding: EdgeInsets.all(16),
              child: _buildAvatar(),
            ),

            // Form fields
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildFormField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline,
                    textColor: textColor,
                    primaryColor: primaryColor,
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    controller: _familyNameController,
                    label: 'Family Name',
                    icon: Icons.people_outline,
                    textColor: textColor,
                    primaryColor: primaryColor,
                  ),
                  SizedBox(height: 16),
                  _buildFormField(
                    controller: _birthdayController,
                    label: 'Birthday',
                    icon: Icons.cake_outlined,
                    textColor: textColor,
                    primaryColor: primaryColor,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                  ),
                  SizedBox(height: 16),
                  _buildGenderDropdown(textColor, primaryColor),
                  SizedBox(height: 24),
                  Text(
                    'Additional Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildVoiceSection(textColor, primaryColor),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      style: TextStyle(color: textColor),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Add important details about the person (e.g., daily routines, favorite things, important memories, family members)',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 16, bottom: 64),
                          child: Icon(Icons.description_outlined,
                              color: primaryColor),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildEventsSection(textColor, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Save Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color primaryColor,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _familyNameController.dispose();
    _birthdayController.dispose();
    _genderController.dispose();
    _descriptionController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// Add Event Dialog
class AddEventDialog extends StatefulWidget {
  final bool isDarkMode;
  final Function(Event) onEventAdded;

  const AddEventDialog({
    super.key,
    required this.isDarkMode,
    required this.onEventAdded,
  });

  @override
  _AddEventDialogState createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  String? _recordedPath;
  List<String> _imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      final eventId = DateTime.now().millisecondsSinceEpoch.toString();
      
      List<String> savedPaths = [];
      for (int i = 0; i < images.length; i++) {
        final imagePath = '${directory.path}/event_${eventId}_image_$i.jpg';
        await File(images[i].path).copy(imagePath);
        savedPaths.add(imagePath);
      }
      
      setState(() {
        _imagePaths = savedPaths;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final eventId = DateTime.now().millisecondsSinceEpoch.toString();
        final path = '${directory.path}/event_${eventId}_voice.m4a';

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
      print('Error recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) _recordedPath = path;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_recordedPath != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(_recordedPath!));
      } catch (e) {
        print('Error playing recording: $e');
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _saveEvent() {
    if (_nameController.text.isNotEmpty && _dateController.text.isNotEmpty) {
      final event = Event(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        date: _dateController.text,
        description: _descriptionController.text,
        voicePath: _recordedPath,
        imagePaths: _imagePaths,
      );
      
      widget.onEventAdded(event);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final primaryColor = widget.isDarkMode ? Color(0xFF2A6277) : Color(0xFF87CEEB);

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Event',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 24),
              
              // Event Name
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Event Name',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.event, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 16),
              
              // Event Date
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _selectDate,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Event Date',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 16),
              
              // Description
              TextField(
                controller: _descriptionController,
                style: TextStyle(color: textColor),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.description, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 16),
              
              // Images Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Images (${_imagePaths.length})',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _pickImages,
                    icon: Icon(Icons.add_photo_alternate, color: primaryColor),
                  ),
                ],
              ),
              if (_imagePaths.isNotEmpty)
                Container(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(right: 8),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(_imagePaths[index])),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 16),
              
              // Voice Recording Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Description (Optional)',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            IconButton(
                              onPressed: _isRecording ? _stopRecording : _startRecording,
                              icon: Icon(
                                _isRecording ? Icons.stop : Icons.mic,
                                color: _isRecording ? Colors.red : primaryColor,
                                size: 32,
                              ),
                            ),
                            Text(
                              _isRecording ? 'Stop' : 'Record',
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                          ],
                        ),
                        if (_recordedPath != null)
                          Column(
                            children: [
                              IconButton(
                                onPressed: _playRecording,
                                icon: Icon(
                                  Icons.play_arrow,
                                  color: primaryColor,
                                  size: 32,
                                ),
                              ),
                              Text(
                                'Play',
                                style: TextStyle(color: textColor, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (_isRecording)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                          SizedBox(width: 4),
                          Text('Recording...', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: textColor)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveEvent,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      child: Text('Save Event', style: TextStyle(color: Colors.white)),
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
}

// Event Details Dialog
class EventDetailsDialog extends StatelessWidget {
  final Event event;
  final bool isDarkMode;
  final Function(Event) onEventUpdated;
  final VoidCallback onEventDeleted;

  const EventDetailsDialog({
    super.key,
    required this.event,
    required this.isDarkMode,
    required this.onEventUpdated,
    required this.onEventDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final primaryColor = isDarkMode ? Color(0xFF2A6277) : Color(0xFF87CEEB);

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: textColor),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        Navigator.of(context).pop();
                        onEventDeleted();
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                event.date,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              if (event.description.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  event.description,
                  style: TextStyle(color: textColor),
                ),
              ],
              if (event.imagePaths.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Images',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: event.imagePaths.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(event.imagePaths[index]),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ],
              if (event.voicePath != null) ...[
                SizedBox(height: 16),
                Text(
                  'Voice Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final audioPlayer = AudioPlayer();
                          await audioPlayer.play(DeviceFileSource(event.voicePath!));
                        },
                        icon: Icon(Icons.play_arrow, color: primaryColor, size: 32),
                      ),
                      Expanded(
                        child: Text(
                          'Play voice description',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  child: Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}