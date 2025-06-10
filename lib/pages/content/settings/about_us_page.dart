import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  final bool isDarkMode;

  const AboutUsPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Color(0xFF2C3E50);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Color(0xFF87CEEB),
        elevation: 0,
        title: Text(
          'About Us - Harmonia App',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with light blue background
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF87CEEB),
                    Color(0xFFB8E6FF),
                    Color(0xFFE6F7FF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'At '),
                        TextSpan(
                          text: 'Harmonia',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: ', we believe technology should empower, not complicate. Our app is designed with love for seniors and caregivers, offering a simple, private, and caring way to manage daily wellbeing.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Family illustration
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        'assets/9.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why We Created Harmonia',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  _buildFeatureItem(
                    '👴',
                    'For Seniors:',
                    'Easy-to-use tools for independence without confusing tech.',
                    textColor
                  ),
                  
                  _buildFeatureItem(
                    '👨‍👩‍👧‍👦',
                    'For Families:',
                    'Stay connected and informed with your loved one\'s care.',
                    textColor
                  ),
                  
                  _buildFeatureItem(
                    '🔒',
                    'Your Privacy First:',
                    'No clouds, no ads – just your data, stored securely offline.',
                    textColor
                  ),
                  
                  SizedBox(height: 24),
                  
                  Text(
                    'Our Promise',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  _buildPromiseItem(
                    'Big buttons, clear text, voice control',
                    textColor
                  ),
                  _buildPromiseItem(
                    'No internet needed\n(unless you choose backup)',
                    textColor
                  ),
                  _buildPromiseItem(
                    'Made with feedback from real seniors and caregivers',
                    textColor
                  ),
                  
                  SizedBox(height: 30),
                  
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF87CEEB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF4A90E2).withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        'From our family to yours with care. 💙',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(0xFF4A90E2).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Questions?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A90E2),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF4A90E2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              'ademyoussfi57@gmail.com',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4A90E2),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String title, String description, Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Color(0xFF4A90E2).withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFF4A90E2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromiseItem(String text, Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFF87CEEB),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}