import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:harmonia/pages/welcome_page.dart';
import 'package:harmonia/pages/onboarding_page.dart';
import 'package:harmonia/pages/home_page.dart';
import 'pages/content/reminders_page.dart';
import 'pages/content/journal_page.dart';
import 'pages/content/profiles_page.dart';
import 'pages/content/games_page.dart';
import 'pages/content/settings/settings_page.dart';
import 'package:harmonia/pages/splash_screen.dart';
import 'pages/content/chat_page.dart';
import 'package:harmonia/pages/content/settings/password_page.dart';
import 'package:harmonia/pages/content/settings/profile_page.dart';
import 'package:harmonia/pages/content/settings/add_reminders_page.dart';
import 'package:harmonia/pages/content/settings/add_family_page.dart';
import 'package:harmonia/pages/content/settings/about_us_page.dart';
import 'package:harmonia/pages/content/settings/security_page.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// Import the hourly notification service
import 'services/hourly_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone for notifications
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Tunis')); // Set your timezone (Tunisia)

  // Initialize hourly notification service
  await HourlyNotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHourlyNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
      // App is in foreground - check and reschedule if needed
        _checkAndRescheduleNotifications();
        break;
      case AppLifecycleState.paused:
      // App is in background - ensure notifications are scheduled
        _ensureNotificationsScheduled();
        break;
      case AppLifecycleState.detached:
      // App is being terminated - final notification scheduling
        _ensureNotificationsScheduled();
        break;
      default:
        break;
    }
  }

  // Initialize hourly notifications when app starts
  Future<void> _initializeHourlyNotifications() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Wait for app to fully load
      await HourlyNotificationService.checkAndRescheduleIfNeeded();
    } catch (e) {
      print('Error initializing hourly notifications: $e');
    }
  }

  // Check and reschedule notifications when app comes to foreground
  Future<void> _checkAndRescheduleNotifications() async {
    try {
      await HourlyNotificationService.checkAndRescheduleIfNeeded();
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }

  // Ensure notifications are scheduled when app goes to background
  Future<void> _ensureNotificationsScheduled() async {
    try {
      await HourlyNotificationService.rescheduleHourlyNotifications();
    } catch (e) {
      print('Error ensuring notifications: $e');
    }
  }

  void toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harmonia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: AppInitializer(toggleTheme: toggleTheme, isDarkMode: _isDarkMode),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomePage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/home': (context) => HomePage(
          toggleTheme: toggleTheme,
          isDarkMode: _isDarkMode,
        ),
        '/journal': (context) => const JournalPage(),
        '/settings': (context) => SettingsPage(isDarkMode: _isDarkMode),
        '/reminders': (context) => const RemindersPage(),
        '/profiles': (context) => ProfilesPage(isDarkMode: _isDarkMode),
        '/games': (context) => GamesPage(isDarkMode: _isDarkMode),
        '/chat': (context) => const ChatPage(),
        '/settings/password': (context) =>
            PasswordPage(isDarkMode: _isDarkMode),
        '/settings/profile': (context) => ProfilePage(isDarkMode: _isDarkMode),
        '/settings/add_reminders': (context) =>
            AddRemindersPage(isDarkMode: _isDarkMode),
        '/settings/add_family': (context) =>
            AddFamilyPage(isDarkMode: _isDarkMode),
        '/settings/about': (context) => AboutUsPage(isDarkMode: _isDarkMode),
        '/settings/security': (context) =>
            SecurityPage(isDarkMode: _isDarkMode),
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const AppInitializer({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;

    setState(() {
      _isFirstLaunch = isFirstLaunch;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Always show splash screen first, but handle navigation differently based on first launch
    return const SplashScreen();
  }
}