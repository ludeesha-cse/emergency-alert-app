import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class LocationService {
  static const String _latKey = 'last_latitude';
  static const String _longKey = 'last_longitude';
  static const Duration _updateInterval = Duration(minutes: 5);

  final SharedPreferences _prefs;
  Timer? _locationTimer;
  bool _isInitialized = false;

  LocationService._(this._prefs);

  static Future<LocationService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return LocationService._(prefs);
  }

  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  Future<bool> checkLocationPermission() async {
    return await Permission.locationAlways.isGranted;
  }

  Future<Position?> getLastKnownLocation() async {
    try {
      if (!await checkLocationPermission()) {
        return null;
      }

      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('Error getting last known location: $e');
      return null;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      if (!await checkLocationPermission()) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  Future<void> _saveLocation(Position position) async {
    await _prefs.setDouble(_latKey, position.latitude);
    await _prefs.setDouble(_longKey, position.longitude);
  }

  Position? getStoredLocation() {
    final lat = _prefs.getDouble(_latKey);
    final long = _prefs.getDouble(_longKey);

    if (lat == null || long == null) return null;

    return Position(
      latitude: lat,
      longitude: long,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Future<void> startLocationUpdates() async {
    if (_isInitialized) return;

    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      final granted = await requestLocationPermission();
      if (!granted) {
        print('Location permission denied');
        return;
      }
    }

    // Initialize location settings
    await Geolocator.requestPermission();
    await Geolocator.openLocationSettings();

    // Start periodic updates
    _locationTimer = Timer.periodic(_updateInterval, (timer) async {
      final position = await getCurrentLocation();
      if (position != null) {
        await _saveLocation(position);
      }
    });

    _isInitialized = true;
  }

  Future<void> stopLocationUpdates() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isInitialized = false;
  }

  // Method to initialize background location tracking
  Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onBackgroundStart,
        onBackground: onBackgroundStart,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
      ),
    );
  }

  // Background service callback
  @pragma('vm:entry-point')
  static Future<bool> onBackgroundStart(ServiceInstance service) async {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Initialize location updates in background
    final prefs = await SharedPreferences.getInstance();
    final locationService = LocationService._(prefs);

    // Periodically update location in background
    Timer.periodic(_updateInterval, (timer) async {
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        await locationService._saveLocation(position);
      }
    });

    return true;
  }

  // Cleanup method
  void dispose() {
    stopLocationUpdates();
  }
}
