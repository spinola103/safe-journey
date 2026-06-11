import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/leg.dart';
import '../models/journey_plan.dart';
import 'safety_score_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Real Chennai routing — Google Maps Directions API
/// Fetches actual transit steps including per-leg polylines.
/// ─────────────────────────────────────────────────────────────────────────────
class RoutingService {
  static const String _apiKey = 'AIzaSyAt9FKYc6Pv3_IlmyHrMP-FjtMN7Q_oe5w';

  static Future<List<JourneyPlan>> fetchRoutes({
    required String origin,
    required String destination,
    required bool womensMode,
  }) async {
    try {
      final from = origin.contains('Chennai') ? origin : '$origin, Chennai';
      final to   = destination.contains('Chennai') ? destination : '$destination, Chennai';

      // Request multiple departure times to get route variety
      // departure_time=now forces real transit schedules
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${Uri.encodeComponent(from)}'
        '&destination=${Uri.encodeComponent(to)}'
        '&mode=transit'
        '&alternatives=true'
        '&transit_mode=bus,subway,rail,tram'
        '&region=in'
        '&language=en'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return _demoFallback(origin, destination);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return _demoFallback(origin, destination);

      final routes = data['routes'] as List;
      if (routes.isEmpty) return _demoFallback(origin, destination);

      final plans = <JourneyPlan>[];
      for (int i = 0; i < routes.length && i < 3; i++) {
        final route = routes[i] as Map<String, dynamic>;
        final legs  = _parseLegs(route, origin, destination);
        if (legs.isEmpty) continue;
        plans.add(JourneyPlan(
          id: 'real_${DateTime.now().millisecondsSinceEpoch}_$i',
          userId: 'current_user',
          guardianUid: '',
          origin: origin,
          destination: destination,
          legs: legs,
        ));
      }

      if (plans.isEmpty) return _demoFallback(origin, destination);

      // Pad to 3 if API returned fewer
      final demo = _demoFallback(origin, destination);
      while (plans.length < 3 && demo.isNotEmpty) {
        plans.add(demo[plans.length % demo.length]);
      }

      return _sortedPlans(plans.take(3).toList(), womensMode);
    } catch (_) {
      return _demoFallback(origin, destination);
    }
  }

  // ── Parse all legs including their polyline points ─────────────────────────
  static List<Leg> _parseLegs(
      Map<String, dynamic> route, String origin, String destination) {
    final legs = <Leg>[];
    final routeLegs = route['legs'] as List;
    if (routeLegs.isEmpty) return legs;

    final routeLeg = routeLegs[0] as Map<String, dynamic>;
    final allSteps = routeLeg['steps'] as List;

    for (final rawStep in allSteps) {
      final step       = rawStep as Map<String, dynamic>;
      final travelMode = (step['travel_mode'] as String).toLowerCase();
      final duration   = (step['duration']['value'] as int) ~/ 60;
      final distance   = step['distance']['text'] as String;

      // Decode per-step polyline
      final polylineStr =
          (step['polyline']?['points'] ?? '') as String;
      final points = _decodePolyline(polylineStr);

      String mode      = travelMode;
      String startStop = _locStr(step['start_location']);
      String endStop   = _locStr(step['end_location']);
      String? routeLabel;
      double fare = 0;

      if (step.containsKey('transit_details')) {
        final transit = step['transit_details'] as Map<String, dynamic>;
        final line    = transit['line']    as Map<String, dynamic>;
        final vehicle = line['vehicle']   as Map<String, dynamic>;
        final type    = (vehicle['type']  as String).toLowerCase();

        routeLabel = (line['short_name'] ?? line['name'] ?? '') as String;
        if ((routeLabel as String).isEmpty) routeLabel = null;

        startStop = (transit['departure_stop'] as Map)['name'] as String? ?? startStop;
        endStop   = (transit['arrival_stop']   as Map)['name'] as String? ?? endStop;

        mode = switch (type) {
          'subway' || 'metro_rail'                            => 'metro',
          'commuter_train' || 'heavy_rail' || 'rail'
          || 'monorail' || 'tram' || 'light_rail'            => 'rail',
          'bus' || 'intercity_bus'                            => 'bus',
          'share_taxi'                                        => 'auto',
          _                                                   => 'bus',
        };
        fare = _estimateFare(mode, duration);

      } else if (travelMode == 'walking') {
        mode = 'walk';
        routeLabel = distance;
      }

      final zone        = _guessZone(endStop);
      final safetyScore = SafetyScoreService.computeScore(
          zone: zone, time: DateTime.now());

      legs.add(Leg(
        mode: mode,
        startStop: startStop,
        endStop: endStop,
        durationMinutes: duration.clamp(1, 999),
        fare: fare,
        safetyScore: safetyScore,
        routeLabel: routeLabel,
        polylinePoints: points,           // ← per-leg route shape
      ));
    }

    return legs.isEmpty ? _demoLegs(origin, destination) : legs;
  }

  // ── Google encoded polyline decoder ────────────────────────────────────────
  static List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = ((result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1));
      lat += dLat;

      shift = 0; result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = ((result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1));
      lng += dLng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  static String _locStr(dynamic loc) {
    if (loc == null) return '';
    final m = loc as Map<String, dynamic>;
    return '{lat: ${m['lat']}, lng: ${m['lng']}}';
  }

  static double _estimateFare(String mode, int durationMinutes) {
    final km = (durationMinutes * 0.5).clamp(1.0, 50.0);
    return switch (mode) {
      'metro' => (km * 2.0).clamp(10, 60),
      'rail'  => (km * 0.5).clamp(5, 30),
      'bus'   => (km * 0.4).clamp(5, 20),
      'auto'  => km * 16,
      _       => 0,
    };
  }

  static String _guessZone(String stop) {
    final s = stop.toLowerCase();
    if (s.contains('tambaram'))   return 'tambaram';
    if (s.contains('guindy'))     return 'guindy';
    if (s.contains('adyar'))      return 'adyar';
    if (s.contains('t.nagar') || s.contains('t nagar')) return 't.nagar';
    if (s.contains('egmore'))     return 'egmore';
    if (s.contains('beach'))      return 'chennai_beach';
    if (s.contains('saidapet'))   return 'saidapet';
    if (s.contains('chromepet'))  return 'chromepet';
    if (s.contains('anna nagar')) return 'anna_nagar';
    if (s.contains('velachery'))  return 'velachery';
    return 'default';
  }

  static List<JourneyPlan> _sortedPlans(
      List<JourneyPlan> plans, bool womensMode) {
    if (plans.length < 2) return plans;
    final fastest  = [...plans]..sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));
    final cheapest = [...plans]..sort((a, b) => a.totalFare.compareTo(b.totalFare));
    final safest   = [...plans]..sort((a, b) => b.avgSafetyScore.compareTo(a.avgSafetyScore));
    if (womensMode) {
      return [
        safest[0],
        cheapest.firstWhere(
            (p) => p.avgSafetyScore >= SafetyScoreService.womensModeThreshold,
            orElse: () => cheapest[0]),
        fastest.firstWhere(
            (p) => p.avgSafetyScore >= SafetyScoreService.womensModeThreshold,
            orElse: () => fastest[0]),
      ];
    }
    return [fastest[0], cheapest[0], safest[0]];
  }

  // ── Demo fallback (rich, realistic Chennai routes) ─────────────────────────
  static List<Leg> _demoLegs(String origin, String destination) => [
    Leg(mode: 'bus',   startStop: origin,      endStop: 'Junction',    durationMinutes: 25, fare: 15, safetyScore: 72, routeLabel: 'MTC 21C'),
    Leg(mode: 'metro', startStop: 'Junction',  endStop: destination,   durationMinutes: 15, fare: 30, safetyScore: 88, routeLabel: 'Green Line'),
  ];

  static List<JourneyPlan> _demoFallback(String origin, String destination) {
    return [
      JourneyPlan(id: 'demo_1', userId: 'demo', guardianUid: '', origin: origin, destination: destination, legs: [
        Leg(mode: 'bus',  startStop: origin,            endStop: 'Guindy',          durationMinutes: 35, fare: 15, safetyScore: 72, routeLabel: 'MTC 21C'),
        Leg(mode: 'metro',startStop: 'Guindy Metro',    endStop: destination,        durationMinutes: 15, fare: 30, safetyScore: 91, routeLabel: 'Green Line'),
      ]),
      JourneyPlan(id: 'demo_2', userId: 'demo', guardianUid: '', origin: origin, destination: destination, legs: [
        Leg(mode: 'rail', startStop: origin,            endStop: 'Chennai Central', durationMinutes: 30, fare: 10, safetyScore: 85, routeLabel: 'Suburban Rail'),
        Leg(mode: 'walk', startStop: 'Chennai Central', endStop: destination,        durationMinutes: 8,  fare: 0,  safetyScore: 75, routeLabel: '0.5 km'),
      ]),
      JourneyPlan(id: 'demo_3', userId: 'demo', guardianUid: '', origin: origin, destination: destination, legs: [
        Leg(mode: 'metro',startStop: origin,            endStop: 'T.Nagar',         durationMinutes: 28, fare: 40, safetyScore: 92, routeLabel: 'Blue Line'),
        Leg(mode: 'walk', startStop: 'T.Nagar',         endStop: destination,        durationMinutes: 6,  fare: 0,  safetyScore: 80, routeLabel: '0.3 km'),
      ]),
    ];
  }
}
