import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/status_badge.dart';
import '../camera/live_view_screen.dart';
import '../../widgets/pi_thumbnail.dart';

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class _ActivityEvent {
  final String title;
  final String zone;
  final String timeAgo;
  final IconData icon;
  final Color color;

  const _ActivityEvent({
    required this.title,
    required this.zone,
    required this.timeAgo,
    required this.icon,
    required this.color,
  });
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _controlBusy = false;
  // FIX: arm state removed from local — lives in AppProvider.armState
  // Activity feed now driven by prov.alerts (no hardcoded _events list)

  // 24h activity dots (simulated — 1 = event, 0 = quiet)
  final List<int> _activityTimeline = const [
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    0,
    1,
    1,
    0,
    1,
    0,
    0,
  ];

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    if (h < 21) return "Good Evening";
    return "Good Night";
  }

  String _systemStateLabel(AppProvider prov) {
    if (!prov.piConnected) return "Pi Offline";
    if (!prov.piRunning) return "Detection Stopped";
    switch (prov.armState) {
      case SystemArmState.armed:
        return "System Armed";
      case SystemArmState.alert:
        return "⚠ Alert Active";
      case SystemArmState.lockdown:
        return "System Locked";
      case SystemArmState.night:
        return "Night Mode On";
      case SystemArmState.disarmed:
        return "System Disarmed";
    }
  }

  Color _systemStateColor(AppProvider prov) {
    if (!prov.piConnected) return AppColors.accentRed;
    if (!prov.piRunning) return AppColors.accentYellow;
    switch (prov.armState) {
      case SystemArmState.alert:
        return Colors.red;
      case SystemArmState.armed:
        return AppColors.accentGreen;
      case SystemArmState.lockdown:
        return Colors.grey;
      case SystemArmState.night:
        return Colors.blue;
      case SystemArmState.disarmed:
        return AppColors.accentYellow;
    }
  }

  IconData _systemStateIcon(AppProvider prov) {
    if (!prov.piConnected) return Icons.wifi_off_rounded;
    if (!prov.piRunning) return Icons.pause_circle_outline;
    switch (prov.armState) {
      case SystemArmState.alert:
        return Icons.warning_amber_rounded;
      case SystemArmState.armed:
        return Icons.shield;
      case SystemArmState.lockdown:
        return Icons.lock;
      case SystemArmState.night:
        return Icons.nightlight_round;
      case SystemArmState.disarmed:
        return Icons.shield_outlined;
    }
  }

  String _armedTimestamp(AppProvider prov) {
    if (!prov.piConnected) return "Reconnect to your Raspberry Pi to resume monitoring";
    if (!prov.piRunning) return "Start detection from the app to monitor your home";
    if (prov.armedAt == null) return "";
    final diff = DateTime.now().difference(prov.armedAt!);
    if (diff.inMinutes < 1) return "Armed just now";
    if (diff.inMinutes < 60) return "Armed ${diff.inMinutes}m ago";
    return "Armed ${diff.inHours}h ago";
  }

  bool _isOn(AppProvider prov, String action) {
    switch (action) {
      case 'arm':
        return prov.armState == SystemArmState.armed;
      case 'night':
        return prov.armState == SystemArmState.night;
      case 'alert':
        return prov.armState == SystemArmState.alert;
      case 'lock':
        return prov.armState == SystemArmState.lockdown;
    }
    return false;
  }

  bool _piReady(AppProvider prov) => prov.piConnected && prov.piRunning;

  Future<bool> _runControlAction(
    Future<bool> Function() action, {
    required String successMessage,
    required String failureMessage,
  }) async {
    if (_controlBusy) return false;

    setState(() => _controlBusy = true);
    try {
      final ok = await action();
      if (!mounted) return ok;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? successMessage : failureMessage),
          backgroundColor: ok ? AppColors.accentGreen : AppColors.accentRed,
        ),
      );
      return ok;
    } finally {
      if (mounted) {
        setState(() => _controlBusy = false);
      }
    }
  }

  void _requirePiReady(BuildContext context, AppProvider prov, VoidCallback action) {
    if (_controlBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the current action to finish.')),
      );
      return;
    }
    if (!_piReady(prov)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prov.piConnected
                ? 'Start the detection engine first.'
                : 'Connect to your Raspberry Pi first.',
          ),
        ),
      );
      return;
    }
    action();
  }

  void _requirePiConnected(
      BuildContext context, AppProvider prov, VoidCallback action) {
    if (_controlBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the current action to finish.')),
      );
      return;
    }
    if (!prov.piConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to your Raspberry Pi first.')),
      );
      return;
    }
    action();
  }

  void _handleAction({
    required String title,
    required bool isOn,
    required Color color,
    required IconData icon,
    required List<String> enablePoints,
    required String disableTitle,
    required List<String> disablePoints,
    required Future<bool> Function() onEnable,
    required Future<bool> Function() onDisable,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: AppText.h2()),
                ],
              ),
              const SizedBox(height: 16),
              if (!isOn) ...[
                ...enablePoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(point, style: AppText.bodyM())),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(disableTitle,
                            style: AppText.bodyM(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...disablePoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.remove_circle_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(point, style: AppText.bodyM())),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOn ? Colors.red : color,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        if (isOn) {
                          await onDisable();
                        } else {
                          await onEnable();
                        }
                      },
                      child: Text(
                        isOn ? "Turn OFF" : "Turn ON",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.border),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshHomeStatus(AppProvider prov) async {
    await prov.refreshFromPi();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Home status refreshed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final cameras = prov.cameras;

    // Group cameras by zone
    final Map<String, List<dynamic>> zoneMap = {};
    for (final cam in cameras) {
      zoneMap.putIfAbsent(cam.zone as String, () => []).add(cam);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          /// PARTICLE BACKGROUND
          const Positioned.fill(child: _HomeParticleBackground()),

          /// CONTENT
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _refreshHomeStatus(prov),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting,
                                style:
                                    AppText.bodyM(color: AppColors.textMuted)),
                            Text("SecureHome", style: AppText.h1()),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => prov.setNav(3), // navigate to Alerts tab
                          child: Stack(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (prov.unreadCount > 0)
                                Positioned(
                                  right: -3,
                                  top: -3,
                                  child: CountBadge(count: prov.unreadCount),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _controlBusy
                              ? null
                              : () => _refreshHomeStatus(prov),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.refresh_rounded,
                              color: _controlBusy
                                  ? AppColors.textMuted
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── PERSISTENT SYSTEM STATE BANNER ──────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _systemStateColor(prov).withOpacity(0.18),
                            AppColors.bgSurface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _systemStateColor(prov).withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _systemStateColor(prov).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_systemStateIcon(prov),
                                color: _systemStateColor(prov)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _systemStateLabel(prov),
                                  style: AppText.bodyM(
                                          color: AppColors.textPrimary)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  !prov.piConnected || !prov.piRunning
                                      ? _armedTimestamp(prov)
                                      : prov.isArmed && prov.armedAt != null
                                          ? _armedTimestamp(prov)
                                          : "All cameras operating normally",
                                  style: AppText.bodyS(
                                      color: _systemStateColor(prov)
                                          .withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                          // Runtime status indicator
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                prov.piConnected
                                    ? Icons.router_outlined
                                    : Icons.wifi_off_rounded,
                                color: prov.piConnected
                                    ? AppColors.accentGreen
                                    : AppColors.accentRed,
                                size: 16,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prov.piConnected ? "Pi Online" : "Pi Offline",
                                style: AppText.bodyS(
                                  color: prov.piConnected
                                      ? AppColors.accentGreen
                                      : AppColors.accentRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── CAMERA HEALTH WARNING BANNER ─────────
                  if (prov.offlineCount > 0 || prov.lowBatteryCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: GestureDetector(
                        onTap: () => prov.setNav(1), // go to cameras tab
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.accentYellow.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.accentYellow.withOpacity(0.35)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.accentYellow, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                [
                                  if (prov.offlineCount > 0)
                                    '${prov.offlineCount} camera${prov.offlineCount > 1 ? 's' : ''} offline',
                                  if (prov.lowBatteryCount > 0)
                                    '${prov.lowBatteryCount} low battery',
                                ].join(' | '),
                                style: AppText.bodyS(
                                    color: AppColors.accentYellow),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.accentYellow, size: 16),
                          ]),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ── QUICK ACTIONS ────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _QuickAction(
                          icon: Icons.security,
                          title: "Arm",
                          subtitle: _piReady(prov)
                              ? "Activate Security"
                              : "Pi status required",
                          active: _piReady(prov) && _isOn(prov, 'arm'),
                          color: Colors.green,
                          onTap: () => _requirePiReady(
                            context,
                            prov,
                            () => _handleAction(
                              title: "ARM SECURITY",
                              isOn: _isOn(prov, 'arm'),
                              color: Colors.green,
                              icon: Icons.security,
                              enablePoints: [
                                "Motion detection enabled",
                                "Cameras start recording on motion",
                                "Intrusion alerts enabled",
                                "Notifications sent to phone",
                                "AI detection active",
                              ],
                              disableTitle:
                                  "System already active. Turning off will:",
                              disablePoints: [
                                "Disable motion detection",
                                "Stop camera alerts",
                                "Disable AI monitoring",
                                "Turn off intrusion notifications",
                              ],
                              onEnable: () => _runControlAction(
                                context.read<AppProvider>().togglePiArm,
                                successMessage: 'Security system armed',
                                failureMessage: 'Failed to arm the system',
                              ),
                              onDisable: () => _runControlAction(
                                context.read<AppProvider>().togglePiArm,
                                successMessage: 'Security system disarmed',
                                failureMessage: 'Failed to disarm the system',
                              ),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: Icons.nightlight_round,
                          title: "Night",
                          subtitle: _piReady(prov)
                              ? "Night Surveillance"
                              : "Pi status required",
                          active: _piReady(prov) && _isOn(prov, 'night'),
                          color: Colors.blue,
                          onTap: () => _requirePiReady(
                            context,
                            prov,
                            () => _handleAction(
                              title: "NIGHT MODE",
                              isOn: _isOn(prov, 'night'),
                              color: Colors.blue,
                              icon: Icons.nightlight_round,
                              enablePoints: [
                                "Enable night vision cameras",
                                "Reduce false motion alerts",
                                "Activate outdoor cameras only",
                                "Dim UI for comfortable night viewing",
                              ],
                              disableTitle:
                                  "Night mode is active. Turning off will:",
                              disablePoints: [
                                "Disable night vision mode",
                                "Switch back to standard camera view",
                                "Restore full UI brightness",
                                "Reactivate all indoor cameras",
                              ],
                              onEnable: () => _runControlAction(
                                context.read<AppProvider>().togglePiNightMode,
                                successMessage: 'Night mode enabled',
                                failureMessage: 'Failed to enable night mode',
                              ),
                              onDisable: () => _runControlAction(
                                context.read<AppProvider>().togglePiNightMode,
                                successMessage: 'Night mode disabled',
                                failureMessage: 'Failed to disable night mode',
                              ),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: Icons.memory_rounded,
                          title: "Detect",
                          subtitle: prov.piConnected
                              ? (prov.piRunning
                                  ? "Engine Running"
                                  : "Start Detection")
                              : "Pi connection required",
                          active: prov.piConnected && prov.piRunning,
                          color: AppColors.brand,
                          onTap: () => _requirePiConnected(
                            context,
                            prov,
                            () => _handleAction(
                              title: "DETECTION ENGINE",
                              isOn: prov.piRunning,
                              color: AppColors.brand,
                              icon: Icons.memory_rounded,
                              enablePoints: [
                                "Start the Pi detection engine",
                                "Enable live camera processing",
                                "Allow real-time alerts and AI events",
                                "Unlock arm and night controls",
                              ],
                              disableTitle:
                                  "Detection is active. Turning it off will:",
                              disablePoints: [
                                "Stop live Pi frame processing",
                                "Pause real-time alert generation",
                                "Disable arm and night controls until restarted",
                                "Hide the live feed until detection restarts",
                              ],
                              onEnable: () => _runControlAction(
                                context.read<AppProvider>().startPiDetection,
                                successMessage: 'Detection engine started',
                                failureMessage:
                                    'Failed to start the detection engine',
                              ),
                              onDisable: () => _runControlAction(
                                context.read<AppProvider>().stopPiDetection,
                                successMessage: 'Detection engine stopped',
                                failureMessage:
                                    'Failed to stop the detection engine',
                              ),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: Icons.lock_outline,
                          title: "Lock",
                          subtitle: "Lock System",
                          active: _isOn(prov, 'lock'),
                          color: Colors.grey,
                          onTap: () => _handleAction(
                            title: "SYSTEM LOCK",
                            isOn: _isOn(prov, 'lock'),
                            color: Colors.grey,
                            icon: Icons.lock_outline,
                            enablePoints: [
                              "Lock all connected doors",
                              "Secure and freeze camera settings",
                              "Enable full perimeter surveillance",
                              "Require authentication to make changes",
                            ],
                            disableTitle: "System is locked. Turning off will:",
                            disablePoints: [
                              "Unlock doors and access points",
                              "Allow camera setting changes",
                              "Disable lock authentication requirement",
                              "Return system to standard access mode",
                            ],
                            onEnable: () async {
                              context
                                  .read<AppProvider>()
                                  .setArmState(SystemArmState.lockdown);
                              return true;
                            },
                            onDisable: () async {
                              context
                                  .read<AppProvider>()
                                  .setArmState(SystemArmState.disarmed);
                              return true;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── STATS ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: "Online",
                            value: "${prov.onlineCount}",
                            icon: Icons.videocam,
                            color: AppColors.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: "Alerts",
                            value: "${prov.unreadCount}",
                            icon: Icons.notifications,
                            color: AppColors.accentYellow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: "Cameras",
                            value: "${cameras.length}",
                            icon: Icons.camera_alt,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── 24H ACTIVITY TIMELINE ────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("24h Activity", style: AppText.h2()),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${_activityTimeline.where((e) => e == 1).length} events",
                                style: AppText.bodyS(color: AppColors.brand),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(24, (i) {
                                  final hasEvent = _activityTimeline[i] == 1;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 1.5),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        height: hasEvent ? 28 : 12,
                                        decoration: BoxDecoration(
                                          color: hasEvent
                                              ? AppColors.brand
                                              : AppColors.brand
                                                  .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text("12AM",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                  Text("6AM",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                  Text("12PM",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                  Text("6PM",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                  Text("Now",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── PANIC / SOS BUTTON ───────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        context
                            .read<AppProvider>()
                            .setArmState(SystemArmState.alert);
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.12),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.sos_outlined,
                                        color: Colors.red, size: 40),
                                  ),
                                  const SizedBox(height: 14),
                                  Text('Emergency Alert Triggered',
                                      style: AppText.h2()),
                                  const SizedBox(height: 8),
                                  Text(
                                      'All cameras are recording. Emergency contacts notified.',
                                      style: AppText.bodyM(),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      context
                                          .read<AppProvider>()
                                          .setArmState(SystemArmState.disarmed);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Cancel Emergency',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16)),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Dismiss',
                                        style: AppText.bodyM(
                                            color: AppColors.textMuted)),
                                  ),
                                ]),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF3D5A), Color(0xFFFF1744)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6))
                          ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sos_outlined,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text('PANIC / SOS',
                                  style: AppText.btn(color: Colors.white)
                                      .copyWith(letterSpacing: 1.5)),
                            ]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── QUICK SNAPSHOT ROW ───────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text("Live Snapshots", style: AppText.h2()),
                        const Spacer(),
                        Text("View All",
                            style: AppText.bodyM(color: AppColors.brand)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: cameras.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final cam = cameras[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveViewScreen(camera: cam),
                            ),
                          ),
                          child: Container(
                            width: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: cam.id == 'pi_cam'
                                      ? PiThumbnail(
                                          width: 160,
                                          height: 110,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        )
                                      : Image.network(
                                          cam.thumb,
                                          width: 160,
                                          height: 110,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                // Dark overlay
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                // LIVE badge
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cam.isOn
                                          ? const Color(0xFFD32F2F)
                                          : const Color(0xFF616161),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cam.isOn ? "LIVE" : "OFF",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                // Camera name
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  right: 6,
                                  child: Text(
                                    cam.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── ZONE OVERVIEW ────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text("Zones", style: AppText.h2()),
                        const Spacer(),
                        Text(
                          "${zoneMap.length} zones",
                          style: AppText.bodyM(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: zoneMap.entries.map((entry) {
                        final zoneName = entry.key;
                        final zoneCams = entry.value;
                        final onlineInZone =
                            zoneCams.where((c) => c.isOn).length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ZoneCard(
                            zoneName: zoneName,
                            total: zoneCams.length,
                            online: onlineInZone,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── CAMERA HEADER ────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text("Cameras", style: AppText.h2()),
                        const Spacer(),
                        Text("View All",
                            style: AppText.bodyM(color: AppColors.brand)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── CAMERA LIST ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: cameras.map((cam) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _CameraLargeCard(
                            camera: cam,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveViewScreen(camera: cam),
                              ),
                            ),
                            onToggle: (v) => prov.toggleCamera(cam.id, v),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── RECENT ACTIVITY FEED ─────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text("Recent Activity", style: AppText.h2()),
                        const Spacer(),
                        Text("See All",
                            style: AppText.bodyM(color: AppColors.brand)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: prov.alerts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text('No recent activity',
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
                              ),
                            )
                          : Column(
                              children: List.generate(
                                prov.alerts.take(5).length,
                                (i) {
                                  final alert = prov.alerts.take(5).toList()[i];
                                  final isLast =
                                      i == prov.alerts.take(5).length - 1;
                                  // Derive icon and colour from alert type
                                  final Color alertColor =
                                      AppColors.alertTypeColor(alert.type);
                                  final IconData alertIcon =
                                      alert.type == 'person'
                                          ? Icons.person
                                          : alert.type == 'motion'
                                              ? Icons.directions_run
                                              : alert.type == 'system'
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.cloud_done;
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: alertColor
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(alertIcon,
                                                  color: alertColor, size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    alert.title,
                                                    style: AppText.bodyM()
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .videocam_outlined,
                                                          size: 12,
                                                          color: Colors.grey),
                                                      const SizedBox(width: 3),
                                                      Text(alert.camera,
                                                          style: AppText.bodyS(
                                                              color: AppColors
                                                                  .textMuted)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              alert.time,
                                              style: AppText.bodyS(
                                                  color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          color: AppColors.border,
                                          indent: 62,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          )
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ZONE CARD
// ─────────────────────────────────────────────

class _ZoneCard extends StatelessWidget {
  final String zoneName;
  final int total;
  final int online;

  const _ZoneCard({
    required this.zoneName,
    required this.total,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final bool allOnline = online == total;
    final statusColor =
        allOnline ? AppColors.accentGreen : AppColors.accentYellow;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zoneName,
                  style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  "$online / $total cameras online",
                  style: AppText.bodyS(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Mini status bar
          Row(
            children: List.generate(total, (i) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < online ? AppColors.accentGreen : AppColors.border,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PARTICLE BACKGROUND
// ─────────────────────────────────────────────

class _HomeParticleBackground extends StatefulWidget {
  const _HomeParticleBackground();

  @override
  State<_HomeParticleBackground> createState() =>
      _HomeParticleBackgroundState();
}

class _HomeParticleBackgroundState extends State<_HomeParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _HomeParticlePainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _HomeParticlePainter extends CustomPainter {
  final double progress;
  _HomeParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.brand.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final particlePaint = Paint()..color = AppColors.brand.withOpacity(0.5);
    final random = Random(42);

    for (int i = 0; i < 55; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          ((random.nextDouble() * size.height) + progress * 120) % size.height;
      final radius = random.nextDouble() * 2.2 + 0.8;
      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_HomeParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────
// CAMERA LARGE CARD
// ─────────────────────────────────────────────

class _CameraLargeCard extends StatefulWidget {
  final dynamic camera;
  final VoidCallback onTap;
  final Function(bool) onToggle;

  const _CameraLargeCard({
    required this.camera,
    required this.onTap,
    required this.onToggle,
  });

  @override
  State<_CameraLargeCard> createState() => _CameraLargeCardState();
}

class _CameraLargeCardState extends State<_CameraLargeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  String status = "";

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> handleToggle(bool value) async {
    setState(() => status = value ? "CONNECTING..." : "DISCONNECTING...");
    await Future.delayed(const Duration(milliseconds: 300));
    widget.onToggle(value);
    setState(() => status = "");
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final bool online = camera.isOn;
    final String displayStatus =
        status.isNotEmpty ? status : (online ? "LIVE" : "OFFLINE");

    Color statusColor;
    if (status.contains("CONNECT")) {
      statusColor = const Color(0xFFFF8C00);
    } else if (online) {
      statusColor = const Color(0xFFD32F2F);
    } else {
      statusColor = const Color(0xFF616161);
    }

    final int wifiStrength = camera.signal ?? 82;
    final int battery = camera.battery ?? 87;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        color: AppColors.bgSurface,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(camera.thumb, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          /// STATUS BADGE
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _blinkAnimation,
                    builder: (_, __) => Opacity(
                      opacity: (displayStatus == "LIVE" ||
                              displayStatus.contains("CONNECT"))
                          ? _blinkAnimation.value
                          : 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: displayStatus == "OFFLINE"
                              ? []
                              : [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(displayStatus,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          /// WIFI + BATTERY top right
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.battery_full,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text("$battery%",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text("$wifiStrength%",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// BOTTOM INFO
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(camera.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(camera.zone,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: camera.isOn,
                            onChanged: handleToggle,
                            activeColor: AppColors.brand,
                            activeTrackColor: AppColors.brand.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          camera.isOn ? "Camera ON" : "Camera OFF",
                          style: TextStyle(
                              color: camera.isOn ? Colors.green : Colors.grey,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text("View Camera",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUICK ACTION CARD
// ─────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : AppColors.border,
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? color : AppColors.brand),
            const Spacer(),
            Text(title,
                style: AppText.bodyM().copyWith(fontWeight: FontWeight.bold)),
            Text(subtitle, style: AppText.bodyS(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppText.h2()),
          Text(label, style: AppText.bodyS()),
        ],
      ),
    );
  }
}
