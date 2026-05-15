// lib/screens/camera/camera_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/settings_row.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/s_button.dart';

class CameraSettingsScreen extends StatefulWidget {
  final String cameraId;
  const CameraSettingsScreen({super.key, required this.cameraId});

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen> {
  bool _checkingFirmware = false;
  bool _rebooting = false;

  double _sensitivityValue = 2.0; // 1=Low, 2=Medium, 3=High

  String _sensitivityLabel(double v) {
    if (v <= 1) return 'Low';
    if (v <= 2) return 'Medium';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final cam = prov.cameras.firstWhere((c) => c.id == widget.cameraId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(cam.name, style: AppText.h3()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          StatusBadge(isOnline: cam.isOnline),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [

        // ── Camera Preview ──────────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.pop(context), // tap preview to go to live view
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(fit: StackFit.expand, children: [
                Image.network(cam.thumb, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.bgElevated,
                    child: const Icon(Icons.videocam_off, color: AppColors.textMuted, size: 40),
                  )),
                Positioned(top: 10, left: 10, child: StatusBadge(isOnline: cam.isOnline)),
                if (cam.isRecording)
                  const Positioned(top: 10, right: 10, child: RecordingBadge()),
                Positioned(bottom: 10, right: 10, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text('Tap for live view', style: AppText.label(size: 10)),
                )),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Device Rename & Zone ──────────────────────────────────────────
        SettingSection(title: 'Identity', children: [
          SettingNavRow(
            label: 'Camera Name',
            value: cam.name,
            icon: Icons.label_outline,
            onTap: () => _editField(context, prov, cam.id, 'name', cam.name),
          ),
          SettingNavRow(
            label: 'Zone',
            value: cam.zone,
            icon: Icons.location_on_outlined,
            onTap: () => _pickZone(context, prov, cam.id, cam.zone),
          ),
        ]),

        const SizedBox(height: 20),

        // ── General ───────────────────────────────────────────────────────
        SettingSection(title: 'General', children: [
          SettingSwitchRow(
            label: 'Camera On/Off',
            subtitle: 'Enable or disable this camera',
            icon: Icons.power_settings_new,
            value: cam.isOn,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(isOn: v)),
          ),
          SettingSwitchRow(
            label: 'Motion Detection',
            icon: Icons.directions_run,
            value: cam.motionDetection,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(motionDetection: v)),
          ),
          SettingSwitchRow(
            label: 'Night Vision Mode',
            icon: Icons.nightlight_round,
            value: cam.nightVision,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(nightVision: v)),
          ),
          SettingSwitchRow(
            label: 'Audio Recording',
            icon: Icons.mic_outlined,
            value: cam.audioRecording,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(audioRecording: v)),
          ),
          SettingSwitchRow(
            label: 'Privacy Mask',
            subtitle: 'Blur sensitive areas from recording',
            icon: Icons.visibility_off_outlined,
            value: cam.privacyMask,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(privacyMask: v)),
          ),
        ]),

        const SizedBox(height: 20),

        // ── Notifications ─────────────────────────────────────────────────
        SettingSection(title: 'Notifications', children: [
          SettingSwitchRow(
            label: 'Motion Alerts',
            icon: Icons.notifications_outlined,
            value: cam.motionAlerts,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(motionAlerts: v)),
          ),
          SettingSwitchRow(
            label: 'Person Detection Alerts',
            icon: Icons.person_outline,
            value: cam.personAlerts,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(personAlerts: v)),
          ),
          SettingSwitchRow(
            label: 'Sound Detection',
            icon: Icons.volume_up_outlined,
            value: cam.soundDetection,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(soundDetection: v)),
          ),
          SettingSliderRow(
            label: 'Detection Sensitivity',
            icon: Icons.tune,
            value: _sensitivityValue,
            min: 1,
            max: 3,
            divisions: 2,
            valueLabel: _sensitivityLabel,
            onChanged: (v) => setState(() => _sensitivityValue = v),
          ),
        ]),

        const SizedBox(height: 20),

        // ── Recording ────────────────────────────────────────────────────
        SettingSection(title: 'Recording', children: [
          SettingDropdownRow(
            label: 'Video Quality',
            icon: Icons.hd_outlined,
            value: cam.videoQuality,
            items: const ['360p', '720p', '1080p', '4K'],
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(videoQuality: v!)),
          ),
          SettingDropdownRow(
            label: 'Storage',
            icon: Icons.cloud_outlined,
            value: cam.storageLocation,
            items: const ['Cloud', 'Local', 'Both'],
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(storageLocation: v!)),
          ),
          SettingSwitchRow(
            label: 'Continuous Recording',
            icon: Icons.fiber_manual_record_outlined,
            value: cam.continuousRecording,
            onChanged: (v) => prov.updateCamera(cam.id, cam.copyWith(continuousRecording: v)),
          ),
          SettingNavRow(
            label: 'Scheduled Recording',
            icon: Icons.schedule,
            onTap: () => _comingSoon(context),
          ),
          SettingNavRow(
            label: 'Motion Zones',
            icon: Icons.crop_free,
            onTap: () => _comingSoon(context),
          ),
        ]),

        const SizedBox(height: 20),

        // ── Device Info ───────────────────────────────────────────────────
        SettingSection(title: 'Device Info', children: [
          SettingInfoRow(
            label: 'Device Name',
            value: cam.name,
            icon: Icons.label_outline,
          ),
          SettingInfoRow(
            label: 'Zone',
            value: cam.zone,
            icon: Icons.location_on_outlined,
          ),
          SettingInfoRow(
            label: 'IP Address',
            value: cam.ip,
            icon: Icons.router_outlined,
            onCopy: () => _copyToClipboard(context, cam.ip, 'IP address'),
          ),
          SettingInfoRow(
            label: 'RTSP URL',
            value: 'rtsp://${cam.ip}/stream',
            icon: Icons.link,
            onCopy: () => _copyToClipboard(context, 'rtsp://${cam.ip}/stream', 'RTSP URL'),
          ),
          SettingInfoRow(
            label: 'Firmware',
            value: cam.firmware,
            icon: Icons.memory_outlined,
          ),
          SettingInfoRow(
            label: 'Signal',
            value: '${cam.signal}%',
            icon: Icons.wifi,
            valueColor: cam.signal > 70 ? AppColors.accentGreen : cam.signal > 30 ? AppColors.accentYellow : AppColors.accentRed,
          ),
          SettingInfoRow(
            label: 'Battery',
            value: '${cam.battery}%',
            icon: Icons.battery_full_outlined,
            valueColor: cam.battery > 50 ? AppColors.accentGreen : cam.battery > 20 ? AppColors.accentYellow : AppColors.accentRed,
          ),
          if (cam.lastMotion != null)
            SettingInfoRow(
              label: 'Last Motion',
              value: cam.lastMotion!,
              icon: Icons.access_time_outlined,
            ),
          if (!cam.isOnline && cam.lastSeen != null)
            SettingInfoRow(
              label: 'Last Seen',
              value: _formatLastSeen(cam.lastSeen!),
              icon: Icons.history,
              valueColor: AppColors.accentRed,
            ),
        ]),

        const SizedBox(height: 20),

        // ── Firmware Update ───────────────────────────────────────────────
        SettingSection(title: 'Maintenance', children: [
          SettingNavRow(
            label: 'Check for Firmware Update',
            value: _checkingFirmware ? 'Checking...' : cam.firmware,
            icon: Icons.system_update_outlined,
            onTap: _checkingFirmware ? () {} : () => _checkFirmware(context, cam.firmware),
          ),
          SettingNavRow(
            label: _rebooting ? 'Rebooting...' : 'Reboot Camera',
            icon: Icons.restart_alt,
            onTap: _rebooting ? () {} : () => _reboot(context),
          ),
        ]),

        const SizedBox(height: 24),

        // ── Danger Zone ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentRed.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
          ),
          child: Column(children: [
            SettingNavRow(label: 'Remove Camera', icon: Icons.delete_outline, onTap: () => _removeBottomSheet(context, prov, cam.id)),
            const Divider(height: 16),
            SettingNavRow(label: 'Factory Reset', icon: Icons.restore, onTap: () => _comingSoon(context)),
          ]),
        ),

        const SizedBox(height: 32),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _comingSoon(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('Coming soon'),
    ));
  }

  void _copyToClipboard(BuildContext ctx, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('$label copied to clipboard'),
    ));
  }

  Future<void> _checkFirmware(BuildContext ctx, String current) async {
    setState(() => _checkingFirmware = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _checkingFirmware = false);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('Firmware $current is up to date'),
    ));
  }

  Future<void> _reboot(BuildContext ctx) async {
    setState(() => _rebooting = true);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _rebooting = false);
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('Camera rebooted successfully'),
    ));
  }

  void _editField(BuildContext ctx, AppProvider prov, String camId, String field, String current) {
    final ctrl = TextEditingController(text: current);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit ${field == 'name' ? 'Camera Name' : 'Zone'}', style: AppText.h3()),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: AppText.bodyM(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: 'Enter ${field == 'name' ? 'camera name' : 'zone'}'),
          ),
          const SizedBox(height: 16),
          SButton(
            label: 'Save',
            onTap: () {
              final cam = prov.cameras.firstWhere((c) => c.id == camId);
              prov.updateCamera(camId, field == 'name'
                  ? cam.copyWith(name: ctrl.text.trim())
                  : cam.copyWith(zone: ctrl.text.trim()));
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _pickZone(BuildContext ctx, AppProvider prov, String camId, String current) {
    const zones = ['Exterior', 'Interior', 'Garage', 'Basement', 'Driveway', 'Garden'];
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text('Select Zone', style: AppText.h3()),
        const SizedBox(height: 8),
        ...zones.map((z) => ListTile(
          title: Text(z, style: AppText.bodyM(color: AppColors.textPrimary)),
          trailing: z == current ? const Icon(Icons.check, color: AppColors.brand) : null,
          onTap: () {
            final cam = prov.cameras.firstWhere((c) => c.id == camId);
            prov.updateCamera(camId, cam.copyWith(zone: z));
            Navigator.pop(ctx);
          },
        )),
        const SizedBox(height: 20),
      ]),
    );
  }

  void _removeBottomSheet(BuildContext ctx, AppProvider prov, String camId) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Remove Camera?', style: AppText.h3()),
          const SizedBox(height: 8),
          Text('This will disconnect the camera from your system. This cannot be undone.',
              style: AppText.bodyM(), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SButton.danger(
            label: 'Remove Camera',
            icon: Icons.delete_outline,
            onTap: () {
              prov.removeCamera(camId);   // FIXED: actually removes from provider
              Navigator.pop(ctx);          // close sheet
              Navigator.pop(ctx);          // go back from settings screen
            },
          ),
          const SizedBox(height: 10),
          SButton.outlined(label: 'Cancel', onTap: () => Navigator.pop(ctx)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  String _formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}