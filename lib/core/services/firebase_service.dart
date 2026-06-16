import 'package:firebase_database/firebase_database.dart';
import '../models/journey_plan.dart';
class FirebaseService {
  static final _db = FirebaseDatabase.instance;

  // ── Journey operations ───────────────────────────────────────────────

  /// Write a journey plan to Firebase
  static Future<void> saveJourney(JourneyPlan plan) async {
    await _db.ref('journeys/${plan.id}').set(plan.toJson());
  }

  /// Stream journey updates (for guardian view)
  static Stream<JourneyPlan?> watchJourney(String journeyId) {
    return _db.ref('journeys/$journeyId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return JourneyPlan.fromJson(Map<String, dynamic>.from(data as Map));
    });
  }

  /// Update journey status
  static Future<void> updateStatus(String journeyId, JourneyStatus status) async {
    await _db.ref('journeys/$journeyId/status').set(status.name);
  }

  // ── Checkpoint operations ────────────────────────────────────────────

  /// Push a verified checkpoint
  static Future<void> addCheckpoint(String journeyId, Checkpoint checkpoint) async {
    final ref = _db.ref('journeys/$journeyId/checkpoints').push();
    await ref.set(checkpoint.toJson());
  }

  /// Update the "last seen" location for guardian view
  static Future<void> updateLastLocation(String journeyId, double lat, double lng, String currentStop) async {
    await _db.ref('journeys/$journeyId/last_location').set({
      'lat': lat,
      'lng': lng,
      'stop': currentStop,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ── SOS operations ───────────────────────────────────────────────────

  /// Trigger SOS — writes to Firebase, Cloud Function handles FCM + SMS
  static Future<void> triggerSOS({
    required String journeyId,
    required double lat,
    required double lng,
    required String currentLegMode,
    required String currentLegRoute,
    required List<Checkpoint> lastCheckpoints,
  }) async {
    await _db.ref('journeys/$journeyId').update({
      'status': JourneyStatus.sos.name,
      'sos_data': {
        'triggered_at': DateTime.now().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'current_mode': currentLegMode,
        'current_route': currentLegRoute,
        'checkpoint_trail': lastCheckpoints
            .take(5)
            .map((c) => c.toJson())
            .toList(),
      },
    });
  }

  // ── User operations ──────────────────────────────────────────────────

  static Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phone,
    required List<String> emergencyContacts,
    double safetyThreshold = 70.0,
    bool womensModeDefault = false,
  }) async {
    await _db.ref('users/$uid').set({
      'name': name,
      'phone': phone,
      'emergency_contacts': emergencyContacts,
      'safety_threshold': safetyThreshold,
      'womens_mode': womensModeDefault,
    });
  }

  static Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    return _db.ref('users/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    });
  }

  // ── Safety score data (seeded, read-only) ────────────────────────────

  static Future<Map<String, dynamic>?> getSafetyScore(String zoneId) async {
    final snap = await _db.ref('safety_scores/$zoneId').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }
}
