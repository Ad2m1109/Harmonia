import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/reminders'),
              child: const Text('Reminders'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/journal'),
              child: const Text('Journal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/profiles'),
              child: const Text('Profiles'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/games'),
              child: const Text('Games'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
