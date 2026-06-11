import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/demo_routes.dart';
import '../../../core/models/journey_plan.dart';

class GuardianScreen extends StatefulWidget {
  final String journeyId;
  const GuardianScreen({super.key, required this.journeyId});

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen>
    with SingleTickerProviderStateMixin {
  // Demo state — in production this comes from Firebase Realtime DB stream
  final JourneyPlan _plan = DemoRoutes.tambToTNagarFastest;
  int _verifiedLegs = 2;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  final List<_CheckpointEvent> _trail = [
    _CheckpointEvent(stop: 'Tambaram', time: '6:18 PM', mode: 'walk',  verified: true),
    _CheckpointEvent(stop: 'Tambaram Bus Stop', time: '6:22 PM', mode: 'bus', verified: true),
    _CheckpointEvent(stop: 'Guindy', time: '7:00 PM', mode: 'metro', verified: false),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lastVerified = _trail.lastWhere((e) => e.verified, orElse: () => _trail.first);
    final currentLeg = _plan.legs[_verifiedLegs.clamp(0, _plan.legs.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Guardian View'),
        actions: [
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Traveller status card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.teal.withOpacity(0.3),
                    child: const Text('P', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Priya', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('${_plan.origin} → ${_plan.destination}',
                        style: TextStyle(color: AppColors.tealMid, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call_rounded, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),

                // Current leg info
                Row(children: [
                  Text(currentLeg.modeEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Currently on: ${currentLeg.modeLabel}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        currentLeg.routeLabel != null
                          ? '${currentLeg.routeLabel} · → ${currentLeg.endStop}'
                          : '→ ${currentLeg.endStop}',
                        style: TextStyle(color: AppColors.tealMid, fontSize: 11)),
                    ],
                  ),
                ]),

                const SizedBox(height: 12),

                Row(children: [
                  _GuardianStat(icon: Icons.location_on_rounded, value: lastVerified.stop, label: 'Last confirmed'),
                  const SizedBox(width: 20),
                  _GuardianStat(icon: Icons.schedule_rounded, value: lastVerified.time, label: 'At'),
                  const SizedBox(width: 20),
                  _GuardianStat(icon: Icons.flag_rounded, value: 'ETA 7:15 PM', label: 'Expected'),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Status indicator ───────────────────────────────────────
          _StatusBanner(verifiedCount: _verifiedLegs, total: _plan.legs.length),

          const SizedBox(height: 20),

          // ── Checkpoint trail ──────────────────────────────────────
          const Text('Checkpoint Trail',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 12),

          ..._trail.map((e) => _TrailTile(event: e)),

          // Pending checkpoint
          _TrailTile(
            event: _CheckpointEvent(
              stop: 'Guindy Metro Station',
              time: 'Expected 7:03 PM',
              mode: 'metro',
              verified: false,
            ),
            isPending: true,
          ),

          const SizedBox(height: 20),

          // ── Journey legs ──────────────────────────────────────────
          const Text('Journey Plan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 12),

          ..._plan.legs.asMap().entries.map((e) {
            final i = e.key;
            final leg = e.value;
            final done = i < _verifiedLegs;
            return _PlanLegRow(leg: leg, done: done, isCurrent: i == _verifiedLegs);
          }),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final int verifiedCount;
  final int total;
  const _StatusBanner({required this.verifiedCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.teal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('On track — $verifiedCount of $total legs completed',
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
            Text('Last update: 6:22 PM · GPS auto-verified',
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
          ]),
        ),
      ]),
    );
  }
}

// ── Trail tile ────────────────────────────────────────────────────────────
class _TrailTile extends StatelessWidget {
  final _CheckpointEvent event;
  final bool isPending;
  const _TrailTile({required this.event, this.isPending = false});

  @override
  Widget build(BuildContext context) {
    final color = isPending ? AppColors.amber
        : (event.verified ? AppColors.teal : AppColors.gray);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(
              isPending ? Icons.schedule_rounded
                  : (event.verified ? Icons.check_rounded : Icons.radio_button_unchecked),
              size: 14, color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.stop,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isPending ? AppColors.amber : AppColors.navy)),
                Text(
                  isPending ? event.time : '${event.modeLabel} · ${event.time}',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray)),
              ],
            ),
          ),
          if (event.verified)
            const Text('GPS ✓', style: TextStyle(fontSize: 10, color: AppColors.teal, fontWeight: FontWeight.w600)),
          if (isPending)
            const Text('Awaiting...', style: TextStyle(fontSize: 10, color: AppColors.amber)),
        ],
      ),
    );
  }
}

class _PlanLegRow extends StatelessWidget {
  final dynamic leg;
  final bool done;
  final bool isCurrent;
  const _PlanLegRow({required this.leg, required this.done, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.teal : (isCurrent ? AppColors.amber : AppColors.gray);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          color: color, size: 18),
        const SizedBox(width: 10),
        Text(leg.modeEmoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${leg.startStop} → ${leg.endStop}',
            style: TextStyle(fontSize: 12, color: done ? AppColors.teal : AppColors.navy,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
        Text('${leg.durationMinutes} min', style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }
}

class _GuardianStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _GuardianStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 11, color: AppColors.tealMid),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppColors.tealMid, fontSize: 9, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ],
  );
}

class _CheckpointEvent {
  final String stop;
  final String time;
  final String mode;
  final bool verified;
  const _CheckpointEvent({required this.stop, required this.time, required this.mode, required this.verified});
  String get modeLabel => switch(mode) {
    'metro' => '🚇 Metro', 'bus' => '🚌 Bus', 'walk' => '🚶 Walk', _ => mode,
  };
}
