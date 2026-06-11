/// Safety Score Engine
/// Pre-seeded from NCRB district data + CMDA lighting + GTFS frequency.
/// No cold start — works on day one before any user contributes data.
///
/// Score is a DECISION-SUPPORT METRIC, not a safety guarantee.
/// Helps users make informed choices — does not replace their judgement.

class SafetyScoreService {
  // ── Pre-seeded zone data (NCRB + CMDA approximations for Chennai) ──
  // Keys: rough area names. Real implementation uses GPS zones.
  static const Map<String, _ZoneData> _zones = {
  // South Chennai
  'tambaram':       _ZoneData(crime: 0.62, lighting: 0.55, crowding: 0.70),
  'chromepet':      _ZoneData(crime: 0.60, lighting: 0.52, crowding: 0.65),
  'pallavaram':     _ZoneData(crime: 0.61, lighting: 0.54, crowding: 0.67),
  'velachery':      _ZoneData(crime: 0.68, lighting: 0.70, crowding: 0.75),
  'medavakkam':     _ZoneData(crime: 0.63, lighting: 0.56, crowding: 0.60),

  // Central Chennai
  'guindy':         _ZoneData(crime: 0.70, lighting: 0.75, crowding: 0.80),
  'saidapet':       _ZoneData(crime: 0.66, lighting: 0.68, crowding: 0.72),
  't.nagar':        _ZoneData(crime: 0.68, lighting: 0.80, crowding: 0.90),
  'kodambakkam':    _ZoneData(crime: 0.65, lighting: 0.72, crowding: 0.78),
  'koyambedu':      _ZoneData(crime: 0.67, lighting: 0.74, crowding: 0.85),
  'ashok_nagar':    _ZoneData(crime: 0.70, lighting: 0.75, crowding: 0.78),

  // North Chennai
  'egmore':         _ZoneData(crime: 0.65, lighting: 0.78, crowding: 0.85),
  'chennai_beach':  _ZoneData(crime: 0.72, lighting: 0.70, crowding: 0.75),
  'park_town':      _ZoneData(crime: 0.64, lighting: 0.76, crowding: 0.80),
  'perambur':       _ZoneData(crime: 0.60, lighting: 0.62, crowding: 0.70),
  'tondiarpet':     _ZoneData(crime: 0.58, lighting: 0.55, crowding: 0.65),

  // West Chennai
  'anna_nagar':     _ZoneData(crime: 0.74, lighting: 0.80, crowding: 0.82),
  'padi':           _ZoneData(crime: 0.66, lighting: 0.65, crowding: 0.68),
  'ambattur':       _ZoneData(crime: 0.63, lighting: 0.60, crowding: 0.70),
  'avadi':          _ZoneData(crime: 0.62, lighting: 0.58, crowding: 0.65),

  // East/OMR
  'adyar':          _ZoneData(crime: 0.75, lighting: 0.72, crowding: 0.65),
  'thiruvanmiyur':  _ZoneData(crime: 0.72, lighting: 0.70, crowding: 0.68),
  'sholinganallur': _ZoneData(crime: 0.70, lighting: 0.68, crowding: 0.65),
  'perungudi':      _ZoneData(crime: 0.68, lighting: 0.66, crowding: 0.62),

  'default':        _ZoneData(crime: 0.65, lighting: 0.65, crowding: 0.70),
};
  // ── Time-of-day weight adjustment ──────────────────────────────────
  static _Weights _getWeights(DateTime time) {
    final hour = time.hour;
    if (hour >= 22 || hour < 6) {
      // Night: crime + lighting dominate
      return const _Weights(crime: 0.45, lighting: 0.40, crowding: 0.00, community: 0.15);
    } else if (hour >= 19) {
      // Evening: lighting matters more
      return const _Weights(crime: 0.38, lighting: 0.30, crowding: 0.12, community: 0.20);
    } else {
      // Day: balanced
      return const _Weights(crime: 0.40, lighting: 0.20, crowding: 0.20, community: 0.20);
    }
  }

  /// Compute safety score for a zone at a given time.
  /// Returns 0–100. Higher = safer.
  static double computeScore({
    required String zone,
    DateTime? time,
    double communityRating = 0.70, // default neutral until user reports come in
  }) {
    final t = time ?? DateTime.now();
    final z = _zones[zone.toLowerCase()] ?? _zones['default']!;
    final w = _getWeights(t);

    final rawScore =
        (z.crime    * w.crime)    +
        (z.lighting * w.lighting) +
        (z.crowding * w.crowding) +
        (communityRating * w.community);

    return (rawScore * 100).clamp(0, 100);
  }

  /// Score label for UI display
  static String scoreLabel(double score) {
    if (score >= 75) return 'Safe';
    if (score >= 55) return 'Moderate';
    return 'Caution';
  }

  /// Women's Mode minimum threshold
  static const double womensModeThreshold = 70.0;

  static bool meetsWomensMode(double score) => score >= womensModeThreshold;
}

class _ZoneData {
  final double crime;    // inverse — higher = less crime in zone
  final double lighting;
  final double crowding;
  const _ZoneData({required this.crime, required this.lighting, required this.crowding});
}

class _Weights {
  final double crime;
  final double lighting;
  final double crowding;
  final double community;
  const _Weights({
    required this.crime,
    required this.lighting,
    required this.crowding,
    required this.community,
  });
}
