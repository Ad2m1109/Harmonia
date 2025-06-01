import 'package:flutter/material.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("slm"),
        actions: [
          Icon(Icons.car_crash_outlined)
        ],
          ),
      body: Container(
        color: Colors.lightBlue,
          child: Center(child: Text('Reminders Page'))),
      floatingActionButton: Container(
        height: 50,
        color: Colors.red,
      ),
    );
  }
}
