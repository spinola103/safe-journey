import 'package:flutter/material.dart';
import '../../../core/models/journey_plan.dart';
import '../../../core/models/leg.dart';
import '../../../core/theme/app_theme.dart';

class RouteCard extends StatelessWidget {
  final JourneyPlan plan;
  final String label;
  final Color labelColor;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onStartJourney;
  final VoidCallback onEditRoute; // ← ADD THIS LINE

  const RouteCard({
    super.key,
    required this.plan,
    required this.label,
    required this.labelColor,
    required this.onTap,
    required this.onStartJourney,
    required this.onEditRoute, // ← ADD THIS LINE
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? labelColor : AppColors.lightGray,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? labelColor.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: labelColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                border: Border(
                  bottom: BorderSide(color: labelColor.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: labelColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _SafetyBadge(score: plan.avgSafetyScore),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats row ─────────────────────────────────────────
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.schedule_rounded,
                        value: plan.totalTimeLabel,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.currency_rupee_rounded,
                        value: plan.totalFare.toStringAsFixed(0),
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.eco_rounded,
                        value:
                            '${plan.totalCo2Saved.toStringAsFixed(1)} kg CO₂',
                        color: AppColors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Leg journey visual ────────────────────────────────
                  _LegJourneyView(legs: plan.legs),
                  const SizedBox(height: 16),

                  // ── Actions ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              onEditRoute, // ← CHANGE onTap → onEditRoute
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit route'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.lightGray),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onStartJourney,
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const Text('Start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: labelColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leg journey visual ────────────────────────────────────────────────────────
class _LegJourneyView extends StatelessWidget {
  final List<Leg> legs;
  const _LegJourneyView({required this.legs});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final modeColor = AppColors.modeColor(leg.mode);

      // Stop name
      items.add(
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: modeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                leg.startStop,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.gray,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

      // Leg connector with coloured line
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: 3.5),
          child: Row(
            children: [
              Container(
                width: 1,
                height: 38,
                color: modeColor.withOpacity(0.35),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: modeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: modeColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(leg.modeEmoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      leg.routeLabel != null
                          ? '${leg.modeLabel} · ${leg.routeLabel}'
                          : leg.modeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: modeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${leg.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 11,
                        color: modeColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Final stop
      if (i == legs.length - 1) {
        items.add(
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leg.endStop,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (w) => Padding(padding: const EdgeInsets.only(bottom: 2), child: w),
          )
          .toList(),
    );
  }
}

// ── Safety badge ──────────────────────────────────────────────────────────────
class _SafetyBadge extends StatelessWidget {
  final double score;
  const _SafetyBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.safetyColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(0)}/100',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
