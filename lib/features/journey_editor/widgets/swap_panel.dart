import 'package:flutter/material.dart';
import '../../../core/models/leg.dart';
import '../../../core/theme/app_theme.dart';

class SwapPanel extends StatelessWidget {
  final Leg currentLeg;
  final List<Leg> alternatives;
  final void Function(Leg) onSelect;

  const SwapPanel({
    super.key,
    required this.currentLeg,
    required this.alternatives,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.lightGray, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Swap this leg', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${currentLeg.startStop} → ${currentLeg.endStop}',
                  style: const TextStyle(color: AppColors.gray, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.lightGray, height: 1),
          const SizedBox(height: 8),

          // Current leg (dimmed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AltTile(
              leg: currentLeg,
              isCurrent: true,
              isRecommended: false,
              onTap: () => Navigator.pop(context),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text('ALTERNATIVES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.gray, letterSpacing: 1.2)),
          ),

          // Alternatives
          ...alternatives.map((alt) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _AltTile(
              leg: alt,
              isCurrent: false,
              isRecommended: alt.safetyScore >= 80,
              onTap: () => onSelect(alt),
            ),
          )),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ── Alternative tile ──────────────────────────────────────────────────────
class _AltTile extends StatelessWidget {
  final Leg leg;
  final bool isCurrent;
  final bool isRecommended;
  final VoidCallback onTap;

  const _AltTile({
    required this.leg, required this.isCurrent,
    required this.isRecommended, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modeColor = AppColors.modeColor(leg.mode);
    final safetyColor = AppColors.safetyColor(leg.safetyScore);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.offWhite : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppColors.lightGray : modeColor.withOpacity(0.3),
            width: isCurrent ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Mode icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.lightGray : modeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(leg.modeEmoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        leg.routeLabel?.replaceAll(' ★ Recommended in Women\'s Mode', '') ?? leg.modeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? AppColors.gray : modeColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRecommended && !isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Recommended',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Current',
                          style: TextStyle(color: AppColors.gray, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    _MiniStat(icon: Icons.schedule_rounded, value: '${leg.durationMinutes} min', color: AppColors.gray),
                    const SizedBox(width: 12),
                    _MiniStat(icon: Icons.currency_rupee_rounded, value: leg.fare.toStringAsFixed(0), color: AppColors.amber),
                    const SizedBox(width: 12),
                    _MiniStat(icon: Icons.shield_rounded,
                      value: '${leg.safetyScore.toStringAsFixed(0)}/100',
                      color: safetyColor),
                  ]),
                ],
              ),
            ),

            if (!isCurrent)
              const Icon(Icons.chevron_right_rounded, color: AppColors.gray, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(value, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ],
  );
}
