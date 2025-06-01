import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/reminders'),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications),
                Text('Reminders', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/journal'),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book),
                Text('Journal', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/profiles'),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person),
                Text('Profiles', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/games'),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.games),
                Text('Games', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings),
                Text('Settings', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
