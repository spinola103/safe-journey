import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/journey_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/route_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Known Chennai stop coordinates for demo polylines
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, LatLng> _stopLatLng = {
  'tambaram': LatLng(12.9249, 80.0999),
  'tambaram bus stop': LatLng(12.9260, 80.1010),
  'guindy': LatLng(13.0067, 80.2206),
  'guindy metro': LatLng(13.0082, 80.2200),
  't.nagar': LatLng(13.0357, 80.2334),
  'tnagar': LatLng(13.0357, 80.2334),
  'anna nagar': LatLng(13.0850, 80.2101),
  'anna nagar east': LatLng(13.0848, 80.2132),
  'anna nagar tower': LatLng(13.0871, 80.2095),
  'adyar': LatLng(13.0012, 80.2565),
  'adyar bus stop': LatLng(13.0005, 80.2560),
  'adyar depot': LatLng(13.0018, 80.2570),
  'egmore': LatLng(13.0732, 80.2609),
  'saidapet': LatLng(13.0212, 80.2258),
  'saidapet metro': LatLng(13.0205, 80.2248),
  'little mount': LatLng(13.0253, 80.2275),
  'chromepet': LatLng(12.9516, 80.1462),
  'velachery': LatLng(12.9815, 80.2209),
  'chennai central': LatLng(13.0827, 80.2751),
  'chennai beach': LatLng(13.0974, 80.2874),
  'chennai beach metro': LatLng(13.0970, 80.2868),
  'koyambedu': LatLng(13.0694, 80.1948),
  'perambur': LatLng(13.1177, 80.2427),
  'junction': LatLng(13.0450, 80.2200),
  'mylapore': LatLng(13.0336, 80.2677),
};

LatLng? _ll(String stop) {
  final key = stop.toLowerCase().trim();
  if (_stopLatLng.containsKey(key)) return _stopLatLng[key];
  for (final e in _stopLatLng.entries) {
    if (key.contains(e.key) || e.key.contains(key)) return e.value;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// RouteResultsScreen
// ─────────────────────────────────────────────────────────────────────────────
class RouteResultsScreen extends StatefulWidget {
  final List<JourneyPlan> plans;
  final bool womensMode;
  const RouteResultsScreen({
  super.key,
  required this.plans,
  this.womensMode = false,
});

  @override
  State<RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends State<RouteResultsScreen> {
  List<String> get labels =>
    widget.womensMode
        ? ['Safest', 'Safe Cheapest', 'Safe Fastest']
        : ['Fastest', 'Cheapest', 'Safest'];
  static const _labelColors = [
    AppColors.teal,
    AppColors.amber,
    AppColors.green,
  ];

  int _selectedIndex = 0; // which plan's route is shown on the map
  GoogleMapController? _mapCtrl;

  // Per-mode colours for polylines
  static Color _modePolyColor(String mode) => switch (mode) {
    'metro' => const Color(0xFF0A9396), // teal
    'rail' => const Color(0xFF6D3A9C), // purple
    'bus' => const Color(0xFFEE9B00), // amber
    'auto' => const Color(0xFFE76F51), // orange
    'walk' => const Color(0xFF3D9970), // green
    _ => const Color(0xFF64748B),
  };

  // Build markers + polylines for a given plan
  ({Set<Marker> markers, Set<Polyline> polylines, LatLngBounds? bounds})
  _buildMapOverlays(JourneyPlan plan) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final allPoints = <LatLng>[];

    for (int i = 0; i < plan.legs.length; i++) {
      final leg = plan.legs[i];
      final color = _modePolyColor(leg.mode);

      // ── Polyline ────────────────────────────────────────────────────
      final List<LatLng> pts;
      if (leg.polylinePoints.isNotEmpty) {
        // Real API points
        pts = leg.polylinePoints;
      } else {
        // Demo: straight line between known stops
        final from = _ll(leg.startStop);
        final to = _ll(leg.endStop);
        pts = (from != null && to != null) ? [from, to] : [];
      }

      if (pts.isNotEmpty) {
        allPoints.addAll(pts);
        polylines.add(
          Polyline(
            polylineId: PolylineId('leg_$i'),
            points: pts,
            color: color,
            width: leg.mode == 'walk' ? 3 : 5,
            patterns: leg.mode == 'walk'
                ? [PatternItem.dash(12), PatternItem.gap(8)]
                : [],
          ),
        );
      }

      // ── Start marker (only for first leg) ────────────────────────────
      if (i == 0) {
        final pos = pts.isNotEmpty ? pts.first : _ll(leg.startStop);
        if (pos != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('origin'),
              position: pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(title: 'From: ${plan.origin}'),
            ),
          );
          allPoints.insert(0, pos);
        }
      }

      // ── Transfer markers (between legs) ──────────────────────────────
      if (i < plan.legs.length - 1) {
        final pos = pts.isNotEmpty ? pts.last : _ll(leg.endStop);
        if (pos != null) {
          markers.add(
            Marker(
              markerId: MarkerId('transfer_$i'),
              position: pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _hueForMode(plan.legs[i + 1].mode),
              ),
              infoWindow: InfoWindow(
                title: leg.endStop,
                snippet: '→ Board ${plan.legs[i + 1].modeLabel}',
              ),
            ),
          );
        }
      }

      // ── Destination marker (last leg) ─────────────────────────────────
      if (i == plan.legs.length - 1) {
        final pos = pts.isNotEmpty ? pts.last : _ll(leg.endStop);
        if (pos != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(title: 'To: ${plan.destination}'),
            ),
          );
          allPoints.add(pos);
        }
      }
    }

    // Compute bounds to fit all points
    LatLngBounds? bounds;
    if (allPoints.length >= 2) {
      double minLat = allPoints.first.latitude;
      double maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude;
      double maxLng = allPoints.first.longitude;
      for (final p in allPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.005, minLng - 0.005),
        northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
      );
    }
    return (markers: markers, polylines: polylines, bounds: bounds);
  }

  static double _hueForMode(String mode) => switch (mode) {
    'metro' => BitmapDescriptor.hueCyan,
    'rail' => BitmapDescriptor.hueViolet,
    'bus' => BitmapDescriptor.hueYellow,
    'auto' => BitmapDescriptor.hueOrange,
    _ => BitmapDescriptor.hueGreen,
  };

  void _onCardTapped(int index) {
    setState(() => _selectedIndex = index);
    final overlays = _buildMapOverlays(widget.plans[index]);
    if (overlays.bounds != null) {
      _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngBounds(overlays.bounds!, 60),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plans[_selectedIndex];
    final overlays = _buildMapOverlays(plan);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.navy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.plans.first.origin} → ${widget.plans.first.destination}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.plans.length} routes found',
                  style: TextStyle(fontSize: 11, color: AppColors.tealMid),
                ),
              ],
            ),
          ),

          // ── Route map ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(13.0067, 80.2206), // Guindy centre
                      zoom: 11,
                    ),
                    onMapCreated: (c) {
                      _mapCtrl = c;
                      final b = overlays.bounds;
                      if (b != null) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _mapCtrl?.animateCamera(
                            CameraUpdate.newLatLngBounds(b, 60),
                          );
                        });
                      }
                    },
                    markers: overlays.markers,
                    polylines: overlays.polylines,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                  ),

                  // ── Legend overlay ──────────────────────────────────
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final leg in plan.legs) ...[
                            Container(
                              width: 12,
                              height: 4,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: _modePolyColor(leg.mode),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Text(
                              leg.modeLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Route tab selector ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: List.generate(widget.plans.length, (i) {
                  final selected = i == _selectedIndex;
                  final color = _labelColors[i];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onCardTapped(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? color : color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withValues(alpha: selected ? 0 : 0.3),
                          ),
                        ),
                        child: Text(
                          i < labels.length ? labels[i] : 'Route ${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── Route cards ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RouteCard(
                    plan: widget.plans[i],
                    label: i < labels.length ? labels[i] : '',
                    labelColor: i < _labelColors.length
                        ? _labelColors[i]
                        : AppColors.teal,
                    womensMode: widget.womensMode,
                    isSelected: i == _selectedIndex,
                    onTap: () => _onCardTapped(i),
                    onStartJourney: () =>
                        context.push('/journey', extra: widget.plans[i]),
                    onEditRoute: () =>
                        context.push('/editor', extra: widget.plans[i]),
                  ),
                ),
                childCount: widget.plans.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


