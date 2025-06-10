import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';

class SecurityPage extends StatefulWidget {
  final bool isDarkMode;

  const SecurityPage({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  GoogleMapController? mapController;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  LatLng? _homeLocation;
  bool _isLoading = true;
  Timer? _locationTimer;
  final double _geofenceRadius = 100; // in meters
  bool _isMonitoringEnabled = false;
  DateTime? _lastAlertTime;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSavedLocation();
    _loadHomeLocation();
    _loadMonitoringSettings();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Location permissions are required')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          if (_selectedLocation == null) {
            _selectedLocation = _currentLocation;
          }
          _isLoading = false;
        });

        mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );

        // Start monitoring if enabled and home location is set
        if (_isMonitoringEnabled && _homeLocation != null) {
          _startLocationMonitoring();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveLocation(LatLng location) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/saved_location.txt');
      await file.writeAsString('${location.latitude},${location.longitude}');
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  Future<void> _loadSavedLocation() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/saved_location.txt');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final parts = contents.split(',');
        setState(() {
          _selectedLocation = LatLng(
            double.parse(parts[0]),
            double.parse(parts[1]),
          );
        });
      }
    } catch (e) {
      print('Error loading saved location: $e');
    }
  }

  Future<void> _loadHomeLocation() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/home_location.txt');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final parts = contents.split(',');
        setState(() {
          _homeLocation = LatLng(
            double.parse(parts[0]),
            double.parse(parts[1]),
          );
        });
      }
    } catch (e) {
      print('Error loading home location: $e');
    }
  }

  Future<void> _loadMonitoringSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/monitoring_enabled.txt');
      if (await file.exists()) {
        final contents = await file.readAsString();
        setState(() {
          _isMonitoringEnabled = contents == 'true';
        });
      }
    } catch (e) {
      print('Error loading monitoring settings: $e');
    }
  }

  Future<void> _saveMonitoringSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/monitoring_enabled.txt');
      await file.writeAsString(_isMonitoringEnabled.toString());
    } catch (e) {
      print('Error saving monitoring settings: $e');
    }
  }

  Future<void> _saveHomeLocation() async {
    if (_selectedLocation == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/home_location.txt');
      await file.writeAsString(
          '${_selectedLocation!.latitude},${_selectedLocation!.longitude}');
      setState(() {
        _homeLocation = _selectedLocation;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home location saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving home location: $e');
    }
  }

  void _toggleLocationMonitoring() {
    setState(() {
      _isMonitoringEnabled = !_isMonitoringEnabled;
    });
    _saveMonitoringSettings();

    if (_isMonitoringEnabled && _homeLocation != null) {
      _startLocationMonitoring();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location monitoring enabled. You will see alerts when away from home.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _stopLocationMonitoring();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location monitoring disabled.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _startLocationMonitoring() {
    _locationTimer?.cancel(); // Cancel existing timer
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDistanceFromHome();
    });
  }

  void _stopLocationMonitoring() {
    _locationTimer?.cancel();
  }

  Future<void> _checkDistanceFromHome() async {
    if (_homeLocation == null || !_isMonitoringEnabled) return;

    try {
      Position position = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);

      double distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _homeLocation!.latitude,
        _homeLocation!.longitude,
      );

      if (distance > _geofenceRadius) {
        // Prevent spam alerts - only show once every 30 minutes
        if (_lastAlertTime == null ||
            DateTime.now().difference(_lastAlertTime!).inMinutes > 30) {
          _lastAlertTime = DateTime.now();
          _showNavigationDialog();
        }
      }
    } catch (e) {
      print('Error checking distance from home: $e');
    }
  }

  Future<void> _showNavigationDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        titlePadding: EdgeInsets.only(top: 20, left: 20, right: 20),
        title: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            Text(
              'Away From Home',
              style: TextStyle(
                fontSize: 18,
                color: widget.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'You are more than 100 meters away from your home location. Would you like directions to get back home?',
          style: TextStyle(
            fontSize: 16,
            color: widget.isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToHome();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Get Directions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToHome() async {
    if (_homeLocation == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_homeLocation!.latitude},${_homeLocation!.longitude}&travelmode=driving',
    );

    try {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps application')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final surfaceColor = widget.isDarkMode ? Colors.grey[900] : Colors.grey[100];
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final primaryColor = widget.isDarkMode ? Color(0xFF1A4B5F) : Color(0xFF87CEEB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Security Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : Column(
              children: [
                // Monitoring Status Card
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isMonitoringEnabled ? Icons.security : Icons.security_outlined,
                            color: _isMonitoringEnabled ? Colors.green : Colors.grey,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location Monitoring',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  _isMonitoringEnabled
                                      ? 'Active - You\'ll see alerts when away from home'
                                      : 'Disabled - No location alerts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isMonitoringEnabled,
                            onChanged: _homeLocation != null ? (_) => _toggleLocationMonitoring() : null,
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      if (_homeLocation == null)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Please set a home location first to enable monitoring',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Map
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation ?? LatLng(0, 0),
                      zoom: 15,
                    ),
                    onMapCreated: (controller) => mapController = controller,
                    markers: {
                      if (_currentLocation != null)
                        Marker(
                          markerId: MarkerId('current'),
                          position: _currentLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueBlue),
                          infoWindow: InfoWindow(title: 'Current Location'),
                        ),
                      if (_selectedLocation != null)
                        Marker(
                          markerId: MarkerId('selected'),
                          position: _selectedLocation!,
                          infoWindow: InfoWindow(title: 'Selected Location'),
                        ),
                      if (_homeLocation != null)
                        Marker(
                          markerId: MarkerId('home'),
                          position: _homeLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen),
                          infoWindow: InfoWindow(title: 'Home Location'),
                        ),
                    },
                    circles: _homeLocation != null
                        ? {
                            Circle(
                              circleId: CircleId('geofence'),
                              center: _homeLocation!,
                              radius: _geofenceRadius,
                              fillColor: Colors.blue.withOpacity(0.1),
                              strokeColor: Colors.blue,
                              strokeWidth: 2,
                            ),
                          }
                        : {},
                    onTap: (LatLng location) {
                      setState(() => _selectedLocation = location);
                      _saveLocation(location);
                    },
                  ),
                ),
                
                // Control Buttons
                Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _getCurrentLocation,
                              icon: Icon(Icons.my_location),
                              label: Text('Current'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_selectedLocation != null &&
                                    mapController != null) {
                                  mapController!.animateCamera(
                                    CameraUpdate.newLatLng(_selectedLocation!),
                                  );
                                }
                              },
                              icon: Icon(Icons.location_on),
                              label: Text('Selected'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                                foregroundColor: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectedLocation != null ? _saveHomeLocation : null,
                          icon: Icon(Icons.home),
                          label: Text('Save as Home Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_homeLocation != null && _isMonitoringEnabled)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '✓ Monitoring active - 100m geofence around home',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}