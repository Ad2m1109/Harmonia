import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class ProfilesPage extends StatefulWidget {
  final bool isDarkMode;

  const ProfilesPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  String _fullName = '';
  String _birthday = '';
  String _gender = '';
  File? _profileImage;
  List<Map<String, dynamic>> _familyMembers = [];
  final _audioPlayer = AudioPlayer();
  String? _voiceDescription;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadFamilyMembers();
    _loadVoiceDescription();
  }

  Future<void> _loadProfileData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Load profile image
      final imagePath = '${directory.path}/profile_image.jpg';
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        setState(() {
          _profileImage = imageFile;
        });
      }

      // Load profile data
      final file = File('${directory.path}/profile.csv');
      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(contents);
        if (csvTable.isNotEmpty) {
          setState(() {
            _fullName = '${csvTable[0][0]} ${csvTable[0][1]}'.trim();
            _birthday = csvTable[0][2] ?? '';
            _gender = csvTable[0][3] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
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
          _familyMembers = csvTable
              .map((row) => {
                    'name': row[0],
                    'relation': row[1],
                    'imagePath': row[2],
                    'voicePath': row[3],
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading family members: $e');
    }
  }

  Future<void> _loadVoiceDescription() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioPath = '${directory.path}/profile_voice.m4a';
      if (await File(audioPath).exists()) {
        setState(() {
          _voiceDescription = audioPath;
        });
      }
    } catch (e) {
      print('Error loading voice description: $e');
    }
  }

  Future<void> _playVoiceDescription() async {
    if (_voiceDescription != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(_voiceDescription!));
      } catch (e) {
        print('Error playing voice description: $e');
      }
    }
  }

  Future<void> _playRecordedAudio(String? audioPath) async {
    if (audioPath != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(audioPath));
      } catch (e) {
        print('Error playing recorded audio: $e');
      }
    }
  }

  void _showFullScreenImage(BuildContext context, String imagePath,
      {bool isProfile = false}) {
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
              tag: isProfile ? 'profileImage' : imagePath,
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

  Widget _buildProfileCard() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: widget.isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_profileImage != null) {
                      _showFullScreenImage(
                        context,
                        _profileImage!.path,
                        isProfile: true,
                      );
                    }
                  },
                  child: Hero(
                    tag: 'profileImage',
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(
                                _profileImage!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.person, size: 50),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _fullName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (_birthday.isNotEmpty)
                  Text(
                    'Birthday: $_birthday',
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          widget.isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                if (_gender.isNotEmpty)
                  Text(
                    'Gender: $_gender',
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          widget.isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                if (_voiceDescription != null)
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_outline,
                      color: widget.isDarkMode ? Colors.white70 : Colors.blue,
                      size: 32,
                    ),
                    onPressed: _playVoiceDescription,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _familyMembers.length,
      itemBuilder: (context, index) {
        final member = _familyMembers[index];
        return Card(
          elevation: 2,
          color: widget.isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (member['imagePath'].isNotEmpty) {
                      _showFullScreenImage(context, member['imagePath']);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    child: member['imagePath'].isNotEmpty
                        ? Hero(
                            tag: 'familyMember$index',
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4)),
                              child: Image.file(
                                File(member['imagePath']),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          )
                        : Icon(Icons.person, size: 50),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      member['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      member['relation'],
                      style: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white70
                            : Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (member['voicePath']?.isNotEmpty ?? false)
                      IconButton(
                        icon: Icon(
                          Icons.play_circle_outline,
                          color:
                              widget.isDarkMode ? Colors.white70 : Colors.blue,
                        ),
                        onPressed: () =>
                            _playRecordedAudio(member['voicePath']),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Family Gallery',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfileData();
          await _loadFamilyMembers();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileCard(),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Family Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              _buildFamilyGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
