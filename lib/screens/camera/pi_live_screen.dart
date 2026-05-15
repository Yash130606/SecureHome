import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../services/pi_service.dart';

enum _LiveViewState {
  loading,
  offline,
  detectionStopped,
  error,
  streaming,
}

class PiLiveScreen extends StatefulWidget {
  const PiLiveScreen({super.key});

  @override
  State<PiLiveScreen> createState() => _PiLiveScreenState();
}

class _PiLiveScreenState extends State<PiLiveScreen> {
  Uint8List? _frameBytes;
  _LiveViewState _viewState = _LiveViewState.loading;
  bool _running = true;
  bool _startingDetection = false;
  int _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  StreamSubscription<List<int>>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_startStream());
  }

  @override
  void dispose() {
    _running = false;
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _captureSnapshot() async {
    if (_frameBytes == null) return;

    try {
      await PiService.saveSnapshot();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Snapshot saved!'),
            ],
          ),
          backgroundColor: AppColors.accentGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startStream() async {
    await _sub?.cancel();
    if (!mounted || !_running) return;

    setState(() {
      _frameBytes = null;
      _fps = 0;
      _frameCount = 0;
      _lastFpsTime = DateTime.now();
      _viewState = _LiveViewState.loading;
    });

    final app = context.read<AppProvider>();
    await app.refreshFromPi();
    if (!mounted || !_running) return;

    if (!app.piConnected || PiService.streamUrl.isEmpty) {
      setState(() => _viewState = _LiveViewState.offline);
      return;
    }

    if (!app.piRunning) {
      setState(() => _viewState = _LiveViewState.detectionStopped);
      return;
    }

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(PiService.streamUrl));
      final response =
          await client.send(request).timeout(const Duration(seconds: 10));

      if (!mounted || !_running) return;

      if (response.statusCode != 200) {
        setState(() => _viewState = _LiveViewState.error);
        client.close();
        return;
      }

      List<int> buffer = [];

      _sub = response.stream.listen(
        (chunk) {
          if (!_running || !mounted) return;
          buffer.addAll(chunk);

          while (true) {
            final start = _indexOf(buffer, const [0xFF, 0xD8]);
            final end = _indexOf(buffer, const [0xFF, 0xD9]);

            if (start == -1 || end == -1 || end <= start) break;

            final jpeg = buffer.sublist(start, end + 2);
            buffer = buffer.sublist(end + 2);

            setState(() {
              _frameBytes = Uint8List.fromList(jpeg);
              _frameCount++;
              _viewState = _LiveViewState.streaming;
            });

            final now = DateTime.now();
            final diff = now.difference(_lastFpsTime).inMilliseconds;
            if (diff >= 1000) {
              setState(() {
                _fps = (_frameCount * 1000 / diff).round();
                _frameCount = 0;
                _lastFpsTime = now;
              });
            }
          }
        },
        onError: (_) => _handleStreamDrop(),
        onDone: _handleStreamDrop,
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _viewState = _LiveViewState.error);
    }
  }

  void _handleStreamDrop() {
    if (!mounted || !_running) return;

    setState(() {
      _frameBytes = null;
      _viewState = _LiveViewState.error;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!_running || !mounted) return;
      unawaited(_startStream());
    });
  }

  Future<void> _startDetectionAndRetry() async {
    setState(() => _startingDetection = true);
    final app = context.read<AppProvider>();
    final ok = await app.startPiDetection();
    if (!mounted) return;
    if (!ok) {
      setState(() => _startingDetection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start the detection engine'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _startingDetection = false);
    await _startStream();
  }

  int _indexOf(List<int> data, List<int> pattern) {
    for (int i = 0; i <= data.length - pattern.length; i++) {
      var found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  void _retry() {
    unawaited(_startStream());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final showLiveMeta =
            _viewState == _LiveViewState.streaming || _frameBytes != null;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Live Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  !app.piConnected
                      ? 'Pi offline'
                      : app.piRunning
                          ? 'Pi online | detection active'
                          : 'Pi online | detection stopped',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              if (showLiveMeta)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      '$_fps FPS',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                onPressed: _retry,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildBody(app)),
              if (showLiveMeta) _buildStatusBar(app),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(AppProvider app) {
    switch (_viewState) {
      case _LiveViewState.loading:
        return _buildLoading();
      case _LiveViewState.offline:
        return _buildStateCard(
          icon: Icons.router_outlined,
          title: 'Pi Offline',
          message: 'Cannot reach the Raspberry Pi. Check the Pi IP and make sure '
              'the API server is running.',
          primaryLabel: 'Retry',
          onPrimary: _retry,
        );
      case _LiveViewState.detectionStopped:
        return _buildStateCard(
          icon: Icons.play_circle_outline,
          title: 'Detection Stopped',
          message: 'The Pi is online, but the detection engine is not running yet. '
              'Start it to receive the live feed.',
          primaryLabel: _startingDetection ? 'Starting...' : 'Start Detection',
          onPrimary: _startingDetection ? null : _startDetectionAndRetry,
          secondaryLabel: 'Retry',
          onSecondary: _retry,
        );
      case _LiveViewState.error:
        return _buildStateCard(
          icon: Icons.videocam_off_outlined,
          title: 'Camera Unavailable',
          message: app.piConnected
              ? 'The Pi is reachable, but the live stream is not available right now.'
              : 'Cannot connect to the Pi camera.',
          primaryLabel: 'Retry',
          onPrimary: _retry,
        );
      case _LiveViewState.streaming:
        return _buildStream();
    }
  }

  Widget _buildStream() {
    if (_frameBytes == null) {
      return _buildLoading();
    }

    return Stack(
      children: [
        Center(
          child: Image.memory(
            _frameBytes!,
            gaplessPlayback: true,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _captureSnapshot,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.black, size: 28),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _timestamp(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentGreen,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Connecting to camera...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            PiService.streamUrl,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    required String primaryLabel,
    required VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white70, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              PiService.streamUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onPrimary,
                  icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
                  label: Text(
                    primaryLabel,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.24)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onSecondary,
                    child: Text(
                      secondaryLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(AppProvider app) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF0A0A0A),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _frameBytes != null ? AppColors.accentGreen : Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _frameBytes != null ? 'Stream Active' : 'Buffering...',
            style: TextStyle(
              color: _frameBytes != null ? AppColors.accentGreen : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(
            app.piConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: Colors.white24,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            app.piConnected ? 'Pi Online' : 'Pi Offline',
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.videocam_outlined, color: Colors.white24, size: 14),
          const SizedBox(width: 4),
          const Text(
            'Pi Camera',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
