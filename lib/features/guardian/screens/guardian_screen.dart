import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/demo_routes.dart';
import '../../../core/models/journey_plan.dart';
import '../../../core/models/leg.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/data/app_session.dart';
import 'package:firebase_database/firebase_database.dart';

// ── Known stop coordinates ────────────────────────────────────────────────────
const Map<String, LatLng> _stopLatLng = {
  'tambaram': LatLng(12.9249, 80.0999),
  'tambaram bus stop': LatLng(12.9260, 80.1010),
  'guindy': LatLng(13.0067, 80.2206),
  'guindy metro': LatLng(13.0082, 80.2200),
  't.nagar': LatLng(13.0357, 80.2334),
  'tnagar': LatLng(13.0357, 80.2334),
  'anna nagar': LatLng(13.0850, 80.2101),
  'adyar': LatLng(13.0012, 80.2565),
  'egmore': LatLng(13.0732, 80.2609),
  'saidapet': LatLng(13.0212, 80.2258),
  'little mount': LatLng(13.0253, 80.2275),
  'chromepet': LatLng(12.9516, 80.1462),
  'velachery': LatLng(12.9815, 80.2209),
  'chennai central': LatLng(13.0827, 80.2751),
  'koyambedu': LatLng(13.0694, 80.1948),
  'junction': LatLng(13.0450, 80.2200),
  'mylapore': LatLng(13.0336, 80.2677),
  'pallavaram': LatLng(12.9677, 80.1495),
  'perambur': LatLng(13.1152, 80.2337),
  'sholinganallur': LatLng(12.9010, 80.2279),
  'thiruvanmiyur': LatLng(12.9829, 80.2593),
  'porur': LatLng(13.0358, 80.1573),
  'ambattur': LatLng(13.1143, 80.1548),
};

LatLng? _ll(String stop) {
  final key = stop.toLowerCase().trim();
  if (_stopLatLng.containsKey(key)) return _stopLatLng[key];
  for (final e in _stopLatLng.entries) {
    if (key.contains(e.key) || e.key.contains(key)) return e.value;
  }
  return null;
}

Color _modeColor(String mode) => switch (mode) {
  'metro' => const Color(0xFF0A9396),
  'rail' => const Color(0xFF6D3A9C),
  'bus' => const Color(0xFFEE9B00),
  'auto' => const Color(0xFFE76F51),
  'walk' => const Color(0xFF3D9970),
  _ => const Color(0xFF64748B),
};

// ─────────────────────────────────────────────────────────────────────────────
// GuardianScreen
// ─────────────────────────────────────────────────────────────────────────────
class GuardianScreen extends StatefulWidget {
  final String journeyId;

  /// Optional: pass traveller name when navigating from ActiveJourneyScreen
  /// so the guardian sees a real name, not a generic placeholder.
  final String? travellerName;

  const GuardianScreen({
    super.key,
    required this.journeyId,
    this.travellerName,
  });

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen>
    with SingleTickerProviderStateMixin {
  // ── Live data from Firebase (fallback to demo until first snapshot) ────────
  JourneyPlan? _livePlan;
  JourneyPlan get _plan => _livePlan ?? DemoRoutes.tambToTNagarFastest;

  // ── Traveller profile from Firebase ───────────────────────────────────────
  String _travellerName = '';
  String _travellerPhone = '';

  // ── Firebase stream ────────────────────────────────────────────────────────
  StreamSubscription? _journeySub;
  StreamSubscription? _userSub;
  StreamSubscription? _locationSub;
  bool _isLive = false;

  // ── Pulse animation ────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // ── Map ────────────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;

  // ── Position (moves from Firebase last_location, or simulated for demo) ───
  LatLng? _currentPos;
  double _simT = 0.25;
  Timer? _simTimer;

  // ── Last location update time (shows freshness) ────────────────────────────
  DateTime? _lastUpdateTime;

  // ─────────────────────────────────────────────────────────────────────────
  // Derived state
  // ─────────────────────────────────────────────────────────────────────────

  String get _displayName {
    if (_travellerName.isNotEmpty) return _travellerName;

    if (widget.travellerName != null && widget.travellerName!.isNotEmpty) {
      return widget.travellerName!;
    }

    if (AppSession.name.isNotEmpty) {
      return AppSession.name;
    }

    if (_plan.userId.isNotEmpty && _plan.userId != 'current_user') {
      return _plan.userId;
    }

    return 'Traveller';
  }

  String get _displayInitial => _displayName[0].toUpperCase();

  int get _verifiedCount => _plan.checkpoints.where((c) => c.verified).length;

  int get _currentLegIndex => _verifiedCount.clamp(0, _plan.legs.length - 1);

  // ETA in minutes (remaining legs)
  int get _etaMinutes {
    int remaining = 0;
    for (int i = _currentLegIndex; i < _plan.legs.length; i++) {
      remaining += _plan.legs[i].durationMinutes;
    }
    final simDeduct = (_simT * _plan.totalMinutes).toInt();
    return (remaining - simDeduct).clamp(0, 9999);
  }

  // Checkpoint trail — real Firebase checkpoints, else demo trail
  List<_TrailEvent> get _trail {
    final events = <_TrailEvent>[];

    if (_plan.checkpoints.isNotEmpty) {
      // Real data from Firebase
      for (final cp in _plan.checkpoints) {
        events.add(
          _TrailEvent(
            stop: cp.stopName,
            time: _fmtTime(cp.time),
            mode: cp.mode,
            verified: cp.verified,
            isPending: false,
          ),
        );
      }
    } else {
      // Demo trail — shows something meaningful before Firebase data arrives
      events.add(
        _TrailEvent(
          stop: _plan.origin,
          time: _fmtTime(DateTime.now().subtract(const Duration(minutes: 20))),
          mode: _plan.legs.isNotEmpty ? _plan.legs[0].mode : 'walk',
          verified: true,
          isPending: false,
        ),
      );
      if (_plan.legs.length > 1) {
        events.add(
          _TrailEvent(
            stop: _plan.legs[0].endStop,
            time: _fmtTime(
              DateTime.now().subtract(const Duration(minutes: 10)),
            ),
            mode: _plan.legs[1].mode,
            verified: true,
            isPending: false,
          ),
        );
      }
    }

    // Always add next pending checkpoint
    if (_currentLegIndex < _plan.legs.length) {
      final nextLeg = _plan.legs[_currentLegIndex];
      events.add(
        _TrailEvent(
          stop: nextLeg.endStop,
          time: 'Expected in ~${nextLeg.durationMinutes} min',
          mode: nextLeg.mode,
          verified: false,
          isPending: true,
        ),
      );
    }

    return events;
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String get _lastUpdateLabel {
    if (_lastUpdateTime == null) return 'GPS auto-verified';
    final diff = DateTime.now().difference(_lastUpdateTime!);
    if (diff.inSeconds < 60) return 'Updated ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${_fmtTime(_lastUpdateTime!)}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    print('Guardian ID = ${widget.journeyId}');
    // Pulse animation
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Firebase journey stream
    _journeySub = FirebaseService.watchJourney(widget.journeyId).listen(
      (plan) {
        print("PLAN RECEIVED = $plan");
        print("PLAN ID = ${plan?.id}");
        if (mounted && plan != null) {
          setState(() {
            _livePlan = plan;
            _isLive = true;
            _lastUpdateTime = DateTime.now();
          });
          // Load traveller profile using userId from plan
          if (plan.userId.isNotEmpty && plan.userId != 'current_user') {
            _loadUserProfile(plan.userId);
          }
        }
      },
      onError: (_) {
        // Firebase unavailable — silently stay on demo
      },
    );
    _locationSub =FirebaseDatabase.instance
        .ref('journeys/${widget.journeyId}/last_location')
        .onValue
        .listen((event) {
          final data = event.snapshot.value;

          if (data == null) return;

          final map = Map<String, dynamic>.from(data as Map);

          setState(() {
            _currentPos = LatLng(
              (map['lat'] as num).toDouble(),
              (map['lng'] as num).toDouble(),
            );

            _lastUpdateTime = DateTime.tryParse(
              map['timestamp']?.toString() ?? '',
            );
          });

          print("LIVE LOCATION: $_currentPos");
        });

    // Simulated position for demo (stops when real GPS arrives from Firebase)
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      // Only simulate if no real location from Firebase
      if (!_isLive) {
        setState(() => _simT = (_simT + 0.006).clamp(0.0, 1.0));
        _updateSimulatedPosition();
      }
    });
  }

  void _loadUserProfile(String userId) {
    _userSub?.cancel();
    _userSub = FirebaseService.watchUserProfile(userId).listen((profile) {
      if (mounted && profile != null) {
        setState(() {
          _travellerName = profile['name'] as String? ?? '';
          _travellerPhone = profile['phone'] as String? ?? '';
        });
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _journeySub?.cancel();
    _userSub?.cancel();
    _simTimer?.cancel();
     _locationSub?.cancel();
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Map helpers ───────────────────────────────────────────────────────────
  void _updateSimulatedPosition() {
    final keyPoints = <LatLng>[];
    for (final leg in _plan.legs) {
      if (leg.polylinePoints.isNotEmpty) {
        keyPoints.addAll(leg.polylinePoints);
      } else {
        final from = _ll(leg.startStop);
        final to = _ll(leg.endStop);
        if (from != null) keyPoints.add(from);
        if (to != null) keyPoints.add(to);
      }
    }
    if (keyPoints.length < 2) return;
    final n = keyPoints.length - 1;
    final fi = (_simT * n).clamp(0.0, n.toDouble());
    final idx = fi.floor().clamp(0, n - 1);
    final t = fi - idx;
    final a = keyPoints[idx];
    final b = keyPoints[idx + 1];
    final pos = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    if (mounted) setState(() => _currentPos = pos);
  }

  Set<Polyline> _buildPolylines() {
    final lines = <Polyline>{};
    for (int i = 0; i < _plan.legs.length; i++) {
      final leg = _plan.legs[i];
      final color = _modeColor(leg.mode);
      final done = i < _currentLegIndex;
      final pts = leg.polylinePoints.isNotEmpty
          ? leg.polylinePoints
          : [_ll(leg.startStop), _ll(leg.endStop)].whereType<LatLng>().toList();
      if (pts.length < 2) continue;
      lines.add(
        Polyline(
          polylineId: PolylineId('leg_$i'),
          points: pts,
          color: done ? color : color.withValues(alpha: 0.35),
          width: leg.mode == 'walk' ? 3 : 5,
          patterns: leg.mode == 'walk'
              ? [PatternItem.dash(12), PatternItem.gap(8)]
              : [],
        ),
      );
    }
    return lines;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    final originLL = _ll(_plan.origin);
    if (originLL != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: originLL,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: 'Start: ${_plan.origin}'),
        ),
      );
    }

    final destLL = _ll(_plan.destination);
    if (destLL != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destLL,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination: ${_plan.destination}'),
        ),
      );
    }

    if (_currentPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('live'),
          position: _currentPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(title: '$_displayName is here'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    return markers;
  }

  void _fitMapToBounds() {
    final pts = [
      _ll(_plan.origin),
      _ll(_plan.destination),
    ].whereType<LatLng>().toList();
    if (pts.length == 2) {
      _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              pts[0].latitude < pts[1].latitude
                  ? pts[0].latitude
                  : pts[1].latitude,
              pts[0].longitude < pts[1].longitude
                  ? pts[0].longitude
                  : pts[1].longitude,
            ),
            northeast: LatLng(
              pts[0].latitude > pts[1].latitude
                  ? pts[0].latitude
                  : pts[1].latitude,
              pts[0].longitude > pts[1].longitude
                  ? pts[0].longitude
                  : pts[1].longitude,
            ),
          ),
          60,
        ),
      );
    }
  }

  // ── SOS alert dialog ──────────────────────────────────────────────────────
  void _showSOSAlert() {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.red, size: 22),
            SizedBox(width: 8),
            Text(
              'SOS Alert',
              style: TextStyle(color: AppColors.red, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_displayName has triggered an SOS.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last known location, route details, and checkpoint trail have been shared. Call immediately.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.gray,
                height: 1.5,
              ),
            ),
            if (_plan.status == JourneyStatus.sos) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SOS Details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Route: ${_plan.origin} → ${_plan.destination}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.navy,
                      ),
                    ),
                    if (_plan.legs.isNotEmpty)
                      Text(
                        'Last transport: ${_plan.legs[_currentLegIndex].modeLabel}'
                        '${_plan.legs[_currentLegIndex].routeLabel != null ? " · ${_plan.legs[_currentLegIndex].routeLabel}" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.navy,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _callTraveller();
            },
            icon: const Icon(Icons.call_rounded, size: 14),
            label: const Text('Call Now'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
          ),
        ],
      ),
    );
  }

  void _callTraveller() {
    // In production: use url_launcher to call _travellerPhone
    // For demo: show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.call_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              _travellerPhone.isNotEmpty
                  ? 'Calling $_travellerPhone...'
                  : 'Calling $_displayName...',
            ),
          ],
        ),
        backgroundColor: AppColors.teal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentLeg = _plan.legs[_currentLegIndex];
    final trail = _trail;
    final lastVerified = trail.lastWhere(
      (e) => e.verified,
      orElse: () => trail.first,
    );

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.navy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guardian View',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _isLive
                      ? 'Watching ${_plan.origin} → ${_plan.destination}'
                      : 'Demo mode',
                  style: TextStyle(color: AppColors.tealMid, fontSize: 11),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isLive ? AppColors.teal : AppColors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isLive ? 'LIVE' : 'DEMO',
                      style: TextStyle(
                        color: _isLive ? AppColors.teal : AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Live map ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _ll(_plan.origin) ?? const LatLng(13.0067, 80.2206),
                      zoom: 11,
                    ),
                    onMapCreated: (c) {
                      _mapCtrl = c;
                      Future.delayed(
                        const Duration(milliseconds: 400),
                        _fitMapToBounds,
                      );
                    },
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                  ),

                  // Follow button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPos != null) {
                          _mapCtrl?.animateCamera(
                            CameraUpdate.newLatLngZoom(_currentPos!, 14),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 14,
                              color: AppColors.teal,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Follow',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom bar: current mode + ETA
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: AppColors.navy.withValues(alpha: 0.90),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            currentLeg.modeEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'On ${currentLeg.modeLabel}'
                              '${currentLeg.routeLabel != null ? " · ${currentLeg.routeLabel}" : ""}'
                              ' → ${currentLeg.endStop}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'ETA ~$_etaMinutes min',
                            style: const TextStyle(
                              color: AppColors.tealMid,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Traveller card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar with real initial
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.teal.withValues(
                              alpha: 0.25,
                            ),
                            child: Text(
                              _displayInitial,
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Real traveller name from Firebase / prop
                                Text(
                                  _displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${_plan.origin} → ${_plan.destination}',
                                  style: const TextStyle(
                                    color: AppColors.tealMid,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Call button — wired to _callTraveller
                          ElevatedButton.icon(
                            onPressed: _callTraveller,
                            icon: const Icon(Icons.call_rounded, size: 14),
                            label: const Text(
                              'Call',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 12),

                      // Stats row — live data
                      Row(
                        children: [
                          _GStat(
                            icon: Icons.location_on_rounded,
                            value: lastVerified.stop,
                            label: 'Last seen',
                          ),
                          const SizedBox(width: 20),
                          _GStat(
                            icon: Icons.schedule_rounded,
                            value: lastVerified.time,
                            label: 'At',
                          ),
                          const SizedBox(width: 20),
                          _GStat(
                            icon: Icons.flag_rounded,
                            value: '$_etaMinutes min',
                            label: 'ETA remaining',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Progress banner ───────────────────────────────────────
                _ProgressBanner(
                  verifiedCount: _verifiedCount > 0 ? _verifiedCount : 1,
                  total: _plan.legs.length,
                  isSOS: _plan.status == JourneyStatus.sos,
                  lastUpdateLabel: _lastUpdateLabel,
                ),

                // SOS card (visible only when SOS active)
                if (_plan.status == JourneyStatus.sos) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showSOSAlert,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            color: AppColors.red,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SOS triggered — tap to view details and call',
                              style: TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.red,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Checkpoint trail ──────────────────────────────────────
                const Text(
                  'Checkpoint Trail',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),

                ...trail.map((e) => _TrailTile(event: e)),

                const SizedBox(height: 20),

                // ── Journey plan ──────────────────────────────────────────
                const Text(
                  'Journey Plan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),

                ..._plan.legs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final leg = entry.value;
                  return _LegRow(
                    leg: leg,
                    done: i < _currentLegIndex,
                    isCurrent: i == _currentLegIndex,
                  );
                }),

                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBanner extends StatelessWidget {
  final int verifiedCount, total;
  final bool isSOS;
  final String lastUpdateLabel;

  const _ProgressBanner({
    required this.verifiedCount,
    required this.total,
    required this.isSOS,
    required this.lastUpdateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSOS ? AppColors.red : AppColors.teal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSOS ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSOS
                      ? 'SOS — journey paused'
                      : 'On track — $verifiedCount of $total legs completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: verifiedCount / total,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lastUpdateLabel,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _TrailEvent {
  final String stop, time, mode;
  final bool verified, isPending;

  const _TrailEvent({
    required this.stop,
    required this.time,
    required this.mode,
    required this.verified,
    this.isPending = false,
  });

  String get modeLabel => switch (mode) {
    'metro' => '🚇 Metro',
    'bus' => '🚌 Bus',
    'walk' => '🚶 Walk',
    'rail' => '🚆 Rail',
    'auto' => '🛺 Auto',
    _ => mode,
  };
}

class _TrailTile extends StatelessWidget {
  final _TrailEvent event;
  const _TrailTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.isPending
        ? AppColors.amber
        : (event.verified ? AppColors.teal : AppColors.gray);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(
              event.isPending
                  ? Icons.schedule_rounded
                  : (event.verified
                        ? Icons.check_rounded
                        : Icons.radio_button_unchecked),
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.stop,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: event.isPending ? AppColors.amber : AppColors.navy,
                  ),
                ),
                Text(
                  event.isPending
                      ? event.time
                      : '${event.modeLabel} · ${event.time}',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray),
                ),
              ],
            ),
          ),
          if (event.verified)
            const Text(
              'GPS ✓',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (event.isPending)
            const Text(
              'Awaiting...',
              style: TextStyle(fontSize: 10, color: AppColors.amber),
            ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  final Leg leg;
  final bool done, isCurrent;

  const _LegRow({
    required this.leg,
    required this.done,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.teal
        : (isCurrent ? AppColors.amber : AppColors.gray);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : (isCurrent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(leg.modeEmoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${leg.startStop} → ${leg.endStop}',
              style: TextStyle(
                fontSize: 12,
                color: done ? AppColors.teal : AppColors.navy,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '${leg.durationMinutes} min',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _GStat extends StatelessWidget {
  final IconData icon;
  final String value, label;

  const _GStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 10, color: AppColors.tealMid),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.tealMid,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
