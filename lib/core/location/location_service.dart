import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/models.dart';

/// Abstraction over real device GPS (CoreLocation on iOS) and test streams.
abstract class LocationService {
  Future<LocationPermissionState> checkAndRequestPermission();
  Future<LocationFix?> getCurrentFix();
  Stream<LocationFix> watchFixes();
}

/// Real device GPS service backed by `geolocator` (CoreLocation on iOS/macOS).
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationPermissionState> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionState.denied;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return LocationPermissionState.denied;
    }
    return LocationPermissionState.granted;
  }

  @override
  Future<LocationFix?> getCurrentFix() async {
    final permissionState = await checkAndRequestPermission();
    if (permissionState != LocationPermissionState.granted) return null;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    );
    return _positionToFix(pos);
  }

  @override
  Stream<LocationFix> watchFixes() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).map(_positionToFix);
  }

  LocationFix _positionToFix(Position pos) {
    return LocationFix(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyMeters: pos.accuracy,
      recordedAt: pos.timestamp,
    );
  }
}
