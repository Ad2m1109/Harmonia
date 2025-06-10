import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;

  const SettingsPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _fullName = 'Empty Name';
  File? _profileImage;
  String? _emergencyNumber;
  final _emergencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileName();
    _loadProfileImage();
    _loadEmergencyNumber();
  }

  Future<void> _loadProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        setState(() {
          _profileImage = imageFile;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> _loadProfileName() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(contents);
        if (csvTable.isNotEmpty) {
          final firstName = csvTable[0][0] as String;
          final familyName = csvTable[0][1] as String;
          if (firstName.isNotEmpty || familyName.isNotEmpty) {
            setState(() {
              _fullName = '$firstName $familyName'.trim();
            });
          }
        }
      }
    } catch (e) {
      print('Error loading profile name: $e');
    }
  }

  Future<void> _loadEmergencyNumber() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/emergency.txt');
    if (await file.exists()) {
      final number = await file.readAsString();
      setState(() {
        _emergencyNumber = number;
      });
    }
  }

  Future<void> _saveEmergencyNumber(String number) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/emergency.txt');
    await file.writeAsString(number);
    setState(() {
      _emergencyNumber = number;
    });
  }

  Future<void> _deleteEmergencyNumber() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/emergency.txt');
    if (await file.exists()) {
      await file.delete();
      setState(() {
        _emergencyNumber = null;
      });
    }
  }

  void _showEmergencyDialog() {
    if (_emergencyNumber != null) {
      _emergencyController.text = _emergencyNumber!;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(
              Icons.emergency_outlined,
              color: Colors.red,
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                _emergencyNumber == null
                    ? 'Add Emergency Contact'
                    : 'Edit Emergency Contact',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emergencyController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Enter emergency phone number',
                prefixIcon: Icon(Icons.phone, color: Colors.red),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
                filled: true,
                fillColor:
                    widget.isDarkMode ? Color(0xFF3A3A3A) : Colors.grey[100],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.cancel,
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey,
                ),
                if (_emergencyNumber != null)
                  _buildActionButton(
                    icon: Icons.delete,
                    label: 'Delete',
                    onPressed: () {
                      _deleteEmergencyNumber();
                      Navigator.pop(context);
                    },
                    color: Colors.red,
                  ),
                _buildActionButton(
                  icon: Icons.save,
                  label: 'Save',
                  onPressed: () {
                    if (_emergencyController.text.isNotEmpty) {
                      final cleanNumber = _emergencyController.text
                          .replaceAll(RegExp(r'[^\d+]'), '');
                      if (cleanNumber.length >= 8) {
                        _saveEmergencyNumber(cleanNumber);
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Please enter a valid phone number')),
                        );
                      }
                    }
                  },
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    return CircleAvatar(
      backgroundColor: Colors.grey[300],
      radius: 30,
      child: ClipOval(
        child: _profileImage != null
            ? Image.memory(
                _profileImage!.readAsBytesSync(),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                key: UniqueKey(),
              )
            : Icon(Icons.person, size: 40, color: Colors.grey[600]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Color(0xFF2C3E50);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
        elevation: 0,
        title: Text(
          'Settings',
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
            // Profile Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    widget.isDarkMode ? Color(0xFF2A6277) : Color(0xFFB6E5FF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: ListTile(
                leading: _buildProfileImage(),
                title: Text(
                  _fullName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings/profile').then((_) {
                      _loadProfileName();
                      _loadProfileImage();
                      setState(() {}); // Force refresh
                    });
                  },
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color:
                          widget.isDarkMode ? Colors.white : Color(0xFF87CEEB),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Main Settings Options
            _buildSettingsSection(
              [
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'reminder',
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/add_reminders'),
                  isDarkMode: widget.isDarkMode,
                ),
                _buildSettingsTile(
                  icon: Icons.people_outline,
                  title: 'Family',
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/add_family'),
                  isDarkMode: widget.isDarkMode,
                ),
                _buildSettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  onTap: () {},
                  isDarkMode: widget.isDarkMode,
                ),
                _buildSettingsTile(
                  icon: Icons.security,
                  title: 'security',
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/security'),
                  isDarkMode: widget.isDarkMode,
                ),
                _buildSettingsTile(
                  icon: Icons.emergency_outlined,
                  title:
                      'EMERGENCY SOS ${_emergencyNumber != null ? "- $_emergencyNumber" : ""}',
                  onTap: _showEmergencyDialog,
                  isDarkMode: widget.isDarkMode,
                  isEmergency: true,
                ),
              ],
              isDarkMode: widget.isDarkMode,
            ),
            SizedBox(height: 20),

            // Footer Options
            _buildSettingsSection(
              [
                _buildSettingsTile(
                  icon: Icons.info_outline,
                  title: 'About Us',
                  onTap: () => Navigator.pushNamed(context, '/settings/about'),
                  isDarkMode: widget.isDarkMode,
                ),
                _buildSettingsTile(
                  icon: Icons.mail_outline,
                  title: 'Contact Us',
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'ademyoussfi57@gmail.com',
                      queryParameters: {'subject': 'Contact Harmonia Support'},
                    );

                    try {
                      // Try launching email client first
                      await launchUrl(
                        emailLaunchUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      // If email client fails, try web Gmail as fallback
                      try {
                        final Uri gmailWebUri = Uri.parse(
                            'https://mail.google.com/mail/?view=cm&fs=1&to=ademyoussfi57@gmail.com&su=Contact%20Harmonia%20Support');
                        await launchUrl(gmailWebUri);
                      } catch (e2) {
                        // If both fail, show error message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'No email app found. Please install an email app or use a web browser.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  isDarkMode: widget.isDarkMode,
                ),
              ],
              isDarkMode: widget.isDarkMode,
            ),
            SizedBox(height: 20),

            // Logout Section
            _buildSettingsSection(
              [
                _buildSettingsTile(
                  icon: Icons.logout,
                  title: 'log out',
                  onTap: () {},
                  isDarkMode: widget.isDarkMode,
                  isLogout: true,
                ),
              ],
              isDarkMode: widget.isDarkMode,
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(List<Widget> tiles, {required bool isDarkMode}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: tiles),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Function() onTap,
    required bool isDarkMode,
    bool isEmergency = false,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isEmergency
            ? Colors.red
            : (isLogout
                ? Colors.red
                : (isDarkMode ? Colors.white : Color(0xFF87CEEB))),
        size: 28,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isEmergency || isLogout ? Colors.red : null,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isDarkMode ? Colors.white54 : Colors.grey,
      ),
      onTap: onTap,
    );
  }

  // Add this helper function at the bottom of the class
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
