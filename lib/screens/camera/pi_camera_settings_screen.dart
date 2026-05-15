import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pi_service.dart';
import '../../widgets/settings_row.dart';
import '../../widgets/status_badge.dart';

class PiCameraSettingsScreen extends StatefulWidget {
  const PiCameraSettingsScreen({super.key});

  @override
  State<PiCameraSettingsScreen> createState() => _PiCameraSettingsScreenState();
}

class _PiCameraSettingsScreenState extends State<PiCameraSettingsScreen> {
  bool _busy = false;

  Future<void> _runAction(
    Future<bool> Function() action,
    String successMessage,
    String failureMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? successMessage : failureMessage),
          backgroundColor: ok ? AppColors.accentGreen : AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyToClipboard(String value, String label) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  String _sensitivityLabel(int value) {
    if (value <= 35) return 'Low';
    if (value >= 70) return 'High';
    return 'Balanced';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final ip = auth.piIpAddress ?? '';
    final canManageProtection = app.piConnected && app.piRunning && !_busy;
    final canManageDetection = app.piConnected && !_busy;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Pi Camera', style: AppText.h3()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          StatusBadge(isOnline: app.piConnected),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: app.piConnected
                            ? AppColors.brand.withOpacity(0.14)
                            : AppColors.accentRed.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        app.piConnected ? Icons.router_outlined : Icons.wifi_off,
                        color: app.piConnected
                            ? AppColors.brand
                            : AppColors.accentRed,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Raspberry Pi Controller', style: AppText.h3()),
                          const SizedBox(height: 4),
                          Text(
                            app.piConnected
                                ? 'Connected and ready for live monitoring.'
                                : 'Offline. Reconnect from the setup screen or settings.',
                            style: AppText.bodyS(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SummaryPill(
                      label: 'Detection',
                      value: app.piRunning ? 'Running' : 'Stopped',
                      color: app.piRunning
                          ? AppColors.accentGreen
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    _SummaryPill(
                      label: 'Arm State',
                      value: app.piNightMode
                          ? 'Night'
                          : app.piArmed
                              ? 'Armed'
                              : 'Disarmed',
                      color: app.piNightMode
                          ? Colors.blue
                          : app.piArmed
                              ? AppColors.brand
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    _SummaryPill(
                      label: 'Unknowns',
                      value: '${app.piUnknowns}',
                      color: app.piUnknowns > 0
                          ? AppColors.accentRed
                          : AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingSection(
            title: 'System Control',
            children: [
              SettingSwitchRow(
                label: 'Arm Security System',
                subtitle: 'Enable person and intrusion detection on the Pi.',
                icon: Icons.security_outlined,
                value: app.piArmed,
                onChanged: canManageProtection
                    ? (_) => _runAction(
                          app.togglePiArm,
                          app.piArmed
                              ? 'System disarmed successfully'
                              : 'System armed successfully',
                          app.piArmed
                              ? 'Failed to disarm the system'
                              : 'Failed to arm the system',
                        )
                    : (_) {},
              ),
              SettingSwitchRow(
                label: 'Night Mode',
                subtitle: 'Use night behavior and faster loitering alerts.',
                icon: Icons.nightlight_round,
                value: app.piNightMode,
                onChanged: canManageProtection
                    ? (_) => _runAction(
                          app.togglePiNightMode,
                          app.piNightMode
                              ? 'Night mode disabled'
                              : 'Night mode enabled',
                          app.piNightMode
                              ? 'Failed to disable night mode'
                              : 'Failed to enable night mode',
                        )
                    : (_) {},
              ),
              SettingSwitchRow(
                label: 'Detection Engine',
                subtitle: 'Start or stop the Pi detection process.',
                icon: Icons.memory_outlined,
                value: app.piRunning,
                onChanged: canManageDetection
                    ? (_) => _runAction(
                          app.piRunning
                              ? app.stopPiDetection
                              : app.startPiDetection,
                          app.piRunning
                              ? 'Detection stopped'
                              : 'Detection started',
                          app.piRunning
                              ? 'Failed to stop detection'
                              : 'Failed to start detection',
                        )
                    : (_) {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (app.piConnected && !app.piRunning)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accentYellow.withOpacity(0.22),
                ),
              ),
              child: Text(
                'Start the detection engine before arming the system or enabling night mode.',
                style: AppText.bodyS(color: AppColors.accentYellow),
              ),
            ),
          SettingSection(
            title: 'Detection Tuning',
            children: [
              SettingSliderRow(
                label: 'Sensitivity',
                subtitle:
                    'Higher sensitivity lowers the confidence threshold and speeds up loiter alerts.',
                icon: Icons.tune,
                value: app.piSensitivity.toDouble(),
                min: 0,
                max: 100,
                divisions: 10,
                valueLabel: (value) =>
                    '${_sensitivityLabel(value.round())} ${value.round()}',
                onChanged: app.piConnected && !_busy
                    ? (value) {
                        app.updatePiSensitivity(value.round());
                      }
                    : (_) {},
              ),
              SettingInfoRow(
                label: 'Face Confidence Threshold',
                value: app.piConfidence.toStringAsFixed(2),
                icon: Icons.face_outlined,
              ),
              SettingInfoRow(
                label: 'Loiter Alert Delay',
                value: '${app.piLoiterSeconds}s',
                icon: Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingSection(
            title: 'Connection',
            children: [
              SettingInfoRow(
                label: 'Pi IP Address',
                value: ip.isEmpty ? 'Not configured' : ip,
                icon: Icons.router_outlined,
                onCopy: ip.isEmpty
                    ? null
                    : () => _copyToClipboard(ip, 'Pi IP address'),
              ),
              SettingInfoRow(
                label: 'API Base URL',
                value: PiService.baseUrl.isEmpty ? 'Not available' : PiService.baseUrl,
                icon: Icons.link,
                onCopy: PiService.baseUrl.isEmpty
                    ? null
                    : () => _copyToClipboard(PiService.baseUrl, 'API URL'),
              ),
              SettingInfoRow(
                label: 'Live Stream URL',
                value: PiService.streamUrl.isEmpty ? 'Not available' : PiService.streamUrl,
                icon: Icons.videocam_outlined,
                onCopy: PiService.streamUrl.isEmpty
                    ? null
                    : () => _copyToClipboard(PiService.streamUrl, 'Stream URL'),
              ),
              SettingNavRow(
                label: 'Refresh Pi Status',
                icon: Icons.refresh_rounded,
                onTap: app.piConnected && !_busy
                    ? () => _runAction(
                          () async {
                            await app.refreshFromPi();
                            return true;
                          },
                          'Pi status refreshed',
                          'Failed to refresh Pi status',
                        )
                    : () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!app.piConnected)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accentRed.withOpacity(0.22),
                ),
              ),
              child: Text(
                'The Pi is offline right now, so controls are disabled until the app can reach the API server again.',
                style: AppText.bodyS(color: AppColors.accentRed),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.bodyS(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppText.bodyM(color: color).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
