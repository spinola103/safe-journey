import 'package:google_maps_flutter/google_maps_flutter.dart';

class Leg {
  final String mode; // 'metro', 'bus', 'auto', 'rail', 'walk'
  final String startStop;
  final String endStop;
  final int durationMinutes;
  final double fare;
  final double safetyScore;
  final String? gtfsRouteId;
  final String? routeLabel;

  /// Real polyline points from Google Directions API (empty for demo legs)
  final List<LatLng> polylinePoints;

  const Leg({
    required this.mode,
    required this.startStop,
    required this.endStop,
    required this.durationMinutes,
    required this.fare,
    required this.safetyScore,
    this.gtfsRouteId,
    this.routeLabel,
    this.polylinePoints = const [],
  });

  Leg copyWith({
    String? mode,
    String? startStop,
    String? endStop,
    int? durationMinutes,
    double? fare,
    double? safetyScore,
    String? gtfsRouteId,
    String? routeLabel,
    List<LatLng>? polylinePoints,
  }) {
    return Leg(
      mode: mode ?? this.mode,
      startStop: startStop ?? this.startStop,
      endStop: endStop ?? this.endStop,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      fare: fare ?? this.fare,
      safetyScore: safetyScore ?? this.safetyScore,
      gtfsRouteId: gtfsRouteId ?? this.gtfsRouteId,
      routeLabel: routeLabel ?? this.routeLabel,
      polylinePoints: polylinePoints ?? this.polylinePoints,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'start': startStop,
    'end': endStop,
    'duration': durationMinutes,
    'fare': fare,
    'safety_score': safetyScore,
    'route_id': gtfsRouteId,
    'route_label': routeLabel,
    // polylinePoints not serialised (transient, re-fetched on demand)
  };

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
    mode: json['mode'] ?? 'bus',
    startStop: json['start'] ?? '',
    endStop: json['end'] ?? '',
    durationMinutes: json['duration'] ?? 0,
    fare: (json['fare'] ?? 0).toDouble(),
    safetyScore: (json['safety_score'] ?? 70).toDouble(),
    gtfsRouteId: json['route_id'],
    routeLabel: json['route_label'],
  );

  // ── Display helpers ──────────────────────────────────────────────────────
  String get modeEmoji {
    switch (mode) {
      case 'metro': return '🚇';
      case 'bus':   return '🚌';
      case 'auto':  return '🛺';
      case 'rail':  return '🚆';
      case 'walk':  return '🚶';
      default:      return '🚌';
    }
  }

  String get modeLabel {
    switch (mode) {
      case 'metro': return 'Metro';
      case 'bus':   return 'MTC Bus';
      case 'auto':  return 'Auto';
      case 'rail':  return 'Suburban Rail';
      case 'walk':  return 'Walk';
      default:      return mode;
    }
  }

  double get co2SavedKg {
    final distanceKm = durationMinutes * 0.5;
    final cabCo2  = distanceKm * 0.21;
    final modeCo2 = switch (mode) {
      'metro' => distanceKm * 0.03,
      'bus'   => distanceKm * 0.07,
      'rail'  => distanceKm * 0.03,
      'walk'  => 0.0,
      'auto'  => distanceKm * 0.14,
      _       => distanceKm * 0.10,
    };
    return (cabCo2 - modeCo2).clamp(0.0, double.infinity);
  }
}
