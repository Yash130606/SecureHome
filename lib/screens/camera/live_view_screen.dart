// lib/screens/camera/live_view_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/camera_model.dart';
import '../../providers/app_provider.dart';
import '../../widgets/status_badge.dart';
import 'camera_settings_screen.dart';

class LiveViewScreen extends StatefulWidget {
  final CameraModel camera;
  const LiveViewScreen({super.key, required this.camera});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> with TickerProviderStateMixin {
  bool _cameraOn = true;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _showPtz = false;
  bool _nightVisionOn = false;
  bool _showSnapshotPreview = false;
  String? _lastSnapshotUrl;

  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  String _quality = '1080p';
  String _timestamp = '';

  double _zoomLevel = 1.0;

  Timer? _clockTimer;
  Timer? _hideTimer;
  Timer? _motionTimer;
  Timer? _snapshotTimer;

  late AnimationController _recCtrl;
  late AnimationController _motionAlertCtrl;
  late AnimationController _snapshotCtrl;
  late Animation<double> _motionAlertScale;
  late Animation<double> _snapshotSlide;

  bool _motionAlert = false;

  @override
  void initState() {
    super.initState();
    _cameraOn = widget.camera.isOn;
    _nightVisionOn = widget.camera.nightVision;
    _quality = widget.camera.videoQuality;

    _recCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);

    _motionAlertCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _motionAlertScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _motionAlertCtrl, curve: Curves.elasticOut),
    );

    _snapshotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _snapshotSlide = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _snapshotCtrl, curve: Curves.easeOutCubic),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _timestamp = _formatTime());
    });

    // Only fire motion alerts when camera is ON
    _motionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_cameraOn && mounted) {
        setState(() => _motionAlert = true);
        _motionAlertCtrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _motionAlert = false);
        });
      }
    });
  }

  String _formatTime() {
    final now = DateTime.now();
    final h = _p(now.hour), m = _p(now.minute), s = _p(now.second);
    return '$h:$m:$s';
  }

  String _p(int v) => v.toString().padLeft(2, '0');

  String get _recordingDuration {
    final h = _p(_recordingSeconds ~/ 3600);
    final m = _p((_recordingSeconds % 3600) ~/ 60);
    final s = _p(_recordingSeconds % 60);
    return '$h:$m:$s';
  }

  void _autoHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _autoHideControls();
  }

  void _toggleCamera() {
    final prov = context.read<AppProvider>();
    final newVal = !_cameraOn;
    setState(() {
      _cameraOn = newVal;
      if (!newVal && _isRecording) _stopRecording(); // stop recording if camera goes off
    });
    // Sync to provider
    prov.updateCamera(widget.camera.id, widget.camera.copyWith(isOn: newVal));
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() { _isRecording = true; _recordingSeconds = 0; });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    _snackbar('Recording saved (${_recordingDuration})');
  }

  void _takeSnapshot() {
    // Show animated preview thumbnail
    setState(() {
      _lastSnapshotUrl = widget.camera.thumb;
      _showSnapshotPreview = true;
    });
    _snapshotCtrl.forward(from: 0);
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _snapshotCtrl.reverse().then((_) {
          if (mounted) setState(() => _showSnapshotPreview = false);
        });
      }
    });
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _qualityDialog(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text('Video Quality', style: AppText.h3()),
        const SizedBox(height: 8),
        ...['360p', '720p', '1080p', '4K'].map((q) => ListTile(
          title: Text(q, style: AppText.bodyM(color: AppColors.textPrimary)),
          trailing: q == _quality ? const Icon(Icons.check, color: AppColors.brand) : null,
          onTap: () { setState(() => _quality = q); Navigator.pop(ctx); },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _snackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _hideTimer?.cancel();
    _motionTimer?.cancel();
    _recordingTimer?.cancel();
    _snapshotTimer?.cancel();
    _recCtrl.dispose();
    _motionAlertCtrl.dispose();
    _snapshotCtrl.dispose();
    // Restore orientation and UI on dispose
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(children: [

          // ── Camera feed ───────────────────────────────────────────────
          Positioned.fill(
            child: _cameraOn
                ? Transform.scale(
                    scale: _zoomLevel,
                    child: Stack(children: [
                      Image.network(widget.camera.thumb, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      // Scan line overlay
                      Positioned.fill(child: CustomPaint(painter: _ScanLinePainter())),
                      // Night vision green tint
                      if (_nightVisionOn)
                        Positioned.fill(child: Container(color: const Color(0x2200FF44))),
                    ]),
                  )
                : const _BlackScreen(),
          ),

          // ── Top bar (auto-hide) ───────────────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12, right: 12, bottom: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(children: [
                  _CircleBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.camera.name, style: AppText.h3()),
                    Text(widget.camera.zone, style: AppText.bodyS()),
                  ])),
                  _CircleBtn(
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CameraSettingsScreen(cameraId: widget.camera.id),
                    )),
                  ),
                  const SizedBox(width: 8),
                  _CircleBtn(
                    icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    onTap: _toggleCamera,
                  ),
                ]),
              ),
            ),
          ),

          // ── Timestamp & badges ────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            child: Row(children: [
              if (_isRecording) ...[
                AnimatedBuilder(
                  animation: _recCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _recCtrl.value,
                    child: const RecordingBadge(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(_recordingDuration, style: AppText.mono(color: AppColors.accentRed, size: 11)),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(_timestamp, style: AppText.mono(color: Colors.white70, size: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(_quality, style: AppText.mono(color: AppColors.brand, size: 11)),
              ),
            ]),
          ),

          // ── Motion alert popup ────────────────────────────────────────
          if (_motionAlert)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: ScaleTransition(
                scale: _motionAlertScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Motion Detected', style: AppText.label(color: Colors.white, size: 11)),
                  ]),
                ),
              ),
            ),

          // ── PTZ Controls overlay ──────────────────────────────────────
          if (_showPtz && widget.camera.ptzSupported)
            Positioned(
              bottom: 160,
              left: 16,
              child: _PtzPad(onDirection: (dir) => _snackbar('PTZ: $dir')),
            ),

          // ── Snapshot preview pop-up ───────────────────────────────────
          if (_showSnapshotPreview && _lastSnapshotUrl != null)
            Positioned(
              bottom: 160,
              right: 16,
              child: AnimatedBuilder(
                animation: _snapshotSlide,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, 50 * (1 - _snapshotSlide.value)),
                  child: Opacity(
                    opacity: _snapshotSlide.value,
                    child: Container(
                      width: 90, height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.brand, width: 1.5),
                        boxShadow: [BoxShadow(color: AppColors.brand.withOpacity(0.3), blurRadius: 8)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(fit: StackFit.expand, children: [
                          Image.network(_lastSnapshotUrl!, fit: BoxFit.cover),
                          const Positioned(
                            bottom: 4, right: 4,
                            child: Icon(Icons.check_circle, color: Colors.white, size: 14),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom controls (auto-hide) ───────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 16, right: 16, top: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Zoom slider
                  Row(children: [
                    const Icon(Icons.zoom_out, color: Colors.white54, size: 16),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.brand,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: AppColors.brand,
                          trackHeight: 2,
                        ),
                        child: Slider(
                          value: _zoomLevel, min: 1.0, max: 4.0,
                          onChanged: (v) => setState(() => _zoomLevel = v),
                        ),
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text('${_zoomLevel.toStringAsFixed(1)}×', style: AppText.bodyS(color: Colors.white60)),
                  ]),
                  const SizedBox(height: 12),
                  // Main controls row
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _ControlBtn(
                      icon: _isRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
                      label: _isRecording ? 'Stop' : 'Record',
                      active: _isRecording,
                      activeColor: AppColors.accentRed,
                      onTap: _cameraOn ? _toggleRecording : null,
                    ),
                    _ControlBtn(
                      icon: Icons.camera_alt_outlined,
                      label: 'Snapshot',
                      onTap: _cameraOn ? _takeSnapshot : null,
                    ),
                    _ControlBtn(
                      icon: _isMuted ? Icons.mic_off_outlined : Icons.mic_outlined,
                      label: _isMuted ? 'Muted' : 'Audio',
                      active: !_isMuted,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                    ),
                    _ControlBtn(
                      icon: _nightVisionOn ? Icons.nightlight_round : Icons.nightlight_outlined,
                      label: 'Night',
                      active: _nightVisionOn,
                      activeColor: AppColors.accentGreen,
                      onTap: () => setState(() => _nightVisionOn = !_nightVisionOn),
                    ),
                    if (widget.camera.ptzSupported)
                      _ControlBtn(
                        icon: Icons.gamepad_outlined,
                        label: 'PTZ',
                        active: _showPtz,
                        onTap: () => setState(() => _showPtz = !_showPtz),
                      ),
                    _ControlBtn(
                      icon: Icons.hd_outlined,
                      label: _quality,
                      onTap: () => _qualityDialog(context),
                    ),
                    _ControlBtn(
                      icon: _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      label: 'Full',
                      onTap: _toggleFullscreen,
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── PTZ D-Pad ─────────────────────────────────────────────────────────────────
class _PtzPad extends StatelessWidget {
  final ValueChanged<String> onDirection;
  const _PtzPad({required this.onDirection});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130, height: 130,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PtzBtn(icon: Icons.keyboard_arrow_up, onTap: () => onDirection('Up')),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _PtzBtn(icon: Icons.keyboard_arrow_left, onTap: () => onDirection('Left')),
          const SizedBox(width: 28),
          _PtzBtn(icon: Icons.keyboard_arrow_right, onTap: () => onDirection('Right')),
        ]),
        _PtzBtn(icon: Icons.keyboard_arrow_down, onTap: () => onDirection('Down')),
      ]),
    );
  }
}

class _PtzBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PtzBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.bgHighlight, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 20),
    ),
  );
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────
class _BlackScreen extends StatelessWidget {
  const _BlackScreen();
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.videocam_off_rounded, color: AppColors.textMuted, size: 48),
      const SizedBox(height: 12),
      Text('Camera Off', style: AppText.bodyM()),
    ])),
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;

  const _ControlBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.activeColor = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Colors.white24 : (active ? activeColor : Colors.white70);
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active ? activeColor.withOpacity(0.15) : Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? activeColor.withOpacity(0.4) : Colors.transparent),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppText.caption(color: color)),
      ]),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.04)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}