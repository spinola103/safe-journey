import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '/core/models/journey_plan.dart';
import '/core/models/stop_locations.dart';

class GeofenceService {
  static const double _checkpointRadiusMeters = 150.0;
  static const int _pollIntervalNearStop = 15;
  static const int _pollIntervalInTransit = 120;

  StreamSubscription<Position>? _positionSub;
  Timer? _missedCheckpointTimer;
  Timer? _pollTimer;

  final void Function(int stopIndex, String stopName) onCheckpointVerified;

  final void Function(int stopIndex, String stopName) onCheckpointMissed;

  final void Function(double lat, double lng) onLocationUpdate;

  GeofenceService({
    required this.onCheckpointVerified,
    required this.onCheckpointMissed,
    required this.onLocationUpdate,
  });

  int _currentStopIndex = 0;
  List<StopLocation> _stops = [];
  bool _isNearStop = false;

  Future<void> startTracking(
    JourneyPlan plan,
    List<StopLocation> stopLocations,
  ) async {
    _stops = stopLocations;
    _currentStopIndex = 0;

    if (plan.legs.isEmpty) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever');
      return;
    }

    _startAdaptivePolling();

    _startMissedCheckpointTimer(plan.legs.first.durationMinutes);
  }

  static Future<List<StopLocation>> resolveStopLocations(
    JourneyPlan plan,
    BuildContext context,
  ) async {
    try {
      final jsonStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/data/chennai_stops.json');
      final data = jsonDecode(jsonStr);
      final stops = data['stops'] as List;

      final locations = <StopLocation>[];

      for (final leg in plan.legs) {
        // Try to find matching stop by name similarity
        final match = stops.firstWhere(
          (s) => (s['name'] as String).toLowerCase().contains(
            leg.startStop.toLowerCase().split(' ').first,
          ),
          orElse: () => null,
        );

        if (match != null) {
          locations.add(
            StopLocation(
              stopName: leg.startStop,
              lat: match['lat'],
              lng: match['lng'],
            ),
          );
        }
      }

      // Add final destination
      final lastLeg = plan.legs.last;
      final destMatch = stops.firstWhere(
        (s) => (s['name'] as String).toLowerCase().contains(
          lastLeg.endStop.toLowerCase().split(' ').first,
        ),
        orElse: () => null,
      );
      if (destMatch != null) {
        locations.add(
          StopLocation(
            stopName: lastLeg.endStop,
            lat: destMatch['lat'],
            lng: destMatch['lng'],
          ),
        );
      }

      return locations.isEmpty ? _fallbackStops(plan) : locations;
    } catch (_) {
      return _fallbackStops(plan);
    }
  }

  static List<StopLocation> _fallbackStops(JourneyPlan plan) {
    // Chennai city centre as fallback — geofence won't trigger but app won't crash
    return plan.legs
        .map(
          (leg) =>
              StopLocation(stopName: leg.startStop, lat: 13.0827, lng: 80.2707),
        )
        .toList();
  }

  void _startAdaptivePolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(
      Duration(
        seconds: _isNearStop ? _pollIntervalNearStop : _pollIntervalInTransit,
      ),
      (_) => _checkPosition(),
    );
  }

  Future<void> _checkPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      onLocationUpdate(pos.latitude, pos.longitude);

      if (_currentStopIndex >= _stops.length) {
        return;
      }

      final target = _stops[_currentStopIndex];

      final distance = _haversineDistance(
        pos.latitude,
        pos.longitude,
        target.lat,
        target.lng,
      );

      final wasNearStop = _isNearStop;
      _isNearStop = distance < 500;

      if (wasNearStop != _isNearStop) {
        _startAdaptivePolling();
      }

      if (distance <= _checkpointRadiusMeters) {
        onCheckpointVerified(_currentStopIndex, target.stopName);

        _currentStopIndex++;

        _missedCheckpointTimer?.cancel();

        if (_currentStopIndex < _stops.length) {
          _startMissedCheckpointTimer(8);
        }
      }
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  void _startMissedCheckpointTimer(int expectedMinutes) {
    _missedCheckpointTimer?.cancel();

    final timeoutMinutes = expectedMinutes + 8;

    _missedCheckpointTimer = Timer(Duration(minutes: timeoutMinutes), () {
      if (_currentStopIndex < _stops.length) {
        onCheckpointMissed(
          _currentStopIndex,
          _stops[_currentStopIndex].stopName,
        );
      }
    });
  }

  static double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;

    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  static double _toRad(double deg) {
    return deg * (pi / 180);
  }

  void dispose() {
    _positionSub?.cancel();
    _missedCheckpointTimer?.cancel();
    _pollTimer?.cancel();
  }
}

const List<StopLocation> demoTambToTNagarStops = [
  StopLocation(stopName: 'Tambaram Bus Stop', lat: 12.9249, lng: 80.1000),
  StopLocation(stopName: 'Guindy', lat: 13.0067, lng: 80.2206),
  StopLocation(stopName: 'Guindy Metro Station', lat: 13.0071, lng: 80.2199),
  StopLocation(stopName: 'T.Nagar', lat: 13.0418, lng: 80.2341),
];
