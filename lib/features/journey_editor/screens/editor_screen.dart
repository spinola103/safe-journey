import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/journey_plan.dart';
import '../../../core/models/leg.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/swap_panel.dart';
import '../../../core/services/routing_service.dart';

class EditorScreen extends StatefulWidget {
  final JourneyPlan plan;
  const EditorScreen({super.key, required this.plan});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late JourneyPlan _current;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _current = widget.plan;
  }

  void _swapLeg(int index, Leg newLeg) {
    setState(() {
      _current = _current.swapLeg(index, newLeg);
      _hasChanges = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Switched to ${newLeg.modeLabel}${newLeg.routeLabel != null ? " · ${newLeg.routeLabel}" : ""}',
            ),
          ],
        ),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSwapPanel(int index) async {
    final currentLeg = _current.legs[index];

    final alternatives = await RoutingService.getAlternativesForLeg(currentLeg);
    final filteredAlternatives = alternatives
        .where((l) => l.mode != currentLeg.mode)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SwapPanel(
        currentLeg: _current.legs[index],
        alternatives: filteredAlternatives,
        onSelect: (newLeg) {
          Navigator.pop(context);
          _swapLeg(index, newLeg);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Route')),
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          if (_hasChanges)
            Container(
              width: double.infinity,
              color: AppColors.teal.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                '✏️ Route modified — tap Confirm to use changes',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // ── Summary bar ─────────────────────────────────────────────
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _SummaryChip(
                  icon: Icons.schedule_rounded,
                  value: _current.totalTimeLabel,
                ),
                const SizedBox(width: 16),
                _SummaryChip(
                  icon: Icons.currency_rupee_rounded,
                  value: _current.totalFare.toStringAsFixed(0),
                ),
                const SizedBox(width: 16),
                _SummaryChip(
                  icon: Icons.shield_rounded,
                  value: '${_current.avgSafetyScore.toStringAsFixed(0)}/100',
                  color: AppColors.safetyColor(_current.avgSafetyScore),
                ),
                const SizedBox(width: 16),
                _SummaryChip(
                  icon: Icons.eco_rounded,
                  value: '${_current.totalCo2Saved.toStringAsFixed(1)} kg',
                  color: AppColors.green,
                ),
              ],
            ),
          ),

          // ── Legs list ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _current.legs.length,
              itemBuilder: (_, i) => _LegEditorTile(
                leg: _current.legs[i],
                index: i,
                total: _current.legs.length,
                onSwapTap: () => _showSwapPanel(i),
              ),
            ),
          ),

          // ── Confirm button ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/journey', extra: _current),
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Confirm & Start Journey'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leg editor tile ───────────────────────────────────────────────────────
class _LegEditorTile extends StatelessWidget {
  final Leg leg;
  final int index;
  final int total;
  final VoidCallback onSwapTap;

  const _LegEditorTile({
    required this.leg,
    required this.index,
    required this.total,
    required this.onSwapTap,
  });

  @override
  Widget build(BuildContext context) {
    final modeColor = AppColors.modeColor(leg.mode);
    return Column(
      children: [
        // Stop name row
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: index == 0
                    ? AppColors.teal
                    : (index == total - 1 ? AppColors.red : modeColor),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              leg.startStop,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        // Leg card
        Padding(
          padding: const EdgeInsets.only(left: 4.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 1,
                height: 90,
                color: modeColor.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: modeColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(leg.modeEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leg.routeLabel != null
                                  ? '${leg.modeLabel} · ${leg.routeLabel}'
                                  : leg.modeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: modeColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${leg.durationMinutes} min  ·  ₹${leg.fare.toStringAsFixed(0)}  ·  Safety ${leg.safetyScore.toStringAsFixed(0)}/100',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Swap button
                      if (leg.mode != 'walk')
                        GestureDetector(
                          onTap: onSwapTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.offWhite,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.lightGray),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 14,
                                  color: AppColors.gray,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Swap',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray,
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
            ],
          ),
        ),
        // End stop (last leg only)
        if (index == total - 1)
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                leg.endStop,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _SummaryChip({
    required this.icon,
    required this.value,
    this.color = AppColors.tealMid,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
