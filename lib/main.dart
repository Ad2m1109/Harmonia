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
// UPDATED: Using the enhanced hourly notification service
import 'services/hourly_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone for Tunisia
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Tunis'));

  // UPDATED: Initialize the reliable hourly notification service
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
    _initializeHourlyNotifications();
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
        print('📱 App resumed - checking hourly notifications...');
        _checkAndRescheduleHourlyNotifications();
        break;
      case AppLifecycleState.paused:
        print('📱 App paused - ensuring hourly notifications are active...');
        _ensureHourlyNotificationsScheduled();
        break;
      case AppLifecycleState.detached:
        print('📱 App detached - final hourly notification check...');
        _ensureHourlyNotificationsScheduled();
        break;
      case AppLifecycleState.inactive:
        print('📱 App inactive - maintaining hourly notifications...');
        break;
      default:
        break;
    }
  }

  // UPDATED: Initialize reliable hourly wellness notifications
  Future<void> _initializeHourlyNotifications() async {
    try {
      print('🔧 Initializing hourly wellness notifications...');

      // Wait a moment for the app to fully initialize
      await Future.delayed(const Duration(seconds: 3));

      // Check if notifications need rescheduling
      await EnhancedNotificationService.checkAndRescheduleIfNeeded();

      // Enable hourly notifications by default for wellness routine
      await EnhancedNotificationService.setHourlyNotifications(true);

      // Schedule a quick test (optional - remove in production)
      // await EnhancedNotificationService.scheduleQuickTest();

      print('✅ Hourly wellness notifications initialized successfully');

      // Show initialization stats
      final stats = await EnhancedNotificationService.getNotificationStats();
      print('📊 Notification stats: ${stats['hourly']} hourly notifications active');

    } catch (e) {
      print('❌ Error initializing hourly notifications: $e');
      // Retry initialization after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _initializeHourlyNotifications();
      });
    }
  }

  // UPDATED: Check and reschedule hourly notifications when app resumes
  Future<void> _checkAndRescheduleHourlyNotifications() async {
    try {
      print('🔄 Checking hourly notification status...');

      await EnhancedNotificationService.checkAndRescheduleIfNeeded();

      // Get updated notification stats
      final stats = await EnhancedNotificationService.getNotificationStats();
      print('📊 Current notification stats:');
      print('   📅 Hourly notifications: ${stats['hourly']}');
      print('   ⏰ Quick reminders: ${stats['quickReminders']}');
      print('   📋 Total pending: ${stats['total']}');

      // If we have very few notifications, force reschedule
      if (stats['hourly']! < 12) {
        print('⚠️ Low notification count detected, force rescheduling...');
        await EnhancedNotificationService.rescheduleHourlyNotifications();
      }

    } catch (e) {
      print('❌ Error checking hourly notifications: $e');
    }
  }

  // UPDATED: Ensure hourly notifications are scheduled when app goes to background
  Future<void> _ensureHourlyNotificationsScheduled() async {
    try {
      print('🔄 Ensuring hourly notifications are scheduled for background...');

      // Double-check that notifications are properly scheduled
      final stats = await EnhancedNotificationService.getNotificationStats();

      if (stats['hourly']! == 0) {
        print('⚠️ No hourly notifications found! Rescheduling immediately...');
        await EnhancedNotificationService.rescheduleHourlyNotifications();
      } else {
        print('✅ ${stats['hourly']} hourly notifications are active for background delivery');
      }

    } catch (e) {
      print('❌ Error ensuring hourly notifications: $e');
      // Force reschedule on error
      try {
        await EnhancedNotificationService.rescheduleHourlyNotifications();
      } catch (retryError) {
        print('❌ Failed to reschedule on retry: $retryError');
      }
    }
  }

  // Method to manually trigger notification test (you can call this from settings)
  Future<void> testNotificationSystem() async {
    try {
      print('🧪 Testing notification system...');
      await EnhancedNotificationService.scheduleQuickTest();

      // Show user feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧪 Test notification scheduled for 2 minutes! Close the app to test background delivery.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('❌ Error testing notifications: $e');
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
      home: AppInitializer(
        toggleTheme: toggleTheme,
        isDarkMode: _isDarkMode,
        testNotifications: testNotificationSystem, // Pass test function
      ),
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
  final Function? testNotifications; // Optional test function

  const AppInitializer({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    this.testNotifications,
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
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isFirstLaunch = prefs.getBool('first_launch') ?? true;

      // If it's first launch, set up notifications
      if (isFirstLaunch) {
        print('🎯 First launch detected - setting up hourly notifications...');
        await EnhancedNotificationService.setHourlyNotifications(true);
        await prefs.setBool('first_launch', false);
      }

      setState(() {
        _isFirstLaunch = isFirstLaunch;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Error checking first launch: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? Colors.black : Colors.white,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('🔧 Setting up hourly wellness notifications...'),
            ],
          ),
        ),
      );
    }

    return const SplashScreen();
  }
}