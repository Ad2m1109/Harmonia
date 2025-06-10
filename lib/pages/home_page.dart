import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final Function? toggleTheme;
  final bool isDarkMode;

  const HomePage({
    super.key,
    this.toggleTheme,
    this.isDarkMode = false,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _tasks = [];
  Map<DateTime, bool> _hasImportantIncomplete = {};
  String? _emergencyNumber;
  List<Map<String, dynamic>> _familyMembers = []; // Add this line

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadEmergencyNumber();
    _loadFamilyMembers(); // Add this line
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTasks();
    _loadEmergencyNumber();
    _loadFamilyMembers(); // Add this line
  }

  // Add this method
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
                    'imagePath': row[2],
                  })
              .toList();

          // Shuffle the list to get random members
          _familyMembers.shuffle();
        });
      }
    } catch (e) {
      print('Error loading family members: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tasks.csv');

      if (await file.exists()) {
        final contents = await file.readAsString();
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(contents);

        setState(() {
          _tasks = csvTable.map((row) {
            final date = DateTime.parse(row[1]);
            final isImportant = row[3].contains('important');
            final isCompleted = row[5] == 'true';

            if (isImportant && !isCompleted) {
              _hasImportantIncomplete[date] = true;
            }

            return {
              'text': row[0],
              'date': date,
              'time': row[2],
              'type': row[3],
              'audioPath': row[4],
              'isCompleted': isCompleted,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading tasks: $e');
    }
  }

  Future<void> _loadEmergencyNumber() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/emergency.txt');
      print("Checking emergency file at: ${file.path}"); // Debug print

      if (await file.exists()) {
        final number = await file.readAsString();
        // Clean the number (remove whitespace, newlines, etc.)
        final cleanNumber = number.trim();
        print("Loaded emergency number: $cleanNumber"); // Debug print

        if (cleanNumber.isNotEmpty) {
          setState(() {
            _emergencyNumber = cleanNumber;
          });
        } else {
          print("Emergency file is empty"); // Debug print
        }
      } else {
        print("Emergency file does not exist"); // Debug print
      }
    } catch (e) {
      print('Error loading emergency number: $e');
    }
  }

  Future<void> _handleEmergencyCall() async {
    if (_emergencyNumber != null && _emergencyNumber!.isNotEmpty) {
      // Clean the number and remove any non-digit characters except + and spaces
      String cleanNumber =
          _emergencyNumber!.replaceAll(RegExp(r'[^\d+\s-()]'), '');

      final Uri callUri = Uri(
        scheme: 'tel',
        path: cleanNumber,
      );

      try {
        print("Attempting to call: $cleanNumber"); // Debug print
        await launchUrl(
          callUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        print("Error launching call: $e"); // Debug print
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not make emergency call. Please check if you have a phone app installed.'),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No emergency number set. Please set it in settings.'),
          ),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  List<DateTime> _getWeekDays() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  String _getDayLabel(DateTime date) {
    DateTime now = DateTime.now();
    if (date.day == now.day && date.month == now.month) {
      return 'Today';
    }
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[date.weekday - 1];
  }

  Widget _buildCalendarDay(String day, String date, bool isCompleted,
      {bool isToday = false}) {
    final DateTime currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      int.parse(date),
    );
    final bool hasImportantTask = _hasImportantIncomplete[currentDate] ?? false;

    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isToday ? Color(0xFF2C3E50) : Color(0xFF7B8794),
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: hasImportantTask
                ? Colors.red
                : (isCompleted
                    ? Color(0xFF4A9B8E)
                    : (isToday ? Color(0xFF4A9B8E) : Colors.transparent)),
            shape: BoxShape.circle,
            border: !isCompleted && !isToday && !hasImportantTask
                ? Border.all(color: Colors.white.withOpacity(0.5), width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              date,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: hasImportantTask || isCompleted || isToday
                    ? Colors.white
                    : Color(0xFF7B8794),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextReminder() {
    if (_tasks.isEmpty) return Text('No upcoming reminders');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcomingTasks = _tasks.where((task) {
      final taskDate = task['date'] as DateTime;
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);

      // Only consider today's tasks
      if (taskDay != today) return false;

      // Parse task time
      final timeComponents = task['time'].toString().split(':');
      final taskHour = int.parse(timeComponents[0]);
      final taskMinute = int.parse(timeComponents[1]);

      // Compare with current time
      return taskHour > now.hour ||
          (taskHour == now.hour && taskMinute > now.minute);
    }).toList();

    if (upcomingTasks.isEmpty) return Text('No more tasks for today');

    // Sort by time
    upcomingTasks.sort((a, b) {
      final aTime = a['time'].toString().split(':');
      final bTime = b['time'].toString().split(':');
      final aHour = int.parse(aTime[0]);
      final bHour = int.parse(bTime[0]);
      final aMinute = int.parse(aTime[1]);
      final bMinute = int.parse(bTime[1]);

      if (aHour != bHour) return aHour.compareTo(bHour);
      return aMinute.compareTo(bMinute);
    });

    final nextTask = upcomingTasks.first;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Next: ',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF87CEEB),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: '${nextTask['text']} at ${nextTask['time']}',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekDays = _getWeekDays();

    // Define colors based on theme
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final headerGradient = widget.isDarkMode
        ? [
            Color(0xFF1A4B5F), // Darker blue
            Color(0xFF2A6277), // Darker light blue
          ]
        : [
            Color(0xFF87CEEB),
            Color(0xFFB6E5FF),
          ];
    final textColor = widget.isDarkMode ? Colors.white : Color(0xFF2C3E50);
    final cardColor = widget.isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFE8F4FD);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 40,
              width: 40,
            ),
            SizedBox(width: 10),
            Text(
              'Harmonia',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () => widget.toggleTheme?.call(),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/settings/password'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section with Calendar
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: headerGradient,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(100),
                    bottomRight: Radius.circular(100),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          '${now.day} ${_getMonthName(now.month)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),

                      // Calendar Week View
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: weekDays.map((date) {
                          bool isToday =
                              date.day == now.day && date.month == now.month;
                          bool isPast = date
                              .isBefore(DateTime(now.year, now.month, now.day));
                          return _buildCalendarDay(
                            _getDayLabel(date),
                            date.day.toString(),
                            isPast,
                            isToday: isToday,
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 40),

                      // Reminder Section
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.pink,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'REMINDERS :',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 15),
                            _buildNextReminder(),
                            SizedBox(height: 20),
                            Center(
                              child: GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/reminders'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    "Let's see all reminders",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2C3E50),
                                      fontWeight: FontWeight.w500,
                                    ),
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
              ),

              // Main Content Section
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // How do you feel today
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'How do you feel today?😊',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Action Buttons Row
                    Row(
                      children: [
                        // Record Feeling Button
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/journal'),
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? Color(0xFF2A6277)
                                    : Color(0xFFB6E5FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Record',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  Text(
                                    'your',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  Text(
                                    'feeling',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF4A9B8E),
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 15),

                        // Emergency SOS Button
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _handleEmergencyCall,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Color(0xFFFFE4E4),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'EMERGENCY SOS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),

                    // Family Section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wanna see your family?🏠👨‍👩‍👧‍👦👨‍👩‍👧‍👦😊',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A9B8E),
                            ),
                          ),
                          SizedBox(height: 20),

                          // Family Members
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _familyMembers.take(3).map((member) {
                              return _buildFamilyMember(
                                member['name'] as String,
                                member['imagePath'] as String,
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),

                          Center(
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/profiles'),
                              child: Text(
                                'See More',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A9B8E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),

                    // Let's remember together Section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Let's remember together 😃📚",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Image.asset(
                              'assets/1.webp',
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/games'),
                              child: Text(
                                "Let's go 👉",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A9B8E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),

                    // Need Any Help Section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Any Help ?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Image.asset(
                              'assets/0.webp',
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/chat'),
                              child: Text(
                                'Ask Me',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A9B8E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyMember(String name, String? imagePath) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
          child: ClipOval(
            child: imagePath != null && File(imagePath).existsSync()
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey.shade400,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.isDarkMode ? Colors.white : Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }
}
