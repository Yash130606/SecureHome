// lib/screens/history/history_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/recording_model.dart';
import '../../providers/app_provider.dart';
import 'snapshots_screen.dart';
import '../../services/pi_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _month = 'October 2023';

  // Storage display values
  final String _storageUsed = '50';
  final String _storageTotal = '100';

  // Simulated event type filter
  String _typeFilter = 'All';
  final List<String> _typeOptions = ['All', 'Person', 'Motion', 'Alert'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.piConnected) {
        provider.refreshFromPi();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showDeleteConfirm() {
    showModalBottomSheet(
      context: context,
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
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Delete Recordings', style: AppText.h2()),
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
                    'This will permanently delete selected recordings. This cannot be undone.',
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Delete',
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
                  onPressed: () => Navigator.pop(context),
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

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
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
                  color: AppColors.brand.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.ios_share_rounded,
                    color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Export', style: AppText.h2()),
            ]),
            const SizedBox(height: 16),
            _ExportOption(
              icon: Icons.download_outlined,
              label: 'Download to Device',
              subtitle: 'Save clips to your phone storage',
              color: AppColors.brand,
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.cloud_upload_outlined,
              label: 'Upload to Cloud',
              subtitle: 'Backup to your cloud storage',
              color: Colors.teal,
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.share_outlined,
              label: 'Share',
              subtitle: 'Send via messages, email or apps',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    var recs = prov.filteredRecordings;
    // FIX: apply type filter locally too
    if (_typeFilter != 'All') {
      recs = recs.where((r) => r.type == _typeFilter.toLowerCase()).toList();
    }
    // FIX: stats from real data, not hardcoded
    final totalClips = recs.length;
    final personClips = recs.where((r) => r.type == 'person').length;
    final motionClips = recs.where((r) => r.type == 'motion').length;
    final cameras = prov.cameraNames;
    final storagePercent = (int.tryParse(_storageUsed) ?? 50) /
        (int.tryParse(_storageTotal) ?? 100);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          /// PARTICLE BACKGROUND
          const Positioned.fill(child: _HistoryParticleBackground()),

          SafeArea(
            child: Column(
              children: [
                // ── HEADER ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recordings & History',
                            style: AppText.bodyM(color: AppColors.textMuted)),
                        Text('History', style: AppText.h1()),
                      ],
                    ),
                    const Spacer(),
                    // Storage pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cloud_outlined,
                            color: AppColors.brand, size: 14),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$_storageUsed / $_storageTotal GB',
                                style: AppText.label(
                                    color: AppColors.brand, size: 10)),
                            const SizedBox(height: 4),
                            Stack(children: [
                              Container(
                                width: 64,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                width: 64 * storagePercent,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: storagePercent > 0.8
                                      ? Colors.red
                                      : AppColors.brand,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined,
                          color: Colors.white),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SnapshotsScreen())),
                      tooltip: 'Snapshots',
                    ),
                  ]),
                ),

                // ── SUMMARY STATS BAR ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _MiniStat(
                      label: 'Total Clips',
                      value: '$totalClips',
                      icon: Icons.movie_outlined,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: 'Person',
                      value: '$personClips',
                      icon: Icons.person_outlined,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: 'Motion',
                      value: '$motionClips',
                      icon: Icons.directions_run,
                      color: Colors.orange,
                    ),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── FILTERS ROW ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    // Camera filter
                    _FilterPill(
                      icon: Icons.videocam_outlined,
                      value: prov.recordingFilter,
                      items: cameras,
                      onChanged: prov.setRecordingFilter,
                    ),
                    const SizedBox(width: 8),
                    // Type filter
                    _TypeFilterPill(
                      value: _typeFilter,
                      options: _typeOptions,
                      onChanged: (v) => setState(() => _typeFilter = v),
                    ),
                    const SizedBox(width: 8),
                    // Month nav
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.chevron_left,
                                  color: AppColors.textSecondary, size: 18),
                            ),
                            Text(_month,
                                style: AppText.bodyS(
                                    color: AppColors.textPrimary)),
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── TABS ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withOpacity(0.2),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      labelStyle: AppText.btn(color: Colors.white)
                          .copyWith(fontSize: 13),
                      unselectedLabelStyle:
                          AppText.bodyM(color: AppColors.textMuted)
                              .copyWith(fontWeight: FontWeight.w500),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textMuted,
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.all(4),
                      tabs: const [
                        Tab(text: 'Recordings'),
                        Tab(text: 'Saved Images'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── CONTENT ─────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ── RECORDINGS GRID
                      recs.isEmpty
                          ? _EmptyState(
                              icon: Icons.movie_outlined,
                              message: prov.piConnected
                                  ? 'No smart recordings yet'
                                  : 'Pi connection required',
                              sub: prov.piConnected
                                  ? 'Trigger a motion or person event to save clips automatically'
                                  : 'Reconnect the Pi to sync recorded event clips',
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.60,
                              ),
                              itemCount: recs.length,
                              itemBuilder: (_, i) =>
                                  _RecordingTile(rec: recs[i]),
                            ),

                      // ── SAVED IMAGES — Real Pi Snapshots
                      const _PiSnapshotsTab(),
                    ],
                  ),
                ),

                // ── BOTTOM ACTION BAR ────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(children: [
                    // Pagination
                    Row(children: [
                      _BottomBtn(
                          icon: Icons.skip_previous_rounded,
                          label: 'Prev',
                          onTap: () {}),
                      const SizedBox(width: 14),
                      _BottomBtn(
                          icon: Icons.skip_next_rounded,
                          label: 'Next',
                          onTap: () {}),
                    ]),
                    const Spacer(),
                    // Actions
                    _BottomBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      onTap: _showDeleteConfirm,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 20),
                    _BottomBtn(
                      icon: Icons.ios_share_rounded,
                      label: 'Export',
                      onTap: _showExportSheet,
                      color: AppColors.brand,
                    ),
                  ]),
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
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 30),
          ),
          const SizedBox(height: 14),
          Text(message,
              style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub,
              style: AppText.bodyS(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINI STAT CARD
// ─────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
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
// FILTER PILLS
// ─────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterPill({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 14),
            const SizedBox(width: 5),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                dropdownColor: AppColors.bgSurface,
                style: AppText.bodyM(color: AppColors.textPrimary)
                    .copyWith(fontSize: 13),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.textMuted, size: 14),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ],
        ),
      );
}

class _TypeFilterPill extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _TypeFilterPill({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list,
                color: AppColors.textSecondary, size: 14),
            const SizedBox(width: 5),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                dropdownColor: AppColors.bgSurface,
                style: AppText.bodyM(color: AppColors.textPrimary)
                    .copyWith(fontSize: 13),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.textMuted, size: 14),
                items: options
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// RECORDING TILE
// ─────────────────────────────────────────────

class _RecordingTile extends StatelessWidget {
  final RecordingModel rec;
  const _RecordingTile({required this.rec});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _RecordingPlayerScreen(recording: rec),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    rec.thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.bgSurface,
                      child: const Icon(Icons.movie_outlined,
                          color: AppColors.textMuted, size: 20),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(rec.duration,
                          style: AppText.label(color: Colors.white, size: 9)),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: rec.type == 'person'
                            ? AppColors.brand.withOpacity(0.85)
                            : Colors.orange.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        rec.type == 'person'
                            ? Icons.person
                            : Icons.directions_run,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rec.date,
            style: AppText.bodyS(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${rec.camera} - ${rec.fileSize}',
                  style: AppText.bodyS(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Icon(
                Icons.play_circle_outline,
                color: AppColors.textMuted,
                size: 12,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordingPlayerScreen extends StatefulWidget {
  final RecordingModel recording;

  const _RecordingPlayerScreen({required this.recording});

  @override
  State<_RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends State<_RecordingPlayerScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final clipUrl = PiService.recordingUrl(widget.recording.filename);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString('''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        background: #000;
        width: 100%;
        height: 100%;
        overflow: hidden;
      }
      video {
        width: 100%;
        height: 100%;
        object-fit: contain;
        background: #000;
      }
    </style>
  </head>
  <body>
    <video controls autoplay playsinline src="$clipUrl"></video>
  </body>
</html>
''');
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recording;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text(rec.camera, style: AppText.h2()),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: AppColors.bgSurface,
            child: Row(
              children: [
                _PlayerInfoChip(
                  icon: Icons.timer_outlined,
                  label: rec.duration,
                ),
                const SizedBox(width: 10),
                _PlayerInfoChip(
                  icon: Icons.sd_storage_outlined,
                  label: rec.fileSize,
                ),
                const SizedBox(width: 10),
                _PlayerInfoChip(
                  icon: rec.type == 'person'
                      ? Icons.person_outline
                      : Icons.directions_run,
                  label: rec.zone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlayerInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.brand, size: 16),
          const SizedBox(width: 6),
          Text(label, style: AppText.bodyS()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SAVED IMAGE TILE
// ─────────────────────────────────────────────

class _SavedImageTile extends StatelessWidget {
  final dynamic rec;
  const _SavedImageTile({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  rec.thumb,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.bgSurface,
                    child: const Icon(Icons.image_not_supported,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                // Timestamp overlay
                Positioned(
                  bottom: 5,
                  left: 5,
                  right: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rec.date,
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(rec.camera,
            style: AppText.bodyS(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        Row(children: [
          Expanded(
            child: Text(
              rec.zone ?? '',
              style: AppText.bodyS(color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.download_outlined,
                color: AppColors.textMuted, size: 11),
          ),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// EXPORT OPTION ROW
// ─────────────────────────────────────────────

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const _ExportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: AppText.bodyS(color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM ACTION BUTTON
// ─────────────────────────────────────────────

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final Color? color;

  const _BottomBtn({
    required this.icon,
    required this.onTap,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? AppColors.textPrimary, size: 22),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(label!,
                  style: AppText.label(size: 9)
                      .copyWith(color: color ?? AppColors.textMuted)),
            ],
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// PARTICLE BACKGROUND
// ─────────────────────────────────────────────

class _HistoryParticleBackground extends StatefulWidget {
  const _HistoryParticleBackground();

  @override
  State<_HistoryParticleBackground> createState() =>
      _HistoryParticleBackgroundState();
}

class _HistoryParticleBackgroundState extends State<_HistoryParticleBackground>
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
        painter: _HistoryParticlePainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PI SNAPSHOTS TAB
// ─────────────────────────────────────────────

class _PiSnapshotsTab extends StatefulWidget {
  const _PiSnapshotsTab();

  @override
  State<_PiSnapshotsTab> createState() => _PiSnapshotsTabState();
}

class _PiSnapshotsTabState extends State<_PiSnapshotsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _snapshots = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final app = context.read<AppProvider>();
    await app.refreshFromPi();
    if (!mounted) return;
    if (!app.piConnected) {
      setState(() {
        _snapshots = [];
        _loading = false;
      });
      return;
    }
    final data = await PiService.getSnapshots();
    setState(() {
      _snapshots = data;
      _loading = false;
    });
  }

  Future<void> _delete(String filename) async {
    final ok = await PiService.deleteSnapshot(filename);
    if (ok) {
      setState(() => _snapshots.removeWhere((s) => s['filename'] == filename));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_snapshots.isEmpty) {
      final app = context.watch<AppProvider>();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(!app.piConnected
                    ? Icons.wifi_off_outlined
                    : app.piRunning
                        ? Icons.photo_library_outlined
                        : Icons.pause_circle_outline,
                color: AppColors.textMuted, size: 56),
            const SizedBox(height: 14),
            Text(!app.piConnected
                    ? 'Pi offline'
                    : app.piRunning
                        ? 'No snapshots yet'
                        : 'Detection is stopped',
                style: AppText.bodyM().copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(!app.piConnected
                    ? 'Connect to the Raspberry Pi to load snapshots'
                    : app.piRunning
                        ? 'Snapshots from Pi appear here'
                        : 'Start detection or capture a snapshot from live view',
                style: AppText.bodyS(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text('Refresh',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.65,
        ),
        itemCount: _snapshots.length,
        itemBuilder: (_, i) {
          final snap = _snapshots[i];
          final url = PiService.snapshotUrl(snap['filename']);
          final type = snap['type'] ?? 'snapshot';
          final isPerson = type == 'person';

          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _FullSnapshotScreen(snapshot: snap))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, prog) {
                            if (prog == null) return child;
                            return Container(
                                color: AppColors.bgSurface,
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)));
                          },
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.bgSurface,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey, size: 20)),
                        ),

                        // Type badge
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                                color: isPerson ? Colors.red : AppColors.brand,
                                borderRadius: BorderRadius.circular(4)),
                            child: Icon(
                                isPerson ? Icons.person : Icons.camera_alt,
                                color: Colors.white,
                                size: 9),
                          ),
                        ),

                        // Delete button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _delete(snap['filename']),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(5)),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),

                        // Time overlay
                        Positioned(
                          bottom: 5,
                          left: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(snap['time'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 8),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(snap['camera'] ?? 'Pi Camera',
                    style: AppText.bodyS(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
                Text(snap['date'] ?? '',
                    style: AppText.bodyS(color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FULL SNAPSHOT SCREEN
// ─────────────────────────────────────────────

class _FullSnapshotScreen extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  const _FullSnapshotScreen({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final url = PiService.snapshotUrl(snapshot['filename']);
    final time = snapshot['time'] ?? '';
    final date = snapshot['date'] ?? '';

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
            Text(time,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text(date,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, prog) {
                if (prog == null) return child;
                return const CircularProgressIndicator();
              },
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.grey, size: 64)),
        ),
      ),
    );
  }
}

class _HistoryParticlePainter extends CustomPainter {
  final double progress;
  _HistoryParticlePainter(this.progress);

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
    final random = Random(7);

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          ((random.nextDouble() * size.height) + progress * 120) % size.height;
      final radius = random.nextDouble() * 2.0 + 0.8;
      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_HistoryParticlePainter old) => old.progress != progress;
}
