import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PasswordPage extends StatefulWidget {
  final bool isDarkMode;

  const PasswordPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final List<String> _pin = ['', '', '', ''];
  final List<String> _confirmPin = ['', '', '', ''];
  int _currentIndex = 0;
  String _errorMessage = '';
  bool _isNewPin = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _checkIfPinExists();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/pin.csv');
  }

  Future<void> _checkIfPinExists() async {
    try {
      final file = await _localFile;
      final exists = await file.exists();
      setState(() {
        _isNewPin = !exists;
      });
    } catch (e) {
      setState(() {
        _isNewPin = true;
      });
    }
  }

  Future<void> _savePin(String pin) async {
    final file = await _localFile;
    await file.writeAsString(pin);
  }

  Future<bool> _verifyPin(String pin) async {
    try {
      final file = await _localFile;
      final savedPin = await file.readAsString();
      return pin == savedPin;
    } catch (e) {
      return false;
    }
  }

  void _handleSubmit() async {
    final pin = _pin.join();
    if (pin.length != 4) {
      setState(() {
        _errorMessage = 'PIN must be 4 digits';
      });
      return;
    }

    if (_isNewPin) {
      if (!_isConfirming) {
        setState(() {
          _isConfirming = true;
          _currentIndex = 0;
          _errorMessage = '';
        });
        return;
      } else {
        final confirmPin = _confirmPin.join();
        if (pin != confirmPin) {
          setState(() {
            _errorMessage = 'PINs do not match. Try again.';
            _isConfirming = false;
            _pin.fillRange(0, _pin.length, '');
            _confirmPin.fillRange(0, _confirmPin.length, '');
            _currentIndex = 0;
          });
          return;
        }
        await _savePin(pin);
        Navigator.pushReplacementNamed(context, '/settings');
      }
    } else {
      final isValid = await _verifyPin(pin);
      if (isValid) {
        Navigator.pushReplacementNamed(context, '/settings');
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN';
          _pin.fillRange(0, _pin.length, ''); // Clear the PIN
          _currentIndex = 0; // Reset the index
        });
      }
    }
  }

  void _handleNumberInput(String number) {
    if (_currentIndex < 4) {
      setState(() {
        if (_isNewPin && _isConfirming) {
          _confirmPin[_currentIndex] = number;
        } else {
          _pin[_currentIndex] = number;
        }
        _currentIndex++;
        _errorMessage = '';
      });

      if (_currentIndex == 4) {
        _handleSubmit();
      }
    }
  }

  void _handleBackspace() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        if (_isNewPin && _isConfirming) {
          _confirmPin[_currentIndex] = '';
        } else {
          _pin[_currentIndex] = '';
        }
        _errorMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Color(0xFF2C3E50);
    final primaryColor =
        widget.isDarkMode ? Color(0xFF2A6277) : Color(0xFF87CEEB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor:
            widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB),
        elevation: 0,
        title: Text(
          _isNewPin ? 'Create PIN' : 'Enter PIN',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isDarkMode
                ? [Color(0xFF1A4B5F), Color(0xFF2A6277)]
                : [Color(0xFF87CEEB), Color(0xFFB6E5FF)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.security,
                          size: 48,
                          color: textColor,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Protected Space',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Harmonia is a privacy-first mobile application designed specifically for Alzheimer\'s patients and their caregivers.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'You can\'t open this space without verification for your security and information protection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isNewPin
                        ? (_isConfirming
                            ? 'Confirm your PIN code'
                            : 'Create your PIN code')
                        : 'Enter your PIN code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 30),
                  // PIN Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final currentPin =
                          _isNewPin && _isConfirming ? _confirmPin : _pin;
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 10),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentPin[index].isNotEmpty
                              ? primaryColor
                              : Colors.white.withOpacity(0.5),
                          border: Border.all(
                            color: _currentIndex == index
                                ? primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ),
            // Number Pad
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var j = 1; j <= 3; j++)
                            _buildNumberButton(
                                (i * 3 + j).toString(), primaryColor),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNumberButton('', primaryColor),
                        _buildNumberButton('0', primaryColor),
                        IconButton(
                          icon: Icon(Icons.backspace, color: textColor),
                          onPressed: _handleBackspace,
                          iconSize: 24,
                          padding: EdgeInsets.all(16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number, Color primaryColor) {
    if (number.isEmpty) return SizedBox(width: 60, height: 60);

    return GestureDetector(
      onTap: () => _handleNumberInput(number),
      child: Container(
        width: 60,
        height: 60,
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Color(0xFF2C3E50),
            ),
          ),
        ),
      ),
    );
  }
}
