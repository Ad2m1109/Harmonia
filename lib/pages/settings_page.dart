import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Color(0xFF87CEEB),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(Icons.person, color: Color(0xFF4A9B8E)),
            title: Text('Profile'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.notifications, color: Color(0xFF4A9B8E)),
            title: Text('Notifications'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.security, color: Color(0xFF4A9B8E)),
            title: Text('Privacy'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.help, color: Color(0xFF4A9B8E)),
            title: Text('Help'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
