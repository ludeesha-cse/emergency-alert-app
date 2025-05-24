import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import '../../models/sensor_data.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final loc.Location _location = loc.Location();
  StreamSubscription<Position>? _positionSubscription;

  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();
  Stream<LocationData> get locationStream => _locationController.stream;

  LocationData? _lastLocation;
  bool _isTracking = false;

  bool get isTracking => _isTracking;
  LocationData? get lastLocation => _lastLocation;

  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> enableLocationService() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    loc.PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        timestamp: DateTime.now(),
      );

      _lastLocation = locationData;
      return locationData;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permissions not granted');
    }

    _isTracking = true;
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      timeLimit: const Duration(seconds: 30),
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final locationData = LocationData(
              latitude: position.latitude,
              longitude: position.longitude,
              altitude: position.altitude,
              accuracy: position.accuracy,
              speed: position.speed,
              timestamp: DateTime.now(),
            );

            _lastLocation = locationData;
            _locationController.add(locationData);
          },
          onError: (error) {
            print('Location tracking error: $error');
          },
        );
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}'
            .replaceAll(
              RegExp(r'^,\s*|,\s*$'),
              '',
            ) // Remove leading/trailing commas
            .replaceAll(RegExp(r',\s*,'), ','); // Remove double commas
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  Future<LocationData?> getLocationWithAddress() async {
    final location = await getCurrentLocation();
    if (location != null) {
      final address = await getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      return LocationData(
        latitude: location.latitude,
        longitude: location.longitude,
        altitude: location.altitude,
        accuracy: location.accuracy,
        speed: location.speed,
        timestamp: location.timestamp,
        address: address,
      );
    }
    return null;
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
