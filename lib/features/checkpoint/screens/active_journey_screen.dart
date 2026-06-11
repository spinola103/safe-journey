import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../../core/models/journey_plan.dart';
import '../../../core/models/leg.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stop coordinates (same table as results screen)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, LatLng> _stopLatLng = {
  'tambaram':           LatLng(12.9249, 80.0999),
  'tambaram bus stop':  LatLng(12.9260, 80.1010),
  'guindy':             LatLng(13.0067, 80.2206),
  'guindy metro':       LatLng(13.0082, 80.2200),
  't.nagar':            LatLng(13.0357, 80.2334),
  'tnagar':             LatLng(13.0357, 80.2334),
  'anna nagar':         LatLng(13.0850, 80.2101),
  'adyar':              LatLng(13.0012, 80.2565),
  'adyar bus stop':     LatLng(13.0005, 80.2560),
  'egmore':             LatLng(13.0732, 80.2609),
  'saidapet':           LatLng(13.0212, 80.2258),
  'saidapet metro':     LatLng(13.0205, 80.2248),
  'little mount':       LatLng(13.0253, 80.2275),
  'chromepet':          LatLng(12.9516, 80.1462),
  'velachery':          LatLng(12.9815, 80.2209),
  'chennai central':    LatLng(13.0827, 80.2751),
  'chennai beach':      LatLng(13.0974, 80.2874),
  'chennai beach metro':LatLng(13.0970, 80.2868),
  'koyambedu':          LatLng(13.0694, 80.1948),
  'junction':           LatLng(13.0450, 80.2200),
  'mylapore':           LatLng(13.0336, 80.2677),
};

LatLng? _ll(String stop) {
  final key = stop.toLowerCase().trim();
  if (_stopLatLng.containsKey(key)) return _stopLatLng[key];
  for (final e in _stopLatLng.entries) {
    if (key.contains(e.key) || e.key.contains(key)) return e.value;
  }
  return null;
}

Color _modePolyColor(String mode) => switch (mode) {
  'metro' => const Color(0xFF0A9396),
  'rail'  => const Color(0xFF6D3A9C),
  'bus'   => const Color(0xFFEE9B00),
  'auto'  => const Color(0xFFE76F51),
  'walk'  => const Color(0xFF3D9970),
  _       => const Color(0xFF64748B),
};

// ─────────────────────────────────────────────────────────────────────────────
// Simulated position: interpolates from origin toward destination over time
// ─────────────────────────────────────────────────────────────────────────────
LatLng _interpolate(LatLng a, LatLng b, double t) {
  t = t.clamp(0.0, 1.0);
  return LatLng(a.latitude + (b.latitude - a.latitude) * t,
                a.longitude + (b.longitude - a.longitude) * t);
}

// ─────────────────────────────────────────────────────────────────────────────
// ActiveJourneyScreen
// ─────────────────────────────────────────────────────────────────────────────
class ActiveJourneyScreen extends StatefulWidget {
  final JourneyPlan plan;
  const ActiveJourneyScreen({super.key, required this.plan});

  @override
  State<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends State<ActiveJourneyScreen>
    with TickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  LatLng?       _currentPos;

  // ── Journey progress ─────────────────────────────────────────────────────
  int  _currentLegIndex = 0;
  final List<bool> _checkpoints = [];

  // ── SOS ──────────────────────────────────────────────────────────────────
  bool   _sosActive   = false;
  bool   _sosHolding  = false;
  double _sosProgress = 0;
  Timer? _sosTimer;

  // ── Simulation ───────────────────────────────────────────────────────────
  Timer? _simTimer;
  double _simT = 0;       // 0 → 1 across the whole journey

  // ── Pulse animation ───────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  // ── ETA ───────────────────────────────────────────────────────────────────
  int get _etaMinutes {
    int remaining = 0;
    for (int i = _currentLegIndex; i < widget.plan.legs.length; i++) {
      remaining += widget.plan.legs[i].durationMinutes;
    }
    // Deduct simulated progress inside current leg
    if (_currentLegIndex < widget.plan.legs.length) {
      final legFraction = (_simT * widget.plan.legs.length) - _currentLegIndex;
      remaining -= (widget.plan.legs[_currentLegIndex].durationMinutes * legFraction).toInt();
    }
    return remaining.clamp(0, 9999);
  }

  // ── Next checkpoint name ───────────────────────────────────────────────────
  String get _nextCheckpointName {
    if (_currentLegIndex < widget.plan.legs.length) {
      return widget.plan.legs[_currentLegIndex].endStop;
    }
    return widget.plan.destination;
  }

  @override
  void initState() {
    super.initState();
    _checkpoints.addAll(List.filled(widget.plan.legs.length + 1, false));
    _checkpoints[0] = true;

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _buildStaticOverlays();
    _startSimulation();
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _simTimer?.cancel();
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Build the full route polylines + stop markers ─────────────────────────
  void _buildStaticOverlays() {
    final markers   = <Marker>{};
    final polylines = <Polyline>{};

    for (int i = 0; i < widget.plan.legs.length; i++) {
      final leg   = widget.plan.legs[i];
      final color = _modePolyColor(leg.mode);

      final List<LatLng> pts;
      if (leg.polylinePoints.isNotEmpty) {
        pts = leg.polylinePoints;
      } else {
        final from = _ll(leg.startStop);
        final to   = _ll(leg.endStop);
        pts = (from != null && to != null) ? [from, to] : [];
      }

      if (pts.isNotEmpty) {
        // Upcoming legs shown dimmed; current + past shown full colour
        final opacity = i <= _currentLegIndex ? 1.0 : 0.35;
        polylines.add(Polyline(
          polylineId: PolylineId('leg_$i'),
          points: pts,
          color: color.withOpacity(opacity),
          width: leg.mode == 'walk' ? 3 : 5,
          patterns: leg.mode == 'walk'
              ? [PatternItem.dash(12), PatternItem.gap(8)]
              : [],
        ));
      }

      // Stop markers
      if (i == 0) {
        final p = pts.isNotEmpty ? pts.first : _ll(leg.startStop);
        if (p != null) {
          markers.add(Marker(
            markerId: const MarkerId('origin'),
            position: p,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: 'Start: ${widget.plan.origin}'),
          ));
        }
      }
      if (i == widget.plan.legs.length - 1) {
        final p = pts.isNotEmpty ? pts.last : _ll(leg.endStop);
        if (p != null) {
          markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: p,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Destination: ${widget.plan.destination}'),
          ));
        }
      }
    }

    if (mounted) setState(() { _markers = markers; _polylines = polylines; });
  }

  // ── Simulation: move "current position" dot along the route ───────────────
  void _startSimulation() {
    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _simT = (_simT + 0.004).clamp(0.0, 1.0);   // 2s tick → ~8 min to cross all legs

      // Compute overall list of key LatLngs
      final keyPoints = <LatLng>[];
      for (final leg in widget.plan.legs) {
        final from = leg.polylinePoints.isNotEmpty
            ? leg.polylinePoints.first
            : _ll(leg.startStop);
        final to   = leg.polylinePoints.isNotEmpty
            ? leg.polylinePoints.last
            : _ll(leg.endStop);
        if (from != null) keyPoints.add(from);
        if (to   != null) keyPoints.add(to);
      }

      LatLng? newPos;
      if (keyPoints.length >= 2) {
        final n = keyPoints.length - 1;
        final fi = (_simT * n).clamp(0.0, n.toDouble());
        final idx = fi.floor().clamp(0, n - 1);
        final frac = fi - idx;
        newPos = _interpolate(keyPoints[idx], keyPoints[idx + 1], frac);
      }

      // Advance leg index based on simT
      final newLegIndex = (_simT * widget.plan.legs.length)
          .floor()
          .clamp(0, widget.plan.legs.length - 1);

      setState(() {
        _currentPos = newPos;
        _currentLegIndex = newLegIndex;
      });

      // Animate camera to follow
      if (newPos != null) {
        _mapCtrl?.animateCamera(CameraUpdate.newLatLng(newPos));
      }
    });
  }

  // ── Checkpoint tap ─────────────────────────────────────────────────────────
  void _verifyCheckpoint(int index) {
    if (_checkpoints[index]) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _checkpoints[index] = true;
      if (index < widget.plan.legs.length) _currentLegIndex = index;
    });
    _buildStaticOverlays();
  }

  // ── SOS ───────────────────────────────────────────────────────────────────
  void _startSosHold() {
    HapticFeedback.heavyImpact();
    setState(() { _sosHolding = true; _sosProgress = 0; });
    _sosTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _sosProgress += 1 / 60);
      if (_sosProgress >= 1.0) { t.cancel(); _triggerSOS(); }
    });
  }

  void _cancelSosHold() {
    _sosTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() { _sosHolding = false; _sosProgress = 0; });
  }

  void _triggerSOS() {
    HapticFeedback.vibrate();
    setState(() { _sosActive = true; _sosHolding = false; });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: AppColors.red, size: 24),
          SizedBox(width: 8),
          Text('SOS Triggered', style: TextStyle(color: AppColors.red, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alert sent to:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            _SOSRecipient(icon: Icons.people_rounded,  color: AppColors.teal,  label: 'Guardian — FCM push sent'),
            const SizedBox(height: 6),
            _SOSRecipient(icon: Icons.message_rounded, color: AppColors.amber, label: 'Emergency contacts — SMS sent'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(8)),
              child: const Text('Location, vehicle, and last 5 checkpoints shared.',
                  style: TextStyle(fontSize: 12, color: AppColors.gray)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); setState(() => _sosActive = false); },
            child: const Text('Cancel SOS', style: TextStyle(color: AppColors.gray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text("I'm Safe"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan       = widget.plan;
    final currentLeg = _currentLegIndex < plan.legs.length
        ? plan.legs[_currentLegIndex] : plan.legs.last;

    // Build current-position marker dynamically
    final displayMarkers = Set<Marker>.from(_markers);
    if (_currentPos != null) {
      displayMarkers.add(Marker(
        markerId: const MarkerId('current'),
        position: _currentPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: const InfoWindow(title: 'You are here'),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          // ── Live map ───────────────────────────────────────────────────────
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _ll(plan.origin) ?? const LatLng(13.0067, 80.2206),
                    zoom: 12,
                  ),
                  onMapCreated: (c) {
                    _mapCtrl = c;
                    if (_currentPos != null) {
                      c.animateCamera(CameraUpdate.newLatLng(_currentPos!));
                    }
                  },
                  markers:   displayMarkers,
                  polylines: _polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),

                // ── App bar overlay ──────────────────────────────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    color: AppColors.navy.withOpacity(0.88),
                    padding: EdgeInsets.fromLTRB(
                        16, MediaQuery.of(context).padding.top + 8, 16, 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Journey Active',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                              Text('${plan.origin} → ${plan.destination}',
                                  style: TextStyle(color: AppColors.tealMid, fontSize: 11)),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: _sosActive ? AppColors.red : AppColors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Live info bar (ETA + next checkpoint) ────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    color: AppColors.navy,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      children: [
                        Text(currentLeg.modeEmoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('On: ${currentLeg.modeLabel}'
                                  '${currentLeg.routeLabel != null ? " · ${currentLeg.routeLabel}" : ""}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('Next stop: $_nextCheckpointName',
                                  style: TextStyle(color: AppColors.tealMid, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$_etaMinutes min',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            Text('ETA',
                                style: TextStyle(color: AppColors.tealMid, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body scrollable ─────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                // Progress header
                Row(
                  children: [
                    const Text('Checkpoints',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    const Spacer(),
                    Text(
                      '${_checkpoints.where((v) => v).length} / ${_checkpoints.length} verified',
                      style: const TextStyle(fontSize: 11, color: AppColors.gray),
                    ),
                  ],
                ),

                // Progress bar
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _checkpoints.where((v) => v).length / _checkpoints.length,
                    backgroundColor: AppColors.lightGray,
                    color: AppColors.teal,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 14),

                // Checkpoint tiles
                ...List.generate(plan.legs.length, (i) {
                  final leg      = plan.legs[i];
                  final verified = _checkpoints[i];
                  final isActive = i == _currentLegIndex;
                  return _CheckpointTile(
                    stopName:   leg.startStop,
                    legLabel:   leg.modeLabel,
                    routeLabel: leg.routeLabel,
                    verified:   verified,
                    isActive:   isActive,
                    onTap:      () => _verifyCheckpoint(i),
                  );
                }),

                // Final destination tile
                _CheckpointTile(
                  stopName:   plan.destination,
                  legLabel:   'Destination',
                  routeLabel: null,
                  verified:   _checkpoints[plan.legs.length],
                  isActive:   false,
                  onTap:      () => _verifyCheckpoint(plan.legs.length),
                ),

                const SizedBox(height: 16),

                // Guardian card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.teal.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_rounded, color: AppColors.teal, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Guardian is watching your journey live',
                            style: TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w500)),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Share link', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── SOS button ─────────────────────────────────────────────────────────
      bottomSheet: Container(
        color: AppColors.offWhite,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sosHolding) ...[
              Text(
                'Hold to confirm SOS... ${(3 * (1 - _sosProgress)).toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 12, color: AppColors.red),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _sosProgress,
                  backgroundColor: AppColors.lightGray,
                  color: AppColors.red,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
            ],
            GestureDetector(
              onLongPressStart: (_) => _startSosHold(),
              onLongPressEnd:   (_) { if (!_sosActive) _cancelSosHold(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _sosHolding ? AppColors.red : AppColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded,
                        color: _sosHolding ? Colors.white : AppColors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _sosActive ? 'SOS Active' : 'Hold 3 seconds for SOS',
                      style: TextStyle(
                        color: _sosHolding ? Colors.white : AppColors.red,
                        fontSize: 15, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Checkpoint tile ───────────────────────────────────────────────────────────
class _CheckpointTile extends StatelessWidget {
  final String stopName, legLabel;
  final String? routeLabel;
  final bool verified, isActive;
  final VoidCallback onTap;

  const _CheckpointTile({
    required this.stopName, required this.legLabel,
    required this.routeLabel, required this.verified,
    required this.isActive,  required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: verified ? AppColors.teal.withOpacity(0.06) : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.teal : (verified ? AppColors.teal.withOpacity(0.3) : AppColors.lightGray),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: verified ? AppColors.teal : AppColors.lightGray,
                  shape: BoxShape.circle),
              child: Icon(
                verified ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                color: verified ? Colors.white : AppColors.gray,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stopName,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: verified ? AppColors.teal : AppColors.navy)),
                  Text(routeLabel != null ? '$legLabel · $routeLabel' : legLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.gray)),
                ],
              ),
            ),
            if (verified)
              const Text('✓ Verified',
                  style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600))
            else if (isActive)
              const Text('Tap to verify',
                  style: TextStyle(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SOSRecipient extends StatelessWidget {
  final IconData icon; final Color color; final String label;
  const _SOSRecipient({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
  ]);
}
