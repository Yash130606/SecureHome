// lib/screens/alerts/alerts_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/status_badge.dart';
import 'notification_settings_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['All', 'Motion', 'Person', 'System'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(
        () => setState(() {})); // rebuild on tab switch so alerts list updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().refreshFromPi();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showClearAllSheet(AppProvider prov) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Clear All Alerts', style: AppText.h2()),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'This will permanently clear all alerts. This cannot be undone.',
                          style: AppText.bodyM(color: Colors.red))),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final ok = await prov.clearAllPiAlerts();
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'All alerts cleared'
                                : 'Could not clear alerts. Latest state restored.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Clear All',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: AppColors.border),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }

  String _monthName(int m) {
    const n = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return n[m];
  }

  @override
  Widget build(BuildContext context) {
    // ── Step 5: watch both providers ────────────────────────
    final prov = context.watch<AppProvider>();
    final unread = prov.unreadCount;
    final latestUnread = prov.latestUnreadAlert;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const Positioned.fill(child: _AlertsParticleBackground()),
        SafeArea(
          child: Column(children: [
            // ── HEADER ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Notifications & Alerts',
                      style: AppText.bodyM(color: AppColors.textMuted)),
                  Text('Alerts', style: AppText.h1()),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final ok = await prov.markAllPiAlertsRead();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'All alerts marked as read'
                              : 'Could not update all alerts. Latest state restored.',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border)),
                    child: Text('Mark all read',
                        style: AppText.bodyM(color: AppColors.textSecondary)
                            .copyWith(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: prov.piConnected ? prov.refreshFromPi : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.refresh_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen())),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.tune_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // ── SUMMARY STATS ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _AlertStatCard(
                    label: 'Unread',
                    value: '$unread',
                    icon: Icons.notifications_active_outlined,
                    color: unread > 0
                        ? AppColors.accentRed
                        : AppColors.accentGreen),
                const SizedBox(width: 10),
                _AlertStatCard(
                    label: 'Motion',
                    value: '${prov.alertCountByType('motion')}',
                    icon: Icons.directions_run,
                    color: AppColors.accentOrange),
                const SizedBox(width: 10),
                _AlertStatCard(
                    label: 'Person',
                    value: '${prov.alertCountByType('person')}',
                    icon: Icons.person_outlined,
                    color: AppColors.brand),
              ]),
            ),

            const SizedBox(height: 14),

            // ── STATUS BANNER ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: unread > 0
                      ? AppColors.accentRed.withOpacity(0.08)
                      : AppColors.accentGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: unread > 0
                          ? AppColors.accentRed.withOpacity(0.3)
                          : AppColors.accentGreen.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(
                      unread > 0
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: unread > 0
                          ? AppColors.accentRed
                          : AppColors.accentGreen,
                      size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unread > 0
                          ? '$unread unread alert${unread > 1 ? 's' : ''} need your attention'
                          : 'All caught up — no unread alerts',
                      style: AppText.bodyM(
                              color: unread > 0
                                  ? AppColors.accentRed
                                  : AppColors.accentGreen)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (unread > 0)
                    GestureDetector(
                      onTap: () => _showClearAllSheet(prov),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('Clear',
                            style: AppText.bodyS(color: Colors.red)),
                      ),
                    ),
                ]),
              ),
            ),

            if (latestUnread != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LatestAlertBanner(alert: latestUnread),
              ),
            ],

            const SizedBox(height: 14),

            // ── TAB BAR ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.brand.withOpacity(0.2),
                          blurRadius: 8)
                    ],
                  ),
                  labelStyle:
                      AppText.btn(color: Colors.white).copyWith(fontSize: 11),
                  unselectedLabelStyle:
                      AppText.bodyM(color: AppColors.textMuted)
                          .copyWith(fontWeight: FontWeight.w500, fontSize: 11),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  dividerColor: Colors.transparent,
                  labelPadding: EdgeInsets.zero,
                  padding: const EdgeInsets.all(4),
                  tabs: _tabs.map((t) {
                    // ── Step 5: count from alertSvc ──────────
                    final count = prov.alertsByType(t).length;
                    return Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t),
                          if (count > 0) ...[
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('$count',
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── ALERT LISTS ──────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: _tabs.map((tab) {
                  // ── Step 5: alerts from alertSvc.byType ─────
                  final alerts = prov.alertsByType(tab);

                  // Loading state: spinner while fetching and list is still empty
                  

                  // Empty state
                  if (alerts.isEmpty) return _EmptyAlertsState(tab: tab);

                  // Group alerts by day
                  final grouped = <String, List<dynamic>>{};
                  for (final a in alerts) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final yesterday = today.subtract(const Duration(days: 1));
                    final ts = a.timestamp as DateTime;
                    final alertDay = DateTime(ts.year, ts.month, ts.day);
                    String key;
                    if (alertDay == today) {
                      key = 'Today';
                    } else if (alertDay == yesterday) {
                      key = 'Yesterday';
                    } else {
                      key = '${ts.day} ${_monthName(ts.month)}';
                    }
                    grouped.putIfAbsent(key, () => []).add(a);
                  }

                  return ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _DayHeader(label: entry.key),
                        for (final alert in entry.value)
                          _SwipeableAlertCard(
                            alert: alert,
                            onTap: () => prov.markAlertRead(alert.id),
                            onDismiss: () async {
                              HapticFeedback.lightImpact();
                              await prov.dismissPiAlert(alert.id);
                            },
                            onMarkRead: () async {
                              HapticFeedback.selectionClick();
                              await prov.markAlertRead(alert.id);
                            },
                          ),
                      ],
                    ],
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// DAY HEADER
// ─────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Row(children: [
          Text(label,
              style: AppText.label(color: AppColors.textMuted, size: 11)),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Divider(height: 1, color: AppColors.border.withOpacity(0.6))),
        ]),
      );
}

// ─────────────────────────────────────────────
// SWIPEABLE ALERT CARD
// swipe right = mark read  |  swipe left = dismiss
// ─────────────────────────────────────────────

class _LatestAlertBanner extends StatelessWidget {
  final dynamic alert;
  const _LatestAlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(alert.severity as String);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_iconFor(alert.type as String), color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latest unread alert',
                  style: AppText.bodyS(color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(
                alert.title as String,
                style: AppText.bodyM().copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${alert.zone} • ${alert.time}',
                style: AppText.bodyS(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        SeverityBadge(severity: alert.severity as String),
      ]),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return Icons.person_outline;
      case 'motion':
        return Icons.directions_run;
      case 'system':
        return Icons.security_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}

class _SwipeableAlertCard extends StatelessWidget {
  final dynamic alert;
  final VoidCallback onTap, onDismiss, onMarkRead;
  const _SwipeableAlertCard(
      {required this.alert,
      required this.onTap,
      required this.onDismiss,
      required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentGreen.withOpacity(0.4)),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Icon(Icons.mark_email_read_outlined,
              color: AppColors.accentGreen, size: 22),
          const SizedBox(width: 8),
          Text('Mark read',
              style: AppText.bodyM(color: AppColors.accentGreen)
                  .copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentRed.withOpacity(0.4)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Spacer(),
          Text('Dismiss',
              style: AppText.bodyM(color: AppColors.accentRed)
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Icon(Icons.delete_outline,
              color: AppColors.accentRed, size: 22),
        ]),
      ),
      confirmDismiss: (dir) async {
        return dir == DismissDirection.endToStart;
      },
      onDismissed: (dir) {
        onDismiss();
      },
      child: _AlertCard(alert: alert, onTap: onTap),
    );
  }
}

// ─────────────────────────────────────────────
// ALERT CARD
// ─────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final dynamic alert;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.onTap});

  Color get _typeColor => AppColors.alertTypeColor(alert.type as String);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: alert.isRead ? AppColors.bgSurface : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  alert.isRead ? AppColors.border : _typeColor.withOpacity(0.4),
              width: alert.isRead ? 1 : 1.5),
          boxShadow: alert.isRead
              ? []
              : [
                  BoxShadow(
                      color: _typeColor.withOpacity(0.08),
                      blurRadius: 12,
                      spreadRadius: 1)
                ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AlertTypeBadge(type: alert.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(alert.title,
                              style: AppText.bodyM(color: AppColors.textPrimary)
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (!alert.isRead)
                          Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  color: _typeColor, shape: BoxShape.circle)),
                      ]),
                      const SizedBox(height: 3),
                      Text(alert.subtitle,
                          style: AppText.bodyS(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _MetaChip(
                              icon: Icons.videocam_outlined,
                              label: alert.camera),
                          _MetaChip(
                              icon: Icons.access_time_rounded,
                              label: alert.time),
                          if ((alert.zone as String).isNotEmpty &&
                              alert.zone != 'Unknown')
                            _MetaChip(
                                icon: Icons.location_on_outlined,
                                label: alert.zone),
                          SeverityBadge(severity: alert.severity),
                        ],
                      ),
                      if (alert.hasThumb) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(alert.thumb!,
                                width: 80,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    width: 80,
                                    height: 56,
                                    color: AppColors.bgSurface)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: onTap,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _typeColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _typeColor.withOpacity(0.2)),
                                ),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_circle_outline_rounded,
                                          color: _typeColor, size: 16),
                                      const SizedBox(width: 6),
                                      Text('View clip',
                                          style:
                                              AppText.bodyS(color: _typeColor)),
                                    ]),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ]),
              ),
            ]),
          ),
          if (!alert.isRead)
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _typeColor.withOpacity(0.6),
                  _typeColor.withOpacity(0.0)
                ]),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.textMuted, size: 11),
        const SizedBox(width: 3),
        Text(label, style: AppText.bodyS()),
      ]);
}

class _EmptyAlertsState extends StatelessWidget {
  final String tab;
  const _EmptyAlertsState({required this.tab});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textMuted, size: 30),
          ),
          const SizedBox(height: 14),
          Text('No $tab alerts',
              style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              tab == 'All'
                  ? 'You\'re all clear — no alerts at this time'
                  : '$tab events will appear here when detected',
              style: AppText.bodyS(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ]),
      );
}

class _AlertStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AlertStatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: AppText.h2().copyWith(fontSize: 16)),
              Text(label, style: AppText.bodyS(color: AppColors.textMuted)),
            ]),
          ]),
        ),
      );
}

// ─── Particle Background ───────────────────────────────────────────────────

class _AlertsParticleBackground extends StatefulWidget {
  const _AlertsParticleBackground();
  @override
  State<_AlertsParticleBackground> createState() =>
      _AlertsParticleBackgroundState();
}

class _AlertsParticleBackgroundState extends State<_AlertsParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
            painter: _AlertsParticlePainter(_ctrl.value), size: Size.infinite),
      );
}

class _AlertsParticlePainter extends CustomPainter {
  final double progress;
  _AlertsParticlePainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()
      ..color = AppColors.brand.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 50)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    for (double y = 0; y < size.height; y += 50)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    final pp = Paint()..color = AppColors.brand.withOpacity(0.45);
    final rng = Random(13);
    for (int i = 0; i < 50; i++) {
      final x = rng.nextDouble() * size.width;
      final y =
          ((rng.nextDouble() * size.height) + progress * 120) % size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 2.0 + 0.8, pp);
    }
  }

  @override
  bool shouldRepaint(_AlertsParticlePainter o) => o.progress != progress;
}
