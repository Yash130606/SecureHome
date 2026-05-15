import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../services/pi_service.dart';

class SnapshotsScreen extends StatefulWidget {
  const SnapshotsScreen({super.key});

  @override
  State<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends State<SnapshotsScreen> {
  List<dynamic> _snapshots = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final app = context.read<AppProvider>();
    await app.refreshFromPi();

    if (!mounted) return;

    if (!app.piConnected) {
      setState(() {
        _snapshots = [];
        _loading = false;
        _error = 'Pi offline';
      });
      return;
    }

    final data = await PiService.getSnapshots();
    if (!mounted) return;

    setState(() {
      _snapshots = data;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _delete(String filename) async {
    final ok = await PiService.deleteSnapshot(filename);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _snapshots.removeWhere((s) => s['filename'] == filename);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Snapshot deleted'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Failed to delete snapshot'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Snapshots',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _SnapshotsHeader(app: app, count: _snapshots.length),
          Expanded(child: _buildBody(app)),
        ],
      ),
    );
  }

  Widget _buildBody(AppProvider app) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildEmptyState(
        icon: Icons.wifi_off_outlined,
        title: 'Pi Offline',
        message: 'Connect to the Raspberry Pi to load saved snapshots.',
      );
    }

    if (_snapshots.isEmpty) {
      return _buildEmptyState(
        icon: app.piRunning
            ? Icons.photo_library_outlined
            : Icons.pause_circle_outline,
        title: app.piRunning ? 'No snapshots yet' : 'Detection is stopped',
        message: app.piRunning
            ? 'Snapshots appear here when the Pi saves an event.'
            : 'Start detection and capture a snapshot from live view.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _snapshots.length,
        itemBuilder: (_, i) {
          final snapshot = Map<String, dynamic>.from(_snapshots[i]);
          return _SnapshotCard(
            snapshot: snapshot,
            onDelete: () => _delete(snapshot['filename']),
            onTap: () => _showFullImage(context, snapshot),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text(title, style: AppText.h2()),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppText.bodyM(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext ctx, Map<String, dynamic> snap) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => _FullImageScreen(snapshot: snap)),
    );
  }
}

class _SnapshotsHeader extends StatelessWidget {
  final AppProvider app;
  final int count;

  const _SnapshotsHeader({required this.app, required this.count});

  @override
  Widget build(BuildContext context) {
    final statusLabel = !app.piConnected
        ? 'Pi offline'
        : app.piRunning
            ? 'Live detection active'
            : 'Detection stopped';
    final statusColor = !app.piConnected
        ? Colors.orange
        : app.piRunning
            ? AppColors.accentGreen
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusLabel, style: AppText.bodyM()),
                Text(
                  '$count snapshot${count == 1 ? '' : 's'} available',
                  style: AppText.bodyS(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SnapshotCard({
    required this.snapshot,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = PiService.snapshotUrl(snapshot['filename']);
    final type = (snapshot['type'] ?? 'snapshot').toString();
    final isPerson = type == 'person';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isPerson ? Colors.red.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppColors.bg,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.bg,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPerson ? Colors.red : AppColors.brand,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPerson ? 'PERSON' : 'SNAPSHOT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _snapshotPrimary(snapshot),
                          style: AppText.bodyM().copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _snapshotSecondary(snapshot),
                          style: AppText.bodyS(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.open_in_full,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _snapshotPrimary(Map<String, dynamic> snapshot) {
    final time = (snapshot['time'] ?? '').toString();
    final camera = (snapshot['camera'] ?? 'Pi Camera').toString();
    return time.isNotEmpty ? '$camera • $time' : camera;
  }

  String _snapshotSecondary(Map<String, dynamic> snapshot) {
    final date = (snapshot['date'] ?? '').toString();
    final sizeKb = snapshot['size_kb'];
    final sizeText = sizeKb == null ? '' : ' • ${sizeKb}KB';
    return '${date.isEmpty ? 'Saved on Pi' : date}$sizeText';
  }
}

class _FullImageScreen extends StatelessWidget {
  final Map<String, dynamic> snapshot;

  const _FullImageScreen({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final url = PiService.snapshotUrl(snapshot['filename']);
    final title = _fullTitle(snapshot);
    final subtitle = _fullSubtitle(snapshot);

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
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator();
            },
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }

  String _fullTitle(Map<String, dynamic> snapshot) {
    final camera = (snapshot['camera'] ?? 'Pi Camera').toString();
    final time = (snapshot['time'] ?? '').toString();
    return time.isNotEmpty ? '$camera • $time' : camera;
  }

  String _fullSubtitle(Map<String, dynamic> snapshot) {
    final date = (snapshot['date'] ?? '').toString();
    final type = (snapshot['type'] ?? 'snapshot').toString();
    return '${date.isEmpty ? 'Saved on Pi' : date} • ${type.toUpperCase()}';
  }
}
