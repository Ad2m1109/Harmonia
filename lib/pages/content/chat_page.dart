import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

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

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _recognizedText = '';

  // Profile data variables
  String? _firstName;
  String? _familyName;
  String? _birthday;
  String? _gender;
  String? _description;
  String? _address;
  String? _phoneNumber;

  // Additional support data
  Map<String, String> _emergencyContacts = {};
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _familyMembers = [];
  List<String> _medications = [];
  List<String> _importantPlaces = [];
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeech();
    _initializeTts();
    _loadAllData();
  }

  Future<void> _initializeSpeech() async {
    bool hasPermission = await _speech.initialize(
      onStatus: (status) {
        setState(() {
          _isListening = status == 'listening';
        });
      },
      onError: (error) => print('Speech recognition error: $error'),
    );
    if (!hasPermission) {
      await Permission.microphone.request();
    }
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfileData(),
      _loadReminders(),
      _loadFamilyMembers(),
      _loadEvents(),
    ]);
    _sendWelcomeMessage();
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
          setState(() {
            _firstName = csvTable[0][0];
            _familyName = csvTable[0][1];
            _birthday = csvTable[0][2];
            _gender = csvTable[0][3];
            _description = csvTable[0][4];
            if (csvTable[0].length > 5) _address = csvTable[0][5];
            if (csvTable[0].length > 6) _phoneNumber = csvTable[0][6];
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadReminders() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tasks.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(contents);
        setState(() {
          _reminders = csvTable
              .map((row) => {
            'text': row[0],
            'date': DateTime.parse(row[1]),
            'time': row[2],
            'type': row[3],
            'audioPath': row[4],
            'isCompleted': row[5] == 'true',
          })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading reminders: $e');
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
        setState(() {
          _familyMembers = csvTable
              .map((row) => {
            'name': row[0],
            'relation': row[1],
            'imagePath': row[2],
            'voicePath': row[3],
          })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading family members: $e');
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

  void _sendWelcomeMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final welcomeMessage = ChatMessage(
        text:
        "Hello ${_firstName ?? 'there'}! I'm here to help you throughout your day. You can ask me about your personal information, family, medications, past events and memories, or anything else you need help remembering. How are you feeling today?",
        isUser: false,
      );
      setState(() {
        _messages.insert(0, welcomeMessage);
      });
      _speak(welcomeMessage.text);
    });
  }

  void _speak(String text) async {
    await _flutterTts.stop(); // Stop any ongoing speech
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          setState(() {
            _isListening = status == 'listening';
          });
        },
        onError: (error) {
          print('Speech recognition error: $error');
          setState(() {
            _isListening = false;
          });
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
              _textController.text = _recognizedText;
              if (result.finalResult) {
                _isListening = false;
                if (_recognizedText.isNotEmpty) {
                  _handleSubmitted(_recognizedText);
                }
              }
            });
          },
        );
      } else {
        setState(() => _isListening = false);
        await Permission.microphone.request();
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  String _formatEventsForContext() {
    if (_events.isEmpty) return 'No events or memories recorded yet.';

    return _events.map((event) {
      String eventInfo = '- ${event.name} (${event.date})';
      if (event.description.isNotEmpty) {
        eventInfo += ': ${event.description}';
      }
      if (event.voicePath != null) {
        eventInfo += ' [Has voice recording]';
      }
      if (event.imagePaths.isNotEmpty) {
        eventInfo += ' [Has ${event.imagePaths.length} image(s)]';
      }
      return eventInfo;
    }).join('\n');
  }

  String _getRecentEvents() {
    if (_events.isEmpty) return 'No recent events found.';

    final sortedEvents = List<Event>.from(_events);
    sortedEvents.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.date.split('/').reversed.join('-'));
        final dateB = DateTime.parse(b.date.split('/').reversed.join('-'));
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    final recentEvents = sortedEvents.take(5).toList();
    return recentEvents.map((event) => '${event.name} on ${event.date}').join(', ');
  }

  Future<String> _getGeminiResponse(String message) async {
    const String apiKey = 'AIzaSyAVRvg9CgENzVKqb4EkM1fECf8L9UkHckw'; // Replace with your actual API key
    final String url =
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final contextPrompt = '''
    You are a compassionate AI assistant helping someone with Alzheimer's disease. Here's their information:

    PERSONAL DETAILS:
    - Name: $_firstName $_familyName
    - Birthday: $_birthday
    - Gender: $_gender
    - Description: ${_description ?? 'No additional information available.'}

    FAMILY MEMBERS:
    ${_familyMembers.map((member) => '- ${member['name']} (${member['relation']})').join('\n')}

    DAILY TASKS AND REMINDERS:
    ${_reminders.map((task) => '- ${task['text']} at ${task['time']} on ${task['date'].day}/${task['date'].month}/${task['date'].year}').join('\n')}

    LIFE EVENTS AND MEMORIES:
    ${_formatEventsForContext()}

    RECENT EVENTS:
    ${_getRecentEvents()}

    INSTRUCTIONS FOR RESPONSES:
    1. Always be patient, kind, and reassuring
    2. Use simple, clear language
    3. If they ask about family members, provide detailed information about relationships
    4. If they ask about tasks or medications, check the reminders list
    5. If they ask about past events, memories, or "what happened when", refer to the life events list
    6. If they ask about recent activities or memories, mention the recent events
    7. Always validate their feelings and provide emotional support
    8. If they seem confused, gently remind them using their profile information
    9. Keep responses focused and easy to understand
    10. When mentioning events, include the date to help with context
    11. If they ask about specific dates or time periods, search through the events for matches
    
    User message: "$message"

    Respond as their helpful, caring AI companion who knows their personal information and life history, and wants to help them feel safe and supported.
    ''';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': contextPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 800,
            'topK': 40,
            'topP': 0.95,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return 'I\'m here to help you. Could you please ask me again?';
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return 'I\'m having trouble right now, but I\'m still here to help you. Please try again.';
      }
    } catch (e) {
      print('Network Error: $e');
      return 'I can\'t connect right now, but remember: your name is $_firstName, and you can always call your emergency contacts if you need help.';
    }
  }

  void _handleSubmitted(String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;

    if (_isEmergencyMessage(text)) {
      _handleEmergencyResponse(text);
      return;
    }

    ChatMessage userMessage = ChatMessage(
      text: text,
      isUser: true,
    );

    setState(() {
      _messages.insert(0, userMessage);
      _isLoading = true;
    });

    String botResponse = await _getGeminiResponse(text);

    ChatMessage botMessage = ChatMessage(
      text: botResponse,
      isUser: false,
    );

    setState(() {
      _messages.insert(0, botMessage);
      _isLoading = false;
    });

    // Speak the bot's response
    _speak(botResponse);
  }

  bool _isEmergencyMessage(String message) {
    final emergencyKeywords = [
      'help',
      'emergency',
      'lost',
      'scared',
      'confused',
      'panic',
      'urgent'
    ];
    final lowerMessage = message.toLowerCase();
    return emergencyKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  void _handleEmergencyResponse(String message) {
    String emergencyResponse =
        "I'm here to help you, ${_firstName ?? 'dear'}. ";

    if (_emergencyContacts.isNotEmpty) {
      emergencyResponse += "Here are your emergency contacts:\n";
      _emergencyContacts.forEach((name, number) {
        emergencyResponse += "• $name: $number\n";
      });
    }

    if (_address != null) {
      emergencyResponse += "\nYour address is: $_address";
    }

    emergencyResponse +=
    "\n\nTake deep breaths. You are safe. If you need immediate help, call 911 or ask someone nearby to help you call your emergency contacts.";

    final emergencyMessage = ChatMessage(
      text: emergencyResponse,
      isUser: false,
      isEmergency: true,
    );

    setState(() {
      _messages.insert(0, emergencyMessage);
    });

    // Speak the emergency response
    _speak(emergencyResponse);
  }

  void _showEventsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('My Life Events & Memories'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_events.isEmpty)
                  const Text('No events or memories recorded yet.')
                else ...[
                  Text(
                    'You have ${_events.length} recorded memories:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._events.map((event) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event, color: Color(0xFF87CEEB), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                event.date,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              if (event.description.isNotEmpty)
                                Text(
                                  event.description,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hello ${_firstName ?? 'Friend'}',
          style:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF87CEEB),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note, color: Colors.white),
            onPressed: () => _showEventsDialog(context),
            tooltip: 'My Events',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickActionButton("Who am I?", Icons.person),
                  _quickActionButton("My family", Icons.family_restroom),
                  _quickActionButton("My memories", Icons.photo_album),
                  _quickActionButton("Recent events", Icons.history),
                  _quickActionButton("What day is it?", Icons.calendar_today),
                  _quickActionButton("Emergency help", Icons.emergency,
                      isEmergency: true),
                ],
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hi ${_firstName ?? 'there'}! Ask me anything you need help remembering.',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0 && _isLoading) {
                  return const TypingIndicator();
                }
                final message = _messages[_isLoading ? index - 1 : index];
                return GestureDetector(
                  onTap: () => _speak(message.text),
                  child: message,
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(String text, IconData icon,
      {bool isEmergency = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton.icon(
        onPressed: () => _handleSubmitted(text),
        icon: Icon(icon, size: 16),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEmergency ? Colors.red : const Color(0xFF87CEEB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(25.0),
              ),
              child: TextField(
                controller: _textController,
                enabled: !_isLoading,
                maxLines: null,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Ask me about your memories, family, or anything...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                ),
                onSubmitted: _isLoading ? null : _handleSubmitted,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Container(
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : const Color(0xFF87CEEB),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
              ),
              onPressed: _startListening,
            ),
          ),
          const SizedBox(width: 12.0),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey : const Color(0xFF87CEEB),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading
                  ? null
                  : () => _handleSubmitted(_textController.text),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContacts(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Contacts'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_emergencyContacts.isEmpty)
                  const Text('No emergency contacts available.')
                else
                  ..._emergencyContacts.entries.map(
                        (contact) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFF87CEEB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(contact.value),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'In case of emergency, dial 911',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showPersonalInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('My Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoItem('Name', '$_firstName $_familyName'),
                _infoItem('Birthday', _birthday ?? 'Not provided'),
                _infoItem('Address', _address ?? 'Not provided'),
                _infoItem('Phone', _phoneNumber ?? 'Not provided'),
                if (_familyMembers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Family Members:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._familyMembers.map((member) => Text('• $member')),
                ],
                if (_medications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Medications:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._medications.map((med) => Text('• $med')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('How I Can Help You'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'I\'m here to help you remember important information and support you throughout your day.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text('You can ask me about:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _helpItem('Your name and personal information'),
                _helpItem('Family members and emergency contacts'),
                _helpItem('Your past events, memories, and experiences'),
                _helpItem('What happened on specific dates or occasions'),
                _helpItem('Recent activities and events'),
                _helpItem('Your medications and when to take them'),
                _helpItem('Today\'s date and what day it is'),
                _helpItem('Your address and phone number'),
                _helpItem('How you\'re feeling or if you need support'),
                const SizedBox(height: 16),
                const Text('Example questions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _helpItem('"What\'s my name?"'),
                _helpItem('"Who are my family members?"'),
                _helpItem('"What events do I have recorded?"'),
                _helpItem('"What happened in [month/year]?"'),
                _helpItem('"Tell me about my recent activities"'),
                _helpItem('"What did I do for my birthday?"'),
                _helpItem('"I feel confused, can you help?"'),
                _helpItem('"What\'s my address?"'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _helpItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: Color(0xFF87CEEB), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF87CEEB),
            child: Icon(Icons.assistant, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'I\'m thinking...',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Opacity(
                            opacity:
                            (_animationController.value + index * 0.3) %
                                1.0,
                            child: const Text(
                              '●',
                              style: TextStyle(color: Color(0xFF87CEEB)),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isEmergency = false,
  });

  final String text;
  final bool isUser;
  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor:
              isEmergency ? Colors.red : const Color(0xFF87CEEB),
              child: Icon(
                isEmergency ? Icons.emergency : Icons.assistant,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF87CEEB)
                    : (isEmergency ? Colors.red.shade50 : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
                border: isEmergency
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isEmergency ? Colors.red.shade800 : Colors.black87),
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: isEmergency ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}