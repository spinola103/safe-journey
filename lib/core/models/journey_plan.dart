import 'leg.dart';

enum JourneyStatus { planned, active, completed, sos }

class Checkpoint {
  final String stopName;
  final DateTime time;
  final bool verified;
  final String mode;

  const Checkpoint({
    required this.stopName,
    required this.time,
    required this.verified,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
    'stop': stopName,
    'time': time.toIso8601String(),
    'verified': verified,
    'mode': mode,
  };

  factory Checkpoint.fromJson(Map<String, dynamic> j) => Checkpoint(
    stopName: j['stop'] ?? '',
    time: DateTime.tryParse(j['time'] ?? '') ?? DateTime.now(),
    verified: j['verified'] ?? false,
    mode: j['mode'] ?? 'bus',
  );
}

class JourneyPlan {
  final String id;
  final List<Leg> legs;
  final String userId;
  final String guardianUid;
  final JourneyStatus status;
  final List<Checkpoint> checkpoints;
  final DateTime? startedAt;
  final String origin;
  final String destination;

  const JourneyPlan({
    required this.id,
    required this.legs,
    required this.userId,
    required this.guardianUid,
    required this.origin,
    required this.destination,
    this.status = JourneyStatus.planned,
    this.checkpoints = const [],
    this.startedAt,
  });

  // ── Computed totals ──────────────────────────────────────────────────
  int get totalMinutes => legs.fold(0, (s, l) => s + l.durationMinutes);
  double get totalFare  => legs.fold(0.0, (s, l) => s + l.fare);
  double get avgSafetyScore =>
      legs.isEmpty ? 0 : legs.fold(0.0, (s, l) => s + l.safetyScore) / legs.length;
  double get totalCo2Saved => legs.fold(0.0, (s, l) => s + l.co2SavedKg);

  String get totalFareLabel  => '₹${totalFare.toStringAsFixed(0)}';
  String get totalTimeLabel  => '$totalMinutes min';
  String get safetyLabel     => avgSafetyScore.toStringAsFixed(0);

  // ── Journey Editor core — O(1) leg swap ─────────────────────────────
  JourneyPlan swapLeg(int index, Leg newLeg) {
    final newLegs = List<Leg>.from(legs);
    newLegs[index] = newLeg;
    return copyWith(legs: newLegs);
  }

  // ── Firebase serialisation ──────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'guardian_uid': guardianUid,
    'origin': origin,
    'destination': destination,
    'status': status.name,
    'legs': legs.map((l) => l.toJson()).toList(),
    'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
    'started_at': startedAt?.toIso8601String(),
  };

  factory JourneyPlan.fromJson(Map<String, dynamic> j) => JourneyPlan(
    id: j['id'] ?? '',
    userId: j['user_id'] ?? '',
    guardianUid: j['guardian_uid'] ?? '',
    origin: j['origin'] ?? '',
    destination: j['destination'] ?? '',
    status: JourneyStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => JourneyStatus.planned,
    ),
    legs: (j['legs'] as List<dynamic>? ?? [])
        .map((l) => Leg.fromJson(l as Map<String, dynamic>))
        .toList(),
    checkpoints: (j['checkpoints'] as List<dynamic>? ?? [])
        .map((c) => Checkpoint.fromJson(c as Map<String, dynamic>))
        .toList(),
    startedAt: j['started_at'] != null
        ? DateTime.tryParse(j['started_at'])
        : null,
  );

  JourneyPlan copyWith({
    String? id,
    List<Leg>? legs,
    String? userId,
    String? guardianUid,
    String? origin,
    String? destination,
    JourneyStatus? status,
    List<Checkpoint>? checkpoints,
    DateTime? startedAt,
  }) {
    return JourneyPlan(
      id: id ?? this.id,
      legs: legs ?? this.legs,
      userId: userId ?? this.userId,
      guardianUid: guardianUid ?? this.guardianUid,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      checkpoints: checkpoints ?? this.checkpoints,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
