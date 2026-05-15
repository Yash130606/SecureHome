// lib/screens/camera/camera_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/pi_thumbnail.dart';
import 'live_view_screen.dart';
import 'camera_settings_screen.dart';
import 'pi_live_screen.dart';
import 'pi_camera_settings_screen.dart';

// ─────────────────────────────────────────────
// FILTER ENUM
// ─────────────────────────────────────────────

enum _CameraFilter { all, online, offline, alerts }

// ─────────────────────────────────────────────
// CAMERA SCREEN
// ─────────────────────────────────────────────

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  _CameraFilter _filter = _CameraFilter.all;
  bool _isGridView = false;
  String _searchQuery = "";
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _selectMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<dynamic> _applyFilters(List<dynamic> cameras) {
    var list = cameras.where((cam) {
      final name = (cam.name as String).toLowerCase();
      final zone = (cam.zone as String).toLowerCase();
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || name.contains(q) || zone.contains(q);
    }).toList();

    switch (_filter) {
      case _CameraFilter.online:
        list = list.where((c) => c.isOnline).toList();
        break;
      case _CameraFilter.offline:
        list = list.where((c) => !c.isOnline).toList();
        break;
      case _CameraFilter.alerts:
        list = list.where((c) => (c.alerts ?? 0) > 0).toList();
        break;
      case _CameraFilter.all:
        break;
    }
    return list;
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(id);
      }
    });
  }

  void _showBulkSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${_selected.length} cameras selected", style: AppText.h2()),
            const SizedBox(height: 18),
            _BulkAction(
              icon: Icons.videocam,
              label: "Enable All Selected",
              color: AppColors.accentGreen,
              onTap: () {
                final prov = context.read<AppProvider>();
                for (final id in _selected) prov.toggleCamera(id, true);
                Navigator.pop(context);
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              },
            ),
            const SizedBox(height: 10),
            _BulkAction(
              icon: Icons.videocam_off,
              label: "Disable All Selected",
              color: Colors.orange,
              onTap: () {
                final prov = context.read<AppProvider>();
                for (final id in _selected) prov.toggleCamera(id, false);
                Navigator.pop(context);
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              },
            ),
            const SizedBox(height: 10),
            _BulkAction(
              icon: Icons.notifications_active,
              label: "Arm Motion Alerts",
              color: AppColors.brand,
              onTap: () {
                final prov = context.read<AppProvider>();
                for (final id in _selected) {
                  final cam = prov.cameras.firstWhere((c) => c.id == id);
                  prov.updateCamera(
                      id, cam.copyWith(motionAlerts: true, personAlerts: true));
                }
                Navigator.pop(context);
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              },
            ),
            const SizedBox(height: 10),
            _BulkAction(
              icon: Icons.close,
              label: "Cancel",
              color: Colors.grey,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final allCameras = prov.cameras;
    final filtered = _applyFilters(allCameras);

    final int onlineCount = allCameras.where((c) => c.isOnline).length;
    final int offlineCount = allCameras.length - onlineCount;
    final int alertCount =
        allCameras.fold(0, (sum, c) => sum + ((c.alerts ?? 0) as int));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _CameraParticleBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      if (_selectMode) ...[
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectMode = false;
                            _selected.clear();
                          }),
                          child: const Icon(Icons.close,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Text("${_selected.length} selected",
                            style: AppText.h1()),
                      ] else ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Cameras", style: AppText.h1()),
                            Text(
                              "$onlineCount online · $offlineCount offline",
                              style: AppText.bodyS(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      if (_selectMode) ...[
                        GestureDetector(
                          onTap: () => _showBulkSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text("Actions",
                                style: AppText.bodyS(color: Colors.white)),
                          ),
                        ),
                      ] else ...[
                        _HeaderBtn(
                          icon: _showSearch ? Icons.search_off : Icons.search,
                          onTap: () => setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchQuery = "";
                              _searchCtrl.clear();
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        _HeaderBtn(
                          icon: _isGridView ? Icons.view_list : Icons.grid_view,
                          onTap: () =>
                              setState(() => _isGridView = !_isGridView),
                        ),
                        const SizedBox(width: 8),
                        _HeaderBtn(
                          icon: Icons.add_circle_outline,
                          onTap: () => _showAddCameraSheet(context),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── SEARCH BAR ──────────────────────────────
                if (_showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: AppText.bodyM(),
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: "Search by name or zone...",
                          hintStyle: AppText.bodyM(color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.textMuted, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // ── SUMMARY STATS ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _MiniStat(
                        label: "Online",
                        value: "$onlineCount",
                        color: AppColors.accentGreen,
                        icon: Icons.circle,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: "Offline",
                        value: "$offlineCount",
                        color: Colors.grey,
                        icon: Icons.circle,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: "Alerts",
                        value: "$alertCount",
                        color: Colors.red,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: "Total",
                        value: "${allCameras.length}",
                        color: AppColors.brand,
                        icon: Icons.videocam,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── FILTER CHIPS ────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FilterChip(
                        label: "All",
                        active: _filter == _CameraFilter.all,
                        onTap: () =>
                            setState(() => _filter = _CameraFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: "Online",
                        active: _filter == _CameraFilter.online,
                        onTap: () =>
                            setState(() => _filter = _CameraFilter.online),
                        color: AppColors.accentGreen,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: "Offline",
                        active: _filter == _CameraFilter.offline,
                        onTap: () =>
                            setState(() => _filter = _CameraFilter.offline),
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: "Alerts",
                        active: _filter == _CameraFilter.alerts,
                        onTap: () =>
                            setState(() => _filter = _CameraFilter.alerts),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── CAMERA LIST / GRID ──────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // ── PI LIVE CAMERA CARD ─────────────────
                      // ── PI LIVE CAMERA CARD ─────────────────
                      if (prov.piConnected) ...[
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PiLiveScreen())),
                          child: _PiCameraCard(),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.25)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.wifi_off_outlined,
                                color: Colors.orange, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pi Camera Offline',
                                      style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  Text(
                                      'Go to Settings → Pi Connection to connect',
                                      style: TextStyle(
                                          color: Colors.orange.withOpacity(0.7),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ],

                      // ── MOCK CAMERAS ─────────────────────────
                      if (filtered.isEmpty)
                        _EmptyState(
                          filter: _filter,
                          hasSearch: _searchQuery.isNotEmpty,
                        )
                      else if (_isGridView)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final cam = filtered[i];
                            return _CameraGridCard(
                              camera: cam,
                              selected: _selected.contains(cam.id as String),
                              selectMode: _selectMode,
                              onTap: () {
                                if (_selectMode) {
                                  _toggleSelect(cam.id as String);
                                } else {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              LiveViewScreen(camera: cam)));
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _selectMode = true;
                                  _selected.add(cam.id as String);
                                });
                              },
                              onSettings: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => CameraSettingsScreen(
                                          cameraId: cam.id as String))),
                            );
                          },
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final cam = filtered[i];
                            return _CameraListCard(
                              camera: cam,
                              selected: _selected.contains(cam.id as String),
                              selectMode: _selectMode,
                              onTap: () {
                                if (_selectMode) {
                                  _toggleSelect(cam.id as String);
                                } else {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              LiveViewScreen(camera: cam)));
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _selectMode = true;
                                  _selected.add(cam.id as String);
                                });
                              },
                              onSettings: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => CameraSettingsScreen(
                                          cameraId: cam.id as String))),
                            );
                          },
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCameraSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Add Camera", style: AppText.h2()),
            const SizedBox(height: 6),
            Text(
              "Choose how you want to add a new camera.",
              style: AppText.bodyM(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            _AddOption(
              icon: Icons.qr_code_scanner,
              title: "Scan QR Code",
              subtitle: "Point camera at the QR on your device",
              color: AppColors.brand,
            ),
            const SizedBox(height: 10),
            _AddOption(
              icon: Icons.wifi,
              title: "Connect via Wi-Fi",
              subtitle: "Find cameras on your local network",
              color: AppColors.accentGreen,
            ),
            const SizedBox(height: 10),
            _AddOption(
              icon: Icons.link,
              title: "Enter IP / RTSP URL",
              subtitle: "Manually connect using a stream URL",
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CAMERA LIST CARD
// ─────────────────────────────────────────────

class _CameraListCard extends StatefulWidget {
  final dynamic camera;
  final bool selected;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSettings;

  const _CameraListCard({
    required this.camera,
    required this.selected,
    required this.selectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSettings,
  });

  @override
  State<_CameraListCard> createState() => _CameraListCardState();
}

class _CameraListCardState extends State<_CameraListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  late Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final bool online = cam.isOn == true;
    final int wifi = cam.signal ?? 78;
    final int battery = cam.battery ?? 91;
    final int alerts = cam.alerts ?? 0;
    final String lastMotion = cam.lastMotion ?? "No recent motion";
    final bool isRecording = online && (cam.isRecording ?? true);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.selected ? AppColors.brand : AppColors.border,
            width: widget.selected ? 2 : 1,
          ),
          boxShadow: widget.selected
              ? [
                  BoxShadow(
                      color: AppColors.brand.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.network(
                    cam.thumb,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: AppColors.bg,
                      child: const Center(
                          child: Icon(Icons.videocam_off,
                              color: Colors.grey, size: 40)),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.3, 0.7, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cam.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Row(children: [
                          const Icon(Icons.location_on,
                              color: Colors.white70, size: 12),
                          const SizedBox(width: 3),
                          Text(cam.zone,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ]),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: _LiveBadge(online: online, blinkAnim: _blinkAnim),
                  ),
                  if (isRecording)
                    Positioned(
                        bottom: 10,
                        left: 12,
                        child: _RecordingPill(blinkAnim: _blinkAnim)),
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Row(children: [
                      _InfoPill(icon: Icons.battery_full, label: "$battery%"),
                      const SizedBox(width: 6),
                      _InfoPill(icon: Icons.wifi, label: "$wifi%"),
                    ]),
                  ),
                  if (widget.selectMode)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: widget.selected
                                ? AppColors.brand
                                : Colors.black38,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: widget.selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: online ? AppColors.accentGreen : Colors.grey,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? "Live • Streaming" : "Offline",
                        style: AppText.bodyS(
                            color:
                                online ? AppColors.accentGreen : Colors.grey),
                      ),
                      Text("Motion: $lastMotion",
                          style: AppText.bodyS(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (alerts > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withOpacity(0.4))),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 12),
                      const SizedBox(width: 3),
                      Text("$alerts alert${alerts > 1 ? 's' : ''}",
                          style: AppText.bodyS(color: Colors.red)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(online ? Icons.cloud_done : Icons.cloud_off,
                    color: online ? AppColors.accentGreen : Colors.grey,
                    size: 18),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.onSettings,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CAMERA GRID CARD
// ─────────────────────────────────────────────

class _CameraGridCard extends StatefulWidget {
  final dynamic camera;
  final bool selected;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSettings;

  const _CameraGridCard({
    required this.camera,
    required this.selected,
    required this.selectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSettings,
  });

  @override
  State<_CameraGridCard> createState() => _CameraGridCardState();
}

class _CameraGridCardState extends State<_CameraGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  late Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final bool online = cam.isOn == true;
    final int alerts = cam.alerts ?? 0;
    final bool isRecording = online && (cam.isRecording ?? true);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: widget.selected ? AppColors.brand : AppColors.border,
              width: widget.selected ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(cam.thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: AppColors.bgSurface,
                      child: const Center(
                          child: Icon(Icons.videocam_off,
                              color: Colors.grey, size: 32)))),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(children: [
                  _LiveBadge(online: online, blinkAnim: _blinkAnim),
                  const Spacer(),
                  if (alerts > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text("$alerts",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
              if (isRecording)
                Positioned(
                    top: 36,
                    left: 8,
                    child: _RecordingPill(blinkAnim: _blinkAnim)),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cam.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Expanded(
                          child: Text(cam.zone,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11),
                              overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                        onTap: widget.onSettings,
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.settings_outlined,
                                color: Colors.white, size: 14)),
                      ),
                    ]),
                  ],
                ),
              ),
              if (widget.selectMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        color:
                            widget.selected ? AppColors.brand : Colors.black38,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: widget.selected
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final bool online;
  final Animation<double> blinkAnim;
  const _LiveBadge({required this.online, required this.blinkAnim});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isStreamingReady = app.piConnected && app.piRunning;
    final statusColor =
        isStreamingReady ? AppColors.accentGreen : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: online ? const Color(0xFFD32F2F) : const Color(0xFF616161),
          borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (online)
          AnimatedBuilder(
            animation: blinkAnim,
            builder: (_, __) => Opacity(
              opacity: blinkAnim.value,
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.white.withOpacity(0.6), blurRadius: 4)
                    ]),
              ),
            ),
          ),
        Text(online ? "LIVE" : "OFFLINE",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  final Animation<double> blinkAnim;
  final bool active;
  const _RecordingPill({required this.blinkAnim, this.active = true});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: blinkAnim,
      builder: (_, __) => Opacity(
        opacity: active ? blinkAnim.value : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: (active ? Colors.red : Colors.orange).withOpacity(0.7))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              Icons.fiber_manual_record,
              color: active ? Colors.red : Colors.orange,
              size: 8,
            ),
            const SizedBox(width: 4),
            Text(active ? "REC" : "IDLE",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isStreamingReady = app.piConnected && app.piRunning;
    final statusColor =
        isStreamingReady ? AppColors.accentGreen : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 11),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: active ? c.withOpacity(0.15) : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? c : AppColors.border, width: active ? 1.5 : 1)),
        child: Text(label,
            style: TextStyle(
                color: active ? c : AppColors.textMuted,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value, style: AppText.h2().copyWith(fontSize: 18)),
            Text(label, style: AppText.bodyS(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _BulkAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BulkAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isStreamingReady = app.piConnected && app.piRunning;
    final statusColor =
        isStreamingReady ? AppColors.accentGreen : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: AppText.bodyS(color: AppColors.textMuted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _CameraFilter filter;
  final bool hasSearch;
  const _EmptyState({required this.filter, required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    String title, sub;
    IconData icon;
    if (hasSearch) {
      title = "No results found";
      sub = "Try a different camera name or zone.";
      icon = Icons.search_off;
    } else if (filter == _CameraFilter.offline) {
      title = "All cameras online";
      sub = "Great — no cameras are currently offline.";
      icon = Icons.check_circle_outline;
    } else if (filter == _CameraFilter.alerts) {
      title = "No active alerts";
      sub = "Everything looks clear across all cameras.";
      icon = Icons.shield_outlined;
    } else {
      title = "No cameras added";
      sub = "Tap + to connect your first camera.";
      icon = Icons.videocam_off_outlined;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(title, style: AppText.h2(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub,
              style: AppText.bodyM(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PARTICLE BACKGROUND
// ─────────────────────────────────────────────

class _CameraParticleBackground extends StatefulWidget {
  const _CameraParticleBackground();
  @override
  State<_CameraParticleBackground> createState() =>
      _CameraParticleBackgroundState();
}

class _CameraParticleBackgroundState extends State<_CameraParticleBackground>
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(_ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PI CAMERA CARD — matches mock camera style
// ─────────────────────────────────────────────

class _PiCameraCard extends StatefulWidget {
  const _PiCameraCard();

  @override
  State<_PiCameraCard> createState() => _PiCameraCardState();
}

class _PiCameraCardState extends State<_PiCameraCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  late Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isStreamingReady = app.piConnected && app.piRunning;
    final statusColor =
        isStreamingReady ? AppColors.accentGreen : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.brand.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          // ── THUMBNAIL ───────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                // Stream preview or placeholder
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: PiThumbnail(
                    height: 180,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    enabled: isStreamingReady,
                    placeholder: Container(
                      color: const Color(0xFF0A0A1A),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, 180),
                            painter: _ScanLinePainter(),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.brand.withOpacity(0.3)),
                                ),
                                child: Icon(
                                  isStreamingReady
                                      ? Icons.videocam
                                      : Icons.pause_circle_outline,
                                  color: isStreamingReady
                                      ? AppColors.brand
                                      : Colors.orange,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isStreamingReady
                                    ? 'Loading Pi preview...'
                                    : 'Start detection to preview camera',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.3, 0.7, 1],
                      ),
                    ),
                  ),
                ),

                // Top left — name + zone
                Positioned(
                  top: 10,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pi Camera',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Row(children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 12),
                        const SizedBox(width: 3),
                        const Text('Door Zone',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),

                // Top right — LIVE badge
                Positioned(
                  top: 10,
                  right: 12,
                  child: _LiveBadge(
                      online: isStreamingReady, blinkAnim: _blinkAnim),
                ),

                // Bottom left — REC pill
                Positioned(
                    bottom: 10,
                    left: 12,
                    child: _RecordingPill(
                        blinkAnim: _blinkAnim, active: isStreamingReady)),

                // Bottom right — stats
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Row(children: [
                    _InfoPill(
                        icon: isStreamingReady
                            ? Icons.memory
                            : Icons.pause_circle_outline,
                        label: isStreamingReady ? 'AI ON' : 'IDLE'),
                    const SizedBox(width: 6),
                    _InfoPill(
                        icon: isStreamingReady ? Icons.wifi : Icons.history,
                        label: isStreamingReady ? 'LIVE' : 'READY'),
                  ]),
                ),
              ],
            ),
          ),

          // ── BOTTOM BAR ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              // Status dot
              AnimatedBuilder(
                animation: _blinkAnim,
                builder: (_, __) => Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: statusColor.withOpacity(0.5),
                          blurRadius: 4)
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isStreamingReady
                            ? 'Live • AI Detection Active'
                            : 'Pi Online • Idle',
                        style: AppText.bodyS(color: statusColor)),
                    Text(
                        isStreamingReady
                            ? 'Latest Pi frame preview'
                            : 'Start detection to preview the camera',
                        style: AppText.bodyS(color: AppColors.textMuted)),
                  ],
                ),
              ),
              // AI badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isStreamingReady ? AppColors.brand : Colors.orange)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          (isStreamingReady ? AppColors.brand : Colors.orange)
                              .withOpacity(0.4)),
                ),
                child: Row(children: [
                  Icon(
                      isStreamingReady
                          ? Icons.auto_awesome
                          : Icons.pause_circle_outline,
                      color:
                          isStreamingReady ? AppColors.brand : Colors.orange,
                      size: 12),
                  const SizedBox(width: 4),
                  Text(isStreamingReady ? 'AI' : 'IDLE',
                      style: AppText.bodyS(
                          color: isStreamingReady
                              ? AppColors.brand
                              : Colors.orange)),
                ]),
              ),
              const SizedBox(width: 8),
              // Cloud sync
              Icon(isStreamingReady ? Icons.cloud_done : Icons.cloud_queue,
                  color: statusColor, size: 18),
              const SizedBox(width: 10),
              // Settings
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PiCameraSettingsScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.settings_outlined,
                      color: AppColors.textSecondary, size: 18),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCAN LINE PAINTER — for Pi camera preview
// ─────────────────────────────────────────────

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Corner brackets
    final bracketPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const len = 20.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bx = cx - 40;
    final by = cy - 40;

    // Top left bracket
    canvas.drawLine(Offset(bx, by), Offset(bx + len, by), bracketPaint);
    canvas.drawLine(Offset(bx, by), Offset(bx, by + len), bracketPaint);

    // Top right bracket
    canvas.drawLine(
        Offset(bx + 80, by), Offset(bx + 80 - len, by), bracketPaint);
    canvas.drawLine(
        Offset(bx + 80, by), Offset(bx + 80, by + len), bracketPaint);

    // Bottom left bracket
    canvas.drawLine(
        Offset(bx, by + 80), Offset(bx + len, by + 80), bracketPaint);
    canvas.drawLine(
        Offset(bx, by + 80), Offset(bx, by + 80 - len), bracketPaint);

    // Bottom right bracket
    canvas.drawLine(
        Offset(bx + 80, by + 80), Offset(bx + 80 - len, by + 80), bracketPaint);
    canvas.drawLine(
        Offset(bx + 80, by + 80), Offset(bx + 80, by + 80 - len), bracketPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => false;
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

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
    final paint = Paint()..color = AppColors.brand.withOpacity(0.45);
    final rng = Random(7);
    for (int i = 0; i < 50; i++) {
      final x = rng.nextDouble() * size.width;
      final y =
          ((rng.nextDouble() * size.height) + progress * 110) % size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 2.0 + 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
