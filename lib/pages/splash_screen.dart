import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-navigate after animation completes
    _navigateAfterAnimation();
  }

  Future<void> _navigateAfterAnimation() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if it's first launch
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;

    if (isFirstLaunch) {
      // If first launch, go to welcome page and mark first launch complete
      await prefs.setBool('first_launch', false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    } else {
      // If not first launch, go directly to home page
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _handleTapNavigation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;

    if (isFirstLaunch) {
      await prefs.setBool('first_launch', false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _handleTapNavigation,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeInAnimation.value,
              child: Image.asset(
                'assets/2.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),
      ),
    );
  }
}
