import 'package:flutter/material.dart';
import 'package:harmonia/pages/content/settings/daily_files_page.dart';
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
// UPDATED: Changed from hourly_notification_service to enhanced_notification_service
import 'services/hourly_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Tunis'));

  // UPDATED: Using EnhancedNotificationService instead of HourlyNotificationService
  await EnhancedNotificationService.initialize();

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
    _initialize10MinuteNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App resumed - checking 10-minute notifications...');
        _checkAndReschedule10MinuteNotifications();
        break;
      case AppLifecycleState.paused:
        print('📱 App paused - ensuring 10-minute notifications are scheduled...');
        _ensure10MinuteNotificationsScheduled();
        break;
      case AppLifecycleState.detached:
        print('📱 App detached - final 10-minute notification check...');
        _ensure10MinuteNotificationsScheduled();
        break;
      default:
        break;
    }
  }

  // UPDATED: Renamed and using EnhancedNotificationService
  Future<void> _initialize10MinuteNotifications() async {
    try {
      print('🔧 Initializing 10-minute wellness notifications...');
      await Future.delayed(const Duration(seconds: 2));
      await EnhancedNotificationService.checkAndRescheduleIfNeeded();

      // Enable 10-minute notifications by default
      await EnhancedNotificationService.set10MinuteNotifications(true);

      print('✅ 10-minute notifications initialized successfully');
    } catch (e) {
      print('❌ Error initializing 10-minute notifications: $e');
    }
  }

  // UPDATED: Using EnhancedNotificationService
  Future<void> _checkAndReschedule10MinuteNotifications() async {
    try {
      await EnhancedNotificationService.checkAndRescheduleIfNeeded();

      // Get notification stats
      final stats = await EnhancedNotificationService.getNotificationStats();
      print('📊 Notification stats: ${stats['tenMinute']} active 10-minute notifications');
    } catch (e) {
      print('❌ Error checking 10-minute notifications: $e');
    }
  }

  // UPDATED: Using EnhancedNotificationService
  Future<void> _ensure10MinuteNotificationsScheduled() async {
    try {
      await EnhancedNotificationService.reschedule10MinuteNotifications();
      print('🔄 10-minute notifications rescheduled for background delivery');
    } catch (e) {
      print('❌ Error ensuring 10-minute notifications: $e');
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
        '/settings/daily_files': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          return DailyFilesPage(
            entries: args?['entries'] ?? [],
            isDarkMode: args?['isDarkMode'] ?? _isDarkMode,
          );
        },
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

    return const SplashScreen();
  }
}