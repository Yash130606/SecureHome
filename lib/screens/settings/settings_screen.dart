// lib/screens/settings/settings_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/settings_row.dart';
import '../alerts/notification_settings_screen.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'face_database_screen.dart';
import '../camera/pi_camera_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final storagePercent = 0.5; // 50/100 GB

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          /// PARTICLE BACKGROUND
          const Positioned.fill(child: _SettingsParticleBackground()),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── HEADER ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preferences & Config',
                            style: AppText.bodyM(color: AppColors.textMuted)),
                        Text('Settings', style: AppText.h1()),
                      ],
                    ),
                  ),
                ),

                // ── PROFILE CARD ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brand.withOpacity(0.14),
                              AppColors.bgSurface,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.brand.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withOpacity(0.35),
                                  blurRadius: 14,
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (auth.userName != null &&
                                        auth.userName!.isNotEmpty)
                                    ? auth.userName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.userName ?? 'User',
                                    style: AppText.h3()),
                                Text(auth.user?.email ?? 'No Email',
                                    style: AppText.bodyS()),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.accentGreen
                                              .withOpacity(0.3)),
                                    ),
                                    child: Text('Pro Plan',
                                        style: AppText.label(
                                            color: AppColors.accentGreen,
                                            size: 9)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color:
                                              AppColors.brand.withOpacity(0.2)),
                                    ),
                                    child: Text('Member since 2023',
                                        style: AppText.label(
                                            color: AppColors.brand, size: 9)),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                        ]),
                      ),
                    ),
                  ),
                ),

                // ── QUICK STATS ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(children: [
                      _QuickStat(
                        label: 'Cameras',
                        value: '${prov.cameras.length}',
                        icon: Icons.videocam_outlined,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 10),
                      _QuickStat(
                        label: 'Online',
                        value: '${prov.onlineCount}',
                        icon: Icons.wifi,
                        color: AppColors.accentGreen,
                      ),
                      const SizedBox(width: 10),
                      _QuickStat(
                        label: 'Alerts',
                        value: '${prov.unreadCount}',
                        icon: Icons.notifications_outlined,
                        color: prov.unreadCount > 0
                            ? AppColors.accentRed
                            : AppColors.textMuted,
                      ),
                    ]),
                  ),
                ),

                // ── STORAGE CARD ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.cloud_outlined,
                                  color: AppColors.brand, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cloud Storage',
                                      style: AppText.bodyM().copyWith(
                                          fontWeight: FontWeight.w600)),
                                  Text('50 GB used of 100 GB',
                                      style: AppText.bodyS(
                                          color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Text('50%',
                                style: AppText.bodyM(color: AppColors.brand)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 10),
                          // Storage bar
                          Stack(children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: storagePercent,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _StorageChip(
                                label: 'Recordings',
                                gb: '32 GB',
                                color: AppColors.brand),
                            const SizedBox(width: 8),
                            _StorageChip(
                                label: 'Snapshots',
                                gb: '12 GB',
                                color: Colors.teal),
                            const SizedBox(width: 8),
                            _StorageChip(
                                label: 'Free',
                                gb: '50 GB',
                                color: AppColors.accentGreen),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── SETTINGS SECTIONS ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(children: [
                      SettingSection(title: 'System', children: [
                        SettingNavRow(
                          label: 'Network',
                          icon: Icons.wifi_outlined,
                          onTap: () {},
                        ),
                        SettingNavRow(
                          label: 'Raspberry Pi Connection',
                          icon: Icons.router_outlined,
                          value: prov.piConnected
                              ? (prov.piRunning ? 'Online • Detecting' : 'Online • Idle')
                              : 'Offline',
                          valueColor: prov.piConnected
                              ? (prov.piRunning
                                  ? AppColors.accentGreen
                                  : AppColors.accentYellow)
                              : Colors.red,
                          onTap: () => _showPiSetupSheet(context, auth),
                        ),
                        SettingNavRow(
                          label: 'Notifications',
                          icon: Icons.notifications_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationSettingsScreen()),
                          ),
                        ),
                        SettingNavRow(
                          label: 'Pi Camera Controls',
                          icon: Icons.videocam_outlined,
                          value: prov.piConnected ? 'Open' : 'Connect first',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PiCameraSettingsScreen(),
                            ),
                          ),
                        ),
                        SettingNavRow(
                          label: 'Storage & Cloud',
                          icon: Icons.cloud_outlined,
                          value: '50 / 100 GB',
                          onTap: () {},
                        ),
                      ]),

                      const SizedBox(height: 18),

                      SettingSection(title: 'Cameras', children: [
                        SettingNavRow(label: 'Camera Settings', onTap: () {}),
                        SettingNavRow(
                          label: 'Face Database',
                          icon: Icons.face_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FaceDatabaseScreen(),
                            ),
                          ),
                        ),
                        SettingNavRow(
                            label: 'Recording Defaults', onTap: () {}),
                        SettingNavRow(label: 'Detection Zones', onTap: () {}),
                        SettingNavRow(
                          label: 'Video Quality',
                          value: '1080p',
                          onTap: () {},
                        ),
                      ]),

                      const SizedBox(height: 18),

                      SettingSection(title: 'Privacy', children: [
                        SettingNavRow(label: 'Privacy Settings', onTap: () {}),
                        SettingNavRow(label: 'Data Usage', onTap: () {}),
                        SettingNavRow(
                            label: 'Access Permissions', onTap: () {}),
                      ]),

                      const SizedBox(height: 18),

                      SettingSection(title: 'Support', children: [
                        SettingNavRow(label: 'Help Center', onTap: () {}),
                        SettingNavRow(label: 'Report a Problem', onTap: () {}),
                        SettingNavRow(
                          label: 'About & Legal',
                          onTap: () => _showAbout(context),
                        ),
                      ]),

                      const SizedBox(height: 28),

                      // ── APP FOOTER ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withOpacity(0.35),
                                  blurRadius: 18,
                                )
                              ],
                            ),
                            child: const Icon(Icons.security_rounded,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(height: 10),
                          Text('SecureHome', style: AppText.h3()),
                          const SizedBox(height: 2),
                          Text('Version 1.0.0 (Build 1)',
                              style: AppText.bodyS()),
                          const SizedBox(height: 4),
                          Text(
                              prov.piConnected
                                  ? (prov.piRunning
                                      ? 'Pi online and detection active'
                                      : 'Pi online, detection stopped')
                                  : 'Pi offline or not configured',
                              style: AppText.bodyS(
                                  color: prov.piConnected
                                      ? (prov.piRunning
                                          ? AppColors.accentGreen
                                          : AppColors.accentYellow)
                                      : Colors.red)),
                          const SizedBox(height: 20),

                          // Sign out button
                          GestureDetector(
                            onTap: () => _showSignOutSheet(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.accentRed.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        AppColors.accentRed.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout_rounded,
                                      color: AppColors.accentRed, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Sign Out',
                                      style: AppText.bodyM(
                                              color: AppColors.accentRed)
                                          .copyWith(
                                              fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPiSetupSheet(BuildContext ctx, AuthProvider auth) {
    final app = ctx.read<AppProvider>();
    final ipCtrl = TextEditingController(
      text: auth.piIpAddress ?? '',
    );

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.bgSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.router_outlined,
                    color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Pi Connection', style: AppText.h2()),
              const Spacer(),
              // Connection status badge
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: app.piConnected
                        ? AppColors.accentGreen.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: app.piConnected
                          ? AppColors.accentGreen.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: app.piConnected
                              ? AppColors.accentGreen
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          app.piConnected
                              ? (app.piRunning
                                  ? 'Connected\nDetection active'
                                  : 'Connected\nDetection stopped')
                              : 'Disconnected',
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            color: app.piConnected
                                ? AppColors.accentGreen
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── IP Input ─────────────────────────────
            Text('Raspberry Pi IP Address',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 8),
            TextField(
              controller: ipCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 192.168.1.100',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.lan_outlined,
                    color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.brand, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Info box ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Run "hostname -I" in Pi terminal to find IP',
                    style: TextStyle(color: Colors.blue.shade300, fontSize: 12),
                  ),
                ),
              ]),
            ),
            if ((auth.errorMessage ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.errorMessage!,
                      style: AppText.bodyS(color: Colors.red),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),

            // ── Buttons ──────────────────────────────
            Row(children: [
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setLocal) {
                    bool saving = false;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final ip = ipCtrl.text.trim();
                        if (ip.isEmpty) return;
                        Navigator.pop(ctx);
                        final ok = await ctx.read<AuthProvider>().savePiIp(ip);
                        if (ctx.mounted) {
                          await ctx.read<AppProvider>().connectToPi(ip);
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? '✅ Connected to Pi!'
                                  : '❌ Could not connect to Pi'),
                              backgroundColor:
                                  ok ? AppColors.accentGreen : Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Save & Connect',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Retry button
              if (auth.piIpAddress != null && auth.piIpAddress!.isNotEmpty)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: AppColors.border),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok =
                        await ctx.read<AuthProvider>().retryPiConnection();
                    if (ctx.mounted && ok) {
                      await ctx.read<AppProvider>().refreshFromPi();
                    }
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content:
                              Text(ok ? '✅ Reconnected!' : '❌ Still offline'),
                          backgroundColor:
                              ok ? AppColors.accentGreen : Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Retry',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.brand.withOpacity(0.3), blurRadius: 14)
                ],
              ),
              child: const Icon(Icons.security_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text('SecureHome', style: AppText.h2()),
            const SizedBox(height: 4),
            Text('Version 1.0.0 (Build 1)',
                style: AppText.bodyS(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            _AboutRow(
              icon: Icons.info_outline,
              label: 'Description',
              value:
                  'A professional home security camera monitoring application.',
            ),
            const SizedBox(height: 10),
            _AboutRow(
              icon: Icons.copyright_outlined,
              label: 'Copyright',
              value: '© 2024 SecureHome Inc.',
            ),
            const SizedBox(height: 10),
            _AboutRow(
              icon: Icons.gavel_outlined,
              label: 'License',
              value: 'All rights reserved.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Sign Out', style: AppText.h2()),
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
                    'You will be logged out of SecureHome. Camera monitoring will stop until you sign back in.',
                    style: AppText.bodyM(color: Colors.red),
                  ),
                ),
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
                    await ctx
                        .read<AuthProvider>()
                        .logout(); // ✅ Firebase logout
                    ctx
                        .read<AppProvider>()
                        .logout(); // (if needed for local state)

                    Navigator.pushAndRemoveUntil(
                      ctx,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Sign Out',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUICK STAT
// ─────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppText.h2().copyWith(fontSize: 16)),
              Text(label, style: AppText.bodyS(color: AppColors.textMuted)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STORAGE CHIP
// ─────────────────────────────────────────────

class _StorageChip extends StatelessWidget {
  final String label;
  final String gb;
  final Color color;

  const _StorageChip({
    required this.label,
    required this.gb,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text('$label ', style: AppText.bodyS(color: AppColors.textMuted)),
      Text(gb, style: AppText.bodyS().copyWith(fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─────────────────────────────────────────────
// ABOUT ROW
// ─────────────────────────────────────────────

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brand, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.bodyS(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: AppText.bodyM()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PARTICLE BACKGROUND
// ─────────────────────────────────────────────

class _SettingsParticleBackground extends StatefulWidget {
  const _SettingsParticleBackground();

  @override
  State<_SettingsParticleBackground> createState() =>
      _SettingsParticleBackgroundState();
}

class _SettingsParticleBackgroundState
    extends State<_SettingsParticleBackground>
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
        painter: _SettingsParticlePainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _SettingsParticlePainter extends CustomPainter {
  final double progress;
  _SettingsParticlePainter(this.progress);

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

    final particlePaint = Paint()..color = AppColors.brand.withOpacity(0.45);
    final random = Random(19);

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          ((random.nextDouble() * size.height) + progress * 120) % size.height;
      final radius = random.nextDouble() * 2.0 + 0.8;
      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_SettingsParticlePainter old) => old.progress != progress;
}
