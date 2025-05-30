import 'package:flutter/material.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/reminders_page.dart';
import 'pages/journal_page.dart';
import 'pages/profiles_page.dart';
import 'pages/games_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harmonia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/home': (context) => const HomePage(),
        '/reminders': (context) => const RemindersPage(),
        '/journal': (context) => const JournalPage(),
        '/profiles': (context) => const ProfilesPage(),
        '/games': (context) => const GamesPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
