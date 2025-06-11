import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_currentPage < 4) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: [
                Image.asset('assets/3.png', fit: BoxFit.cover),
                Image.asset('assets/4.png', fit: BoxFit.cover),
                Image.asset('assets/5.png', fit: BoxFit.cover),
                Image.asset('assets/6.png', fit: BoxFit.cover),
                Image.asset('assets/7.jpg', fit: BoxFit.cover),
              ],
            ),
          ),
          Positioned(
            bottom: 58, 
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? const Color.fromARGB(255, 1, 165, 235)
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
