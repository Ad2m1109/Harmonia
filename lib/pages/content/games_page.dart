import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class Event {
  String id;
  String name;
  String date;
  String description;
  String? voicePath;
  List<String> imagePaths;

  Event({
    required this.id,
    required this.name,
    required this.date,
    this.description = '',
    this.voicePath,
    this.imagePaths = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date,
    'description': description,
    'voicePath': voicePath,
    'imagePaths': imagePaths,
  };

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'],
    name: json['name'],
    date: json['date'],
    description: json['description'] ?? '',
    voicePath: json['voicePath'],
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
  );
}

class GameEntry {
  final DateTime timestamp;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String difficultyLevel;
  final int currentScore;
  final int totalQuestions;
  final int streakCount;
  final String feedback;

  GameEntry({
    required this.timestamp,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.difficultyLevel,
    required this.currentScore,
    required this.totalQuestions,
    required this.streakCount,
    required this.feedback,
  });

  List<dynamic> toCsvRow() {
    return [
      timestamp.toIso8601String(),
      question,
      userAnswer,
      correctAnswer,
      isCorrect.toString(),
      difficultyLevel,
      currentScore,
      totalQuestions,
      streakCount,
      feedback,
    ];
  }

  static List<String> get csvHeaders => [
    'Timestamp',
    'Question',
    'User Answer',
    'Correct Answer',
    'Is Correct',
    'Difficulty Level',
    'Current Score',
    'Total Questions',
    'Streak Count',
    'Feedback',
  ];
}

class GamesPage extends StatefulWidget {
  final bool isDarkMode;

  const GamesPage({super.key, this.isDarkMode = false});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _familyMembers = [];
  Map<String, String> _profileData = {};
  List<Event> _events = [];
  List<GameEntry> _gameEntries = [];
  String _currentQuestion = '';
  String _correctAnswer = '';
  List<String> _options = [];
  int _score = 0;
  int _totalQuestions = 0;
  bool _showResult = false;
  bool _isCorrect = false;
  String _currentFeedback = '';
  String _difficultyLevel = 'easy';
  int _streakCount = 0;
  int _correctAnswersInLevel = 0;
  bool _isLoading = false;
  bool _isProcessingAnswer = false;
  List<String> _recentQuestions = [];
  late FlutterTts _flutterTts;

  static const int ANSWERS_TO_ADVANCE = 3;
  static const int STREAK_TO_ADVANCE = 2;

  final List<String> _motivationalMessages = [
    "🌟 Your memories are precious treasures waiting to be discovered!",
    "💪 Every question you answer strengthens your mind!",
    "🧠 You're doing amazing! Keep exercising that wonderful brain!",
    "❤️ Take your time - there's no rush, just progress!",
    "🌈 Each memory you recall is a beautiful gift!",
    "⭐ You're stronger than you know - keep going!",
    "🎯 Focus on the positive - you're making great progress!",
    "💝 Your effort matters more than perfect answers!",
    "🌸 Be kind to yourself - you're doing wonderfully!",
    "🔥 Your determination is inspiring!",
  ];

  late AnimationController _questionAnimationController;
  late AnimationController _feedbackAnimationController;
  late AnimationController _motivationAnimationController;
  late Animation<double> _questionFadeAnimation;
  late Animation<double> _feedbackScaleAnimation;
  late Animation<double> _motivationFadeAnimation;
  late Animation<double> _motivationScaleAnimation;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _initializeTts();
    _initializeAnimations();
    _loadData();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  void _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _initializeAnimations() {
    _questionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _motivationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _questionFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _questionAnimationController,
      curve: Curves.easeInOut,
    ));

    _feedbackScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.elasticOut,
    ));

    _motivationFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _motivationAnimationController,
      curve: Curves.easeInOut,
    ));

    _motivationScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _motivationAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _questionAnimationController.dispose();
    _feedbackAnimationController.dispose();
    _motivationAnimationController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFamilyMembers(),
      _loadProfileData(),
      _loadEvents(),
      _loadGameHistory(),
    ]);
    _generateQuestion();
  }

  Future<void> _loadGameHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/memory_game_history.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(contents);

        if (csvTable.isNotEmpty && csvTable[0].contains('Timestamp')) {
          csvTable.removeAt(0);
        }

        _gameEntries = csvTable.map((row) {
          return GameEntry(
            timestamp: DateTime.parse(row[0]),
            question: row[1],
            userAnswer: row[2],
            correctAnswer: row[3],
            isCorrect: row[4] == 'true',
            difficultyLevel: row[5],
            currentScore: int.parse(row[6].toString()),
            totalQuestions: int.parse(row[7].toString()),
            streakCount: int.parse(row[8].toString()),
            feedback: row[9],
          );
        }).toList();

        print('Loaded ${_gameEntries.length} game history entries');
      }
    } catch (e) {
      print('Error loading game history: $e');
    }
  }

  Future<void> _saveGameEntry(GameEntry entry) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/memory_game_history.csv');

      bool fileExists = await file.exists();
      List<List<dynamic>> rows = [];

      if (fileExists) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          rows = const CsvToListConverter().convert(contents);
        }
      }

      if (rows.isEmpty) {
        rows.add(GameEntry.csvHeaders);
      }

      rows.add(entry.toCsvRow());

      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      _gameEntries.add(entry);

      print('Game entry saved successfully');
    } catch (e) {
      print('Error saving game entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save game data: $e')),
        );
      }
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/family_members.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(contents);

        _familyMembers = csvTable
            .map((row) => {
          'name': row[0],
          'relation': row[1],
          'imagePath': row[2],
        })
            .toList();
      }
    } catch (e) {
      print('Error loading family members: $e');
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(contents);
        if (csvTable.isNotEmpty) {
          _profileData = {
            'firstName': csvTable[0][0] ?? '',
            'familyName': csvTable[0][1] ?? '',
            'birthday': csvTable[0][2] ?? '',
            'gender': csvTable[0][3] ?? '',
            'description': csvTable[0][4] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/events.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        setState(() {
          _events = jsonList.map((json) => Event.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error loading events: $e');
    }
  }

  String _formatEventsForQuestions() {
    if (_events.isEmpty) return 'No events or memories recorded yet.';

    return _events.map((event) {
      String eventInfo = '- ${event.name} on ${event.date}';
      if (event.description.isNotEmpty) {
        eventInfo += ' (${event.description})';
      }
      return eventInfo;
    }).join('\n');
  }

  void _generateQuestion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final aiQuestion = await _getQuestionFromAPI();

      setState(() {
        _currentQuestion = aiQuestion['question'] ?? 'Loading question...';
        _correctAnswer = aiQuestion['correct_answer'] ?? '';
        _options = List<String>.from(aiQuestion['options'] ?? []);
        _showResult = false;
        _totalQuestions++;
        _isLoading = false;
      });

      _recentQuestions.add(_currentQuestion);
      if (_recentQuestions.length > 5) {
        _recentQuestions.removeAt(0);
      }

      _questionAnimationController.forward();

      // Speak the question
      _speak(_currentQuestion);
    } catch (e) {
      print('Error generating question: $e');
      setState(() {
        _currentQuestion =
        'Unable to generate question. Please check your internet connection.';
        _correctAnswer = '';
        _options = [];
        _isLoading = false;
      });
      _speak(_currentQuestion);
    }
  }

  Future<Map<String, dynamic>> _getQuestionFromAPI() async {
    const String apiKey = 'AIzaSyAVRvg9CgENzVKqb4EkM1fECf8L9UkHckw'; // Replace with your actual API key
    final String url =
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final context = '''
      Create a memory quiz question for someone with Alzheimer's disease using this data:
      
      PERSONAL PROFILE: 
      ${_profileData.toString()}
      
      FAMILY MEMBERS: 
      ${_familyMembers.map((m) => '${m['name']} (${m['relation']})')}
      
      LIFE EVENTS & MEMORIES:
      ${_formatEventsForQuestions()}
      
      CURRENT DIFFICULTY: $_difficultyLevel
      CURRENT STREAK: $_streakCount
      PROGRESS IN LEVEL: $_correctAnswersInLevel/$ANSWERS_TO_ADVANCE
      
      RECENT QUESTIONS TO AVOID (do NOT repeat these or create very similar questions):
      ${_recentQuestions.isEmpty ? 'None yet' : _recentQuestions.map((q) => '- $q').join('\n')}
      
      Guidelines for $_difficultyLevel level:
      - EASY: Basic personal info (name, birthday), simple family recognition, basic event names, simple daily concepts
      - MEDIUM: Specific relationships, event dates, detailed family connections, event descriptions, life timeline questions
      - HARD: Complex event relationships, detailed memories, specific dates and contexts, connecting multiple events, advanced family dynamics
      
      Question Requirements:
      - Use simple, clear language appropriate for someone with memory challenges
      - Make questions personally meaningful using their actual data
      - Focus on positive memories and relationships
      - Include events, family, and personal information in questions
      - Always provide exactly 4 multiple choice options
      - Make sure one option is clearly correct
      - Include encouraging, memory-reinforcing explanations
      - When asking about events, use their actual recorded events
      - IMPORTANT: Create a completely different question from the recent questions listed above
      - Vary question types: sometimes ask about names, sometimes dates, sometimes relationships, sometimes event details
      - Be creative and avoid repetitive patterns
      
      Return JSON format ONLY (no other text):
      {
        "question": "clear, simple question text using their personal data (DIFFERENT from recent questions)",
        "correct_answer": "the correct answer",
        "options": ["4 options including correct one, shuffled"],
        "explanation": "encouraging explanation with memory reinforcement",
        "memory_tip": "helpful tip to remember this information"
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': context}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 1000,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final responseText =
          data['candidates'][0]['content']['parts'][0]['text'];

          final jsonStart = responseText.indexOf('{');
          final jsonEnd = responseText.lastIndexOf('}') + 1;

          if (jsonStart != -1 && jsonEnd != -1) {
            final jsonStr = responseText.substring(jsonStart, jsonEnd);
            final questionData = jsonDecode(jsonStr);

            if (questionData['question'] != null &&
                questionData['correct_answer'] != null &&
                questionData['options'] != null &&
                questionData['options'].length == 4) {
              return questionData;
            }
          }
        }
      }
      throw Exception('Invalid response from AI');
    } catch (e) {
      print('API Error: $e');
      throw Exception('Failed to generate question: $e');
    }
  }

  Future<String> _getResponseForAnswer(
      bool isCorrect, String explanation) async {
    const String apiKey = 'YOUR_API_KEY_HERE'; // Replace with your actual API key
    final String url =
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final String motivation =
    _motivationalMessages[Random().nextInt(_motivationalMessages.length)];

    String levelAdvancementMessage = '';
    if (isCorrect && _correctAnswersInLevel + 1 >= ANSWERS_TO_ADVANCE && _difficultyLevel != 'hard') {
      levelAdvancementMessage = ' 🎉 Congratulations! You\'re ready for the next level!';
    }

    final prompt = isCorrect
        ? '''
          Generate a warm, encouraging response for a correct answer for someone with Alzheimer's.
          Use celebration words like "Wonderful!", "Excellent!", "You remembered!"
          Include: $explanation
          Add this motivational message: $motivation
          Progress: ${_correctAnswersInLevel + 1}/$ANSWERS_TO_ADVANCE correct in $_difficultyLevel level
          Streak count: ${_streakCount + 1}
          Level advancement: $levelAdvancementMessage
          Keep it positive and affirming.
          Make it 2-3 sentences, warm and supportive.
          '''
        : '''
          Generate a very supportive, gentle response for an incorrect answer for someone with Alzheimer's.
          Use phrases like "That's okay", "Let's try together", "You're doing great"
          Never use words like "wrong" or "mistake"
          Include the correct answer naturally: $explanation
          Add this motivational message: $motivation
          Focus on encouragement and learning.
          Still on $_difficultyLevel level - every attempt helps you learn!
          Make it 2-3 sentences, gentle and supportive.
          ''';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 300,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        }
      }
      return isCorrect
          ? "Wonderful! You remembered correctly! 🌟$levelAdvancementMessage"
          : "That's perfectly okay. The answer is $explanation. You're doing great! 💙";
    } catch (e) {
      print('API Error: $e');
      return isCorrect
          ? "Excellent! You got it right! 🌟$levelAdvancementMessage"
          : "That's okay! The answer is $explanation. Keep going! 💙";
    }
  }

  void _checkAnswer(String selected) async {
    if (_isProcessingAnswer) return;

    _feedbackAnimationController.reset();

    setState(() {
      _isProcessingAnswer = true;
      _isCorrect = selected == _correctAnswer;
      _showResult = true;
      if (_isCorrect) {
        _score++;
        _streakCount++;
        _correctAnswersInLevel++;
      } else {
        _streakCount = 0;
      }
    });

    try {
      _feedbackAnimationController.forward();
      _autoAdjustDifficulty();

      final response = await _getResponseForAnswer(_isCorrect, _correctAnswer);

      if (mounted) {
        setState(() {
          _currentFeedback = response;
        });

        // Speak the feedback
        _speak(_currentFeedback);

        final gameEntry = GameEntry(
          timestamp: DateTime.now(),
          question: _currentQuestion,
          userAnswer: selected,
          correctAnswer: _correctAnswer,
          isCorrect: _isCorrect,
          difficultyLevel: _difficultyLevel,
          currentScore: _score,
          totalQuestions: _totalQuestions,
          streakCount: _streakCount,
          feedback: response,
        );

        await _saveGameEntry(gameEntry);

        final delay =
        Duration(milliseconds: min(6000, max(3000, response.length * 50)));

        await Future.delayed(delay);
        if (mounted) {
          _loadNextQuestion();
        }
      }
    } catch (e) {
      print('Error processing answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Something went wrong. Please try again.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAnswer = false;
        });
      }
    }
  }

  void _autoAdjustDifficulty() {
    if (_isCorrect) {
      if (_correctAnswersInLevel >= ANSWERS_TO_ADVANCE && _streakCount >= STREAK_TO_ADVANCE) {
        if (_difficultyLevel == 'easy') {
          setState(() {
            _difficultyLevel = 'medium';
            _correctAnswersInLevel = 0;
            _recentQuestions.clear();
          });
          _showLevelUpMessage('Medium');
        } else if (_difficultyLevel == 'medium') {
          setState(() {
            _difficultyLevel = 'hard';
            _correctAnswersInLevel = 0;
            _recentQuestions.clear();
          });
          _showLevelUpMessage('Hard');
        }
      }
    } else {
      double recentSuccessRate = _totalQuestions > 4 ? _score / _totalQuestions : 1.0;

      if (recentSuccessRate < 0.3 && _streakCount == 0) {
        if (_difficultyLevel == 'hard') {
          setState(() {
            _difficultyLevel = 'medium';
            _correctAnswersInLevel = 0;
            _recentQuestions.clear();
          });
        } else if (_difficultyLevel == 'medium' && _totalQuestions > 8) {
          setState(() {
            _difficultyLevel = 'easy';
            _correctAnswersInLevel = 0;
            _recentQuestions.clear();
          });
        }
      }
    }
  }

  void _showLevelUpMessage(String newLevel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Level Up! Welcome to $newLevel Level! 🎉'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
    _speak('Congratulations! You’ve leveled up to $newLevel level!');
  }

  void _loadNextQuestion() {
    setState(() {
      _showResult = false;
    });
    _questionAnimationController.reset();
    _feedbackAnimationController.reset();
    _generateQuestion();
  }

  Widget _buildProgressIndicator() {
    double successRate = _totalQuestions > 0 ? _score / _totalQuestions : 0;
    double levelProgress = _correctAnswersInLevel / ANSWERS_TO_ADVANCE;

    final backgroundColor = widget.isDarkMode ? Colors.grey[900] : Colors.blue.shade50;
    final borderColor = widget.isDarkMode ? Colors.grey[700] : Colors.blue.shade200;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = widget.isDarkMode ? Colors.grey[400] : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor!,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score: $_score/$_totalQuestions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Level: ${_difficultyLevel.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_gameEntries.isNotEmpty)
                    Text(
                      'History: ${_gameEntries.length} games',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_streakCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Streak: $_streakCount 🔥',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: $_correctAnswersInLevel/$ANSWERS_TO_ADVANCE',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: successRate,
            backgroundColor: widget.isDarkMode ? Colors.grey[700] : Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              successRate > 0.7
                  ? Colors.green
                  : successRate > 0.4
                  ? Colors.orange
                  : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          if (_difficultyLevel != 'hard')
            Column(
              children: [
                Text(
                  'Progress to next level',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: levelProgress,
                  backgroundColor: widget.isDarkMode ? Colors.grey[700] : Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final surfaceColor = widget.isDarkMode ? Colors.grey[900] : Colors.blue.shade50;
    final borderColor = widget.isDarkMode ? Colors.grey[700] : Colors.blue.shade200;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final primaryColor = widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Memory Game'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                  title: Text(
                    'How Memory Game Works',
                    style: TextStyle(color: textColor),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎯 The game automatically adjusts difficulty:',
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Easy: Basic personal info and simple facts',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        '• Medium: Family relationships and event details',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        '• Hard: Complex memories and connections',
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '📈 Get $_correctAnswersInLevel/$ANSWERS_TO_ADVANCE correct answers with a streak of $STREAK_TO_ADVANCE to advance!',
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '💪 Questions use your personal information, family members, and recorded life events to make them meaningful to you.',
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '📊 All your game progress is automatically saved for tracking.',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Got it!',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    CircularProgressIndicator(color: primaryColor)
                  else
                    FadeTransition(
                      opacity: _questionFadeAnimation,
                      child: GestureDetector(
                        onTap: () => _speak(_currentQuestion),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: borderColor!,
                            ),
                          ),
                          child: Text(
                            _currentQuestion,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (!_isLoading && _options.isNotEmpty)
                    ..._options.asMap().entries.map((entry) {
                      int index = entry.key;
                      String option = entry.value;
                      bool isCorrectOption = option == _correctAnswer;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ElevatedButton(
                            onPressed:
                            _showResult ? null : () => _checkAnswer(option),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 60),
                              backgroundColor: _showResult
                                  ? isCorrectOption
                                  ? Colors.green.shade600
                                  : widget.isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300
                                  : widget.isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.blue.shade100,
                              foregroundColor: _showResult && isCorrectOption
                                  ? Colors.white
                                  : textColor,
                              elevation: _showResult && isCorrectOption ? 8 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: widget.isDarkMode
                                      ? Colors.grey.shade600
                                      : Colors.blue.shade300,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_showResult && isCorrectOption)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(Icons.check_circle,
                                          color: Colors.white),
                                    ),
                                  Flexible(
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  if (_showResult)
                    ScaleTransition(
                      scale: _feedbackScaleAnimation,
                      child: GestureDetector(
                        onTap: () => _speak(_currentFeedback),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(top: 20),
                          decoration: BoxDecoration(
                            color: _isCorrect
                                ? (widget.isDarkMode ? Colors.green.shade900 : Colors.green.shade50)
                                : (widget.isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _isCorrect ? Colors.green : Colors.blue,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _isCorrect ? Icons.celebration : Icons.favorite,
                                size: 40,
                                color: _isCorrect ? Colors.green : Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _currentFeedback,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: _isCorrect
                                      ? (widget.isDarkMode ? Colors.green.shade300 : Colors.green.shade800)
                                      : (widget.isDarkMode ? Colors.blue.shade300 : Colors.blue.shade800),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
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
}