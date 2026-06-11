import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/demo_routes.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/journey_plan.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Well-known Chennai landmarks → LatLng (used to pin markers on the map)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, LatLng> _knownPlaces = {
  'tambaram':          LatLng(12.9249, 80.0999),
  't.nagar':           LatLng(13.0357, 80.2334),
  'tnagar':            LatLng(13.0357, 80.2334),
  'anna nagar':        LatLng(13.0850, 80.2101),
  'adyar':             LatLng(13.0012, 80.2565),
  'egmore':            LatLng(13.0732, 80.2609),
  'guindy':            LatLng(13.0067, 80.2206),
  'velachery':         LatLng(12.9815, 80.2209),
  'marina beach':      LatLng(13.0500, 80.2824),
  'chennai central':   LatLng(13.0827, 80.2751),
  'koyambedu':         LatLng(13.0694, 80.1948),
  'perambur':          LatLng(13.1177, 80.2427),
  'chromepet':         LatLng(12.9516, 80.1462),
  'saidapet':          LatLng(13.0212, 80.2258),
  'mylapore':          LatLng(13.0336, 80.2677),
  'porur':             LatLng(13.0358, 80.1568),
  'ambattur':          LatLng(13.1143, 80.1548),
  'perungudi':         LatLng(12.9646, 80.2448),
  'sholinganallur':    LatLng(12.9010, 80.2279),
};

LatLng? _latLngFor(String place) {
  final key = place.toLowerCase().trim();
  for (final entry in _knownPlaces.entries) {
    if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
  }
  return null;
}

// Default camera: Chennai city centre
const _chennaiBounds = CameraPosition(
  target: LatLng(13.0500, 80.2450),
  zoom: 11.5,
);

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _originCtrl = TextEditingController(text: 'Tambaram');
  final _destCtrl   = TextEditingController(text: 'Marina Beach');

  bool _womensModeOn = false;
  bool _searching    = false;

  // Map controller
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  final List<String> _recentSearches = [
    'Tambaram → T.Nagar',
    'Adyar → Egmore',
    'Anna Nagar → Guindy',
  ];

  @override
  void initState() {
    super.initState();
    // Draw initial markers once map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMapMarkers());
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Map helpers ─────────────────────────────────────────────────────────
  void _updateMapMarkers() {
    final fromLL = _latLngFor(_originCtrl.text);
    final toLL   = _latLngFor(_destCtrl.text);

    final markers  = <Marker>{};
    final polylines = <Polyline>{};

    if (fromLL != null) {
      markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: fromLL,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'From: ${_originCtrl.text}'),
      ));
    }
    if (toLL != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: toLL,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'To: ${_destCtrl.text}'),
      ));
    }

    if (fromLL != null && toLL != null) {
      // Simple straight dashed line between the two points
      polylines.add(Polyline(
        polylineId: const PolylineId('route_line'),
        points: [fromLL, toLL],
        color: AppColors.teal,
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));

      // Animate camera to show both markers
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            fromLL.latitude  < toLL.latitude  ? fromLL.latitude  : toLL.latitude,
            fromLL.longitude < toLL.longitude ? fromLL.longitude : toLL.longitude,
          ),
          northeast: LatLng(
            fromLL.latitude  > toLL.latitude  ? fromLL.latitude  : toLL.latitude,
            fromLL.longitude > toLL.longitude ? fromLL.longitude : toLL.longitude,
          ),
        ),
        80,
      ));
    }

    if (mounted) setState(() { _markers = markers; _polylines = polylines; });
  }

  // ── Swap ─────────────────────────────────────────────────────────────────
  void _swapLocations() {
    final tmp = _originCtrl.text;
    _originCtrl.text = _destCtrl.text;
    _destCtrl.text   = tmp;
    _updateMapMarkers();
  }

  // ── Search ───────────────────────────────────────────────────────────────
  Future<void> _searchRoutes() async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);

    final origin      = _originCtrl.text.trim();
    final destination = _destCtrl.text.trim();

    List<JourneyPlan> plans = await RoutingService.fetchRoutes(
      origin: origin,
      destination: destination,
      womensMode: _womensModeOn,
    );

    if (plans.isEmpty) {
      plans = DemoRoutes.routeDatabase['$origin|$destination'] ??
              DemoRoutes.routeDatabase['Tambaram|T.Nagar']!;
    }

    if (mounted) {
      setState(() => _searching = false);
      context.push('/results', extra: plans);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── App bar with map ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.navy,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                children: [
                  // ── Google Map ─────────────────────────────────────────
                  Positioned.fill(
                    child: GoogleMap(
                      initialCameraPosition: _chennaiBounds,
                      onMapCreated: (c) {
                        _mapCtrl = c;
                        _updateMapMarkers();
                      },
                      markers:   _markers,
                      polylines: _polylines,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      liteModeEnabled: false,
                    ),
                  ),

                  // ── Top gradient overlay (for legibility of title) ─────
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: 90,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.navy.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Title row ──────────────────────────────────────────
                  Positioned(
                    top: 48, left: 20, right: 20,
                    child: Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: AppColors.teal, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'SafeJourney',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _womensModeOn = !_womensModeOn),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _womensModeOn ? AppColors.teal : Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _womensModeOn ? AppColors.teal : Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined, size: 14,
                                  color: _womensModeOn ? Colors.white : Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Women's Mode",
                                  style: TextStyle(
                                    color: _womensModeOn ? Colors.white : Colors.white.withOpacity(0.7),
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body content ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search card
                  _SearchCard(
                    originCtrl:   _originCtrl,
                    destCtrl:     _destCtrl,
                    onSwap:       _swapLocations,
                    womensModeOn: _womensModeOn,
                    onSearch:     _searchRoutes,
                    loading:      _searching,
                    onLocationChanged: _updateMapMarkers, // <── triggers map update
                  ),
                  const SizedBox(height: 16),

                  // Women's mode info banner
                  if (_womensModeOn) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: AppColors.teal, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Women's Mode ON — routes with safety score below 70 will be filtered out",
                              style: TextStyle(color: AppColors.teal, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Guardian View button ─────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/guardian/demo_001'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.visibility_rounded, color: AppColors.teal, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Guardian View',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                Text('Monitor a traveller\'s live journey',
                                  style: TextStyle(color: AppColors.tealMid, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.tealMid, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recent searches
                  Text('Recent searches', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._recentSearches.map(
                    (s) => _RecentSearchTile(
                      query: s,
                      onTap: () {
                        final parts = s.split(' → ');
                        if (parts.length == 2) {
                          _originCtrl.text = parts[0];
                          _destCtrl.text   = parts[1];
                          _updateMapMarkers();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats
                  Text("Today's impact", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard(icon: Icons.eco_rounded,      color: AppColors.green, value: '2.4 kg', label: 'CO₂ saved'),
                      const SizedBox(width: 12),
                      _StatCard(icon: Icons.route_rounded,    color: AppColors.teal,  value: '3',      label: 'Journeys'),
                      const SizedBox(width: 12),
                      _StatCard(icon: Icons.savings_rounded,  color: AppColors.amber, value: '₹340',   label: 'Saved vs cab'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search card with Places Autocomplete
// ─────────────────────────────────────────────────────────────────────────────
class _SearchCard extends StatefulWidget {
  final TextEditingController originCtrl;
  final TextEditingController destCtrl;
  final VoidCallback onSwap;
  final bool womensModeOn;
  final VoidCallback onSearch;
  final bool loading;
  final VoidCallback onLocationChanged;

  const _SearchCard({
    required this.originCtrl,
    required this.destCtrl,
    required this.onSwap,
    required this.womensModeOn,
    required this.onSearch,
    required this.loading,
    required this.onLocationChanged,
  });

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus   = FocusNode();

  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _isOriginActive  = false;
  Timer? _debounce;

  @override
  void dispose() {
    _originFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text, bool isOrigin) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (text.length < 2) {
        if (mounted) setState(() { _suggestions = []; _showSuggestions = false; });
        return;
      }
      final results = await PlacesService.autocomplete(text);
      if (mounted) {
        setState(() {
          _suggestions     = results;
          _showSuggestions = results.isNotEmpty;
          _isOriginActive  = isOrigin;
        });
      }
    });
  }

  void _onSuggestionTapped(PlaceSuggestion s) {
    final label = s.mainText;
    if (_isOriginActive) {
      widget.originCtrl.text = label;
    } else {
      widget.destCtrl.text = label;
    }
    setState(() { _suggestions = []; _showSuggestions = false; });
    widget.onLocationChanged();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // Origin field
              _LocationField(
                controller: widget.originCtrl,
                focusNode: _originFocus,
                hint: 'From',
                dotColor: AppColors.teal,
                onChanged: (v) => _onTextChanged(v, true),
                onFocusChange: (focused) {
                  if (focused) setState(() => _isOriginActive = true);
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Container(width: 1, height: 20, color: AppColors.lightGray),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        widget.onSwap();
                        setState(() { _suggestions = []; _showSuggestions = false; });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.offWhite,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.gray),
                      ),
                    ),
                  ],
                ),
              ),

              // Destination field
              _LocationField(
                controller: widget.destCtrl,
                focusNode: _destFocus,
                hint: 'To',
                dotColor: AppColors.red,
                onChanged: (v) => _onTextChanged(v, false),
                onFocusChange: (focused) {
                  if (focused) setState(() => _isOriginActive = false);
                },
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.loading ? null : widget.onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.womensModeOn ? AppColors.teal : AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: widget.loading
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.womensModeOn) ...[
                              const Icon(Icons.shield_rounded, size: 16),
                              const SizedBox(width: 6),
                            ],
                            const Text('Find Safe Routes'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),

        // ── Suggestions dropdown ──────────────────────────────────────────
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions.take(5).map((s) {
                return InkWell(
                  onTap: () => _onSuggestionTapped(s),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: AppColors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.mainText,
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy,
                                ),
                              ),
                              if (s.secondaryText.isNotEmpty)
                                Text(
                                  s.secondaryText,
                                  style: const TextStyle(fontSize: 12, color: AppColors.gray),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.north_west_rounded, size: 14, color: AppColors.gray),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single location text field
// ─────────────────────────────────────────────────────────────────────────────
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Color dotColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChange;

  const _LocationField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.dotColor,
    required this.onChanged,
    required this.onFocusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Focus(
            onFocusChange: onFocusChange,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.navy,
              ),
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: () { controller.clear(); onChanged(''); },
            child: const Icon(Icons.close_rounded, size: 16, color: AppColors.gray),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Existing helper widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _RecentSearchTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  const _RecentSearchTile({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.lightGray, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.history_rounded, size: 18, color: AppColors.gray),
      ),
      title: Text(query, style: const TextStyle(fontSize: 14, color: AppColors.navy)),
      trailing: const Icon(Icons.north_west_rounded, size: 14, color: AppColors.gray),
      onTap: onTap,
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray)),
          ],
        ),
      ),
    );
  }
}