// lib/screens/home/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/status_badge.dart';
import 'home_screen.dart';
import '../camera/camera_screen.dart';      // FIXED: was camera_list_screen.dart
import '../history/history_screen.dart';
import '../alerts/alerts_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Screens are created once in state so they can receive arguments if needed
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      HomeScreen(),
      CameraScreen(),      // FIXED: correct screen
      HistoryScreen(),
      AlertsScreen(),
      SettingsScreen(),
    ];
    // Set system UI once in initState — not on every build
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (provider.piConnected) {
        provider.refreshFromPi();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: prov.navIndex, children: _screens),
      bottomNavigationBar: _BottomNav(
        index: prov.navIndex,
        unread: prov.unreadCount,
        onTap: (i) {
          HapticFeedback.selectionClick(); // haptic on tab switch
          prov.setNav(i);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final int unread;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.7), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            _NavItem(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,           label: 'Home',     idx: 0, current: index, onTap: onTap),
            _NavItem(icon: Icons.videocam_outlined,       activeIcon: Icons.videocam_rounded,       label: 'Cameras',  idx: 1, current: index, onTap: onTap),
            _NavItem(icon: Icons.history_outlined,        activeIcon: Icons.history_rounded,        label: 'History',  idx: 2, current: index, onTap: onTap),
            _NavItem(icon: Icons.notifications_outlined,  activeIcon: Icons.notifications_rounded,  label: 'Alerts',   idx: 3, current: index, onTap: onTap, badge: unread),
            _NavItem(icon: Icons.settings_outlined,       activeIcon: Icons.settings_rounded,       label: 'Settings', idx: 4, current: index, onTap: onTap),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, current;
  final ValueChanged<int> onTap;
  final int badge;
  const _NavItem({required this.icon, required this.activeIcon, required this.label,
      required this.idx, required this.current, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    final showBadge = badge > 0 && !active;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.brand.withOpacity(0.12)
                    : showBadge
                        ? AppColors.accentRed.withOpacity(0.08)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(active ? activeIcon : icon,
                color: active
                    ? AppColors.brand
                    : showBadge
                        ? AppColors.accentRed
                        : AppColors.textMuted,
                size: 22),
            ),
            if (showBadge) Positioned(
              right: -2, top: -2,
              child: CountBadge(count: badge),
            ),
          ]),
          const SizedBox(height: 3),
          Text(label, style: AppText.label(color: active ? AppColors.brand : AppColors.textMuted, size: 9)),
        ]),
      ),
    );
  }
}
