// lib/screens/alerts/notification_settings_screen.dart
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/settings_row.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleCtrl;
  final _emailCtrl = TextEditingController();
  String _fcmToken = 'Loading...';
  String _permissionLabel = 'Checking...';

  static const _soundOptions = ['Default', 'Chime', 'Alert', 'Pulse', 'None'];
  static const _vibrationOptions = ['Off', 'Short', 'Long', 'Double Pulse'];
  static const _cooldownOptions = [30, 60, 120, 300, 600];
  static const _cooldownLabels = ['30s', '1 min', '2 min', '5 min', '10 min'];

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    final prov = context.read<AppProvider>();
    _emailCtrl.text = prov.notifEmail;
    _loadPushDetails();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPushDetails() async {
    final settings = await PushNotificationService.notificationSettings();
    await PushNotificationService.refreshToken();
    if (!mounted) return;

    setState(() {
      _fcmToken = PushNotificationService.currentToken ?? 'Not available';
      _permissionLabel = settings.authorizationStatus.name;
    });
  }

  Future<void> _copyToken() async {
    if (_fcmToken == 'Loading...' ||
        _fcmToken == 'Not available' ||
        _fcmToken.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _fcmToken));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FCM token copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notifications', style: AppText.h3()),
          Text('Alert delivery & schedule', style: AppText.bodyS()),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _sendTestNotification(context),
            child: Text('Test', style: AppText.bodyMBold(color: AppColors.brand)),
          ),
        ],
      ),
      body: Stack(children: [
        // Particle background
        Positioned.fill(child: _NotifParticleBackground(controller: _particleCtrl)),

        ListView(padding: const EdgeInsets.all(20), children: [

          // ── Alert Types ──────────────────────────────────────────────
          SettingSection(title: 'Alert Types', children: [
            SettingSwitchRow(
              label: 'Motion Detected',
              subtitle: 'Any movement in camera zone',
              icon: Icons.directions_run,
              value: prov.notifMotion,
              onChanged: (v) => prov.toggleNotif('motion', v),
            ),
            SettingSwitchRow(
              label: 'Person Detected',
              subtitle: 'AI identifies a person',
              icon: Icons.person_outline,
              value: prov.notifPerson,
              onChanged: (v) => prov.toggleNotif('person', v),
            ),
            SettingSwitchRow(
              label: 'System Alerts',
              subtitle: 'Camera offline, low battery',
              icon: Icons.warning_amber_outlined,
              value: prov.notifSystem,
              onChanged: (v) => prov.toggleNotif('system', v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Schedule ─────────────────────────────────────────────────
          SettingSection(title: 'Schedule', children: [
            SettingSwitchRow(
              label: 'Do Not Disturb',
              subtitle: 'Pause all notifications',
              icon: Icons.do_not_disturb_on_outlined,
              value: prov.doNotDisturb,
              onChanged: (v) => prov.toggleNotif('dnd', v),
            ),
            SettingTimePickerRow(
              label: 'Quiet Hours Start',
              icon: Icons.bedtime_outlined,
              value: prov.quietHoursStart,
              onTap: () => _pickTime(context, prov, isStart: true),
            ),
            SettingTimePickerRow(
              label: 'Quiet Hours End',
              icon: Icons.wb_sunny_outlined,
              value: prov.quietHoursEnd,
              onTap: () => _pickTime(context, prov, isStart: false),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Delivery ─────────────────────────────────────────────────
          SettingSection(title: 'Delivery', children: [
            SettingInfoRow(
              label: 'Push Permission',
              value: _permissionLabel,
              icon: Icons.notifications_active_outlined,
            ),
            SettingNavRow(
              label: 'Sound',
              value: prov.notifSound,
              icon: Icons.music_note_outlined,
              onTap: () => _pickOption(
                context, 'Alert Sound', _soundOptions, prov.notifSound,
                (v) => prov.setNotifSound(v),
              ),
            ),
            SettingNavRow(
              label: 'Vibration',
              value: prov.notifVibration,
              icon: Icons.vibration,
              onTap: () => _pickOption(
                context, 'Vibration Pattern', _vibrationOptions, prov.notifVibration,
                (v) => prov.setNotifVibration(v),
              ),
            ),
            SettingNavRow(
              label: 'Banner Style',
              value: 'Temporary',
              icon: Icons.notifications_none_outlined,
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 20),

          // ── Advanced ─────────────────────────────────────────────────
          SettingSection(title: 'Firebase Push', children: [
            SettingInfoRow(
              label: 'FCM Device Token',
              value: _fcmToken == 'Loading...'
                  ? 'Loading...'
                  : _fcmToken == 'Not available'
                      ? 'Not available'
                      : '${_fcmToken.substring(0, min(32, _fcmToken.length))}...',
              icon: Icons.key_outlined,
              onCopy: _fcmToken == 'Loading...' || _fcmToken == 'Not available'
                  ? null
                  : _copyToken,
            ),
            SettingNavRow(
              label: 'Refresh Push Token',
              icon: Icons.refresh_rounded,
              onTap: _loadPushDetails,
            ),
          ]),

          const SizedBox(height: 20),

          SettingSection(title: 'Advanced', children: [
            SettingSliderRow(
              label: 'Detection Sensitivity',
              subtitle: 'How sensitive motion detection is',
              icon: Icons.tune,
              value: prov.notifSensitivity == 'Low' ? 1 : prov.notifSensitivity == 'Medium' ? 2 : 3,
              min: 1,
              max: 3,
              divisions: 2,
              valueLabel: (v) => v <= 1 ? 'Low' : v <= 2 ? 'Medium' : 'High',
              onChanged: (v) => prov.setNotifSensitivity(
                v <= 1 ? 'Low' : v <= 2 ? 'Medium' : 'High',
              ),
            ),
            SettingNavRow(
              label: 'Cooldown Period',
              value: _cooldownLabels[_cooldownOptions.indexOf(prov.notifCooldownSeconds).clamp(0, _cooldownLabels.length - 1)],
              icon: Icons.timer_outlined,
              onTap: () => _pickCooldown(context, prov),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Email Alerts ─────────────────────────────────────────────
          SettingSection(title: 'Email Alerts', children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Email Address', style: AppText.bodyM(color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: AppText.bodyM(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'your@email.com',
                        prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      prov.setNotifEmail(_emailCtrl.text.trim());
                      FocusScope.of(context).unfocus();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Email saved'),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Save', style: AppText.btn()),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Per-Camera ───────────────────────────────────────────────
          SettingSection(title: 'Per-Camera Notifications', children: [
            ...context.read<AppProvider>().cameras.map((cam) => SettingSwitchRow(
              label: cam.name,
              subtitle: cam.zone,
              icon: Icons.videocam_outlined,
              value: cam.motionAlerts || cam.personAlerts,
              onChanged: (v) => context.read<AppProvider>().updateCamera(cam.id, cam.copyWith(
                motionAlerts: v, personAlerts: v,
              )),
            )),
          ]),

          const SizedBox(height: 20),

          // ── Summary ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatChip('Unread', '${prov.unreadCount}', AppColors.accentRed),
              _StatChip('Cameras', '${prov.onlineCount}/${prov.cameras.length}', AppColors.brand),
              _StatChip('Mode', prov.doNotDisturb ? 'DND' : 'On', prov.doNotDisturb ? AppColors.accentYellow : AppColors.accentGreen),
            ]),
          ),

          const SizedBox(height: 32),
        ]),
      ]),
    );
  }

  // ── Action helpers ──────────────────────────────────────────────────────────

  Future<void> _pickTime(BuildContext ctx, AppProvider prov, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: (isStart ? prov.quietHoursStart : prov.quietHoursEnd) ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.brand, surface: AppColors.bgSurface),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      prov.setQuietHours(
        isStart ? picked : prov.quietHoursStart,
        isStart ? prov.quietHoursEnd : picked,
      );
    }
  }

  void _pickOption(BuildContext ctx, String title, List<String> options, String current, ValueChanged<String> onSelect) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text(title, style: AppText.h3()),
        const SizedBox(height: 8),
        ...options.map((o) => ListTile(
          title: Text(o, style: AppText.bodyM(color: AppColors.textPrimary)),
          trailing: o == current ? const Icon(Icons.check, color: AppColors.brand) : null,
          onTap: () { onSelect(o); Navigator.pop(ctx); },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _pickCooldown(BuildContext ctx, AppProvider prov) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text('Cooldown Period', style: AppText.h3()),
        const SizedBox(height: 8),
        ..._cooldownOptions.asMap().entries.map((e) => ListTile(
          title: Text(_cooldownLabels[e.key], style: AppText.bodyM(color: AppColors.textPrimary)),
          subtitle: Text('Wait ${_cooldownLabels[e.key]} between alerts from same camera', style: AppText.bodyS()),
          trailing: prov.notifCooldownSeconds == e.value ? const Icon(Icons.check, color: AppColors.brand) : null,
          onTap: () { prov.setNotifCooldown(e.value); Navigator.pop(ctx); },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _sendTestNotification(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('🔔 Test alert sent — check your notifications'),
    ));
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: AppText.h2(color: color)),
    const SizedBox(height: 2),
    Text(label, style: AppText.bodyS()),
  ]);
}

// ── Particle background ───────────────────────────────────────────────────────
class _NotifParticleBackground extends StatelessWidget {
  final AnimationController controller;
  const _NotifParticleBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _NotifParticlePainter(progress: controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _NotifParticlePainter extends CustomPainter {
  final double progress;
  _NotifParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = AppColors.brand.withOpacity(0.03)..strokeWidth = 1;
    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += spacing)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    final rng = Random(31);
    final dotPaint = Paint()..color = AppColors.brand.withOpacity(0.45);
    for (int i = 0; i < 40; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final y = (baseY + progress * 120) % size.height;
      canvas.drawCircle(Offset(baseX, y), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_NotifParticlePainter old) => old.progress != progress;
}
