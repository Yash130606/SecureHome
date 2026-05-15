// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text.dart';

// ── STATUS BADGE (LIVE / OFFLINE) with animated dot ──────────────────────────
class StatusBadge extends StatefulWidget {
  final bool isOnline;
  const StatusBadge({super.key, required this.isOnline});

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? AppColors.online : AppColors.offline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _opacity,
          builder: (_, __) => Opacity(
            opacity: widget.isOnline ? _opacity.value : 1.0,
            child: Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(widget.isOnline ? 'LIVE' : 'OFFLINE', style: AppText.label(color: color, size: 9)),
      ]),
    );
  }
}

// ── RECORDING BADGE (REC) ─────────────────────────────────────────────────────
class RecordingBadge extends StatefulWidget {
  const RecordingBadge({super.key});

  @override
  State<RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<RecordingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _opacity,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(
                color: AppColors.accentRed, shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('REC', style: AppText.label(color: AppColors.accentRed, size: 9)),
      ]),
    );
  }
}

// ── ALERT TYPE BADGE ─────────────────────────────────────────────────────────
class AlertTypeBadge extends StatelessWidget {
  final String type;
  const AlertTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.alertTypeColor(type); // uses unified colour from AppColors
    final icon = _icon(type);
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  static IconData _icon(String type) {
    switch (type) {
      case 'person':    return Icons.person_outline;
      case 'motion':    return Icons.directions_run;
      case 'system':    return Icons.warning_amber_rounded;
      case 'recording': return Icons.videocam_outlined;
      default:          return Icons.notifications_outlined;
    }
  }
}

// ── COUNT BADGE ──────────────────────────────────────────────────────────────
class CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const CountBadge({super.key, required this.count, this.color = AppColors.accentRed});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
      child: Center(child: Text(label, style: AppText.label(color: Colors.white, size: 9))),
    );
  }
}

// ── BATTERY BADGE ─────────────────────────────────────────────────────────────
class BatteryBadge extends StatelessWidget {
  final int battery;
  const BatteryBadge({super.key, required this.battery});

  @override
  Widget build(BuildContext context) {
    final color = battery > 50
        ? AppColors.accentGreen
        : battery > 20
            ? AppColors.accentYellow
            : AppColors.accentRed;
    final icon = battery > 70
        ? Icons.battery_full
        : battery > 40
            ? Icons.battery_4_bar
            : battery > 15
                ? Icons.battery_2_bar
                : Icons.battery_alert;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 2),
        Text('$battery%', style: AppText.caption(color: color)),
      ]),
    );
  }
}

// ── SIGNAL BADGE ─────────────────────────────────────────────────────────────
class SignalBadge extends StatelessWidget {
  final int signal;
  const SignalBadge({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = signal > 70
        ? AppColors.accentGreen
        : signal > 30
            ? AppColors.accentYellow
            : AppColors.accentRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi, color: color, size: 11),
        const SizedBox(width: 2),
        Text('$signal%', style: AppText.caption(color: color)),
      ]),
    );
  }
}

// ── SEVERITY BADGE ────────────────────────────────────────────────────────────
class SeverityBadge extends StatelessWidget {
  final String severity;
  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(severity.toUpperCase(), style: AppText.overline(color: color)),
    );
  }
}
