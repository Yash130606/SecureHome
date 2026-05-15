import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../services/pi_service.dart';

class FaceDatabaseScreen extends StatefulWidget {
  const FaceDatabaseScreen({super.key});

  @override
  State<FaceDatabaseScreen> createState() => _FaceDatabaseScreenState();
}

class _FaceDatabaseScreenState extends State<FaceDatabaseScreen> {
  static const int _requiredMobileShots = 5;
  bool _loading = true;
  bool _working = false;
  String _searchQuery = '';
  String? _progressTitle;
  String? _progressDetail;
  List<Map<String, dynamic>> _faces = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    setState(() => _loading = true);
    final app = context.read<AppProvider>();
    await app.refreshFromPi();
    if (!mounted) return;

    if (!app.piConnected) {
      setState(() {
        _faces = [];
        _loading = false;
      });
      return;
    }

    final faces = await PiService.getKnownFaces();
    if (!mounted) return;
    setState(() {
      _faces = faces
          .whereType<Map>()
          .map((face) => Map<String, dynamic>.from(face))
          .toList()
        ..sort((a, b) => _faceName(a).compareTo(_faceName(b)));
      _loading = false;
    });
  }

  Future<void> _deleteFace(String name) async {
    if (_working) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text('Delete $name?', style: AppText.h3()),
            content: Text(
              'This will remove the person from the Pi face database. You can add them again later from the app.',
              style: AppText.bodyM(color: AppColors.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _working = true);
    final ok = await PiService.deleteFace(name);
    if (!mounted) return;

    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '$name removed from the Pi database' : 'Could not delete $name',
        ),
        backgroundColor: ok ? AppColors.accentGreen : AppColors.accentRed,
      ),
    );

    if (ok) {
      await _loadFaces();
    }
  }

  Future<void> _showAddPersonSheet() async {
    await _showFaceCaptureSheet();
  }

  Future<void> _showFaceCaptureSheet({String? existingName}) async {
    final app = context.read<AppProvider>();
    if (_working) return;

    if (!app.piConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to the Raspberry Pi first.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    final controller = TextEditingController(text: existingName ?? '');
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Person', style: AppText.h3()),
              if (existingName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Capture fresh phone photos to retrain $existingName.',
                  style: AppText.bodyM(color: AppColors.textMuted),
                ),
              ] else ...[
              const SizedBox(height: 8),
              Text(
                'Enter a name, then use your phone camera to capture a few face photos for training.',
                style: AppText.bodyM(color: AppColors.textMuted),
              ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppText.bodyM(),
                decoration: InputDecoration(
                  hintText: 'Person name',
                  hintStyle: AppText.bodyM(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                      ),
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Use Phone Camera'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;
    await _registerFace(name.trim());
  }

  Future<void> _retrainDatabase() async {
    if (_working) return;
    setState(() {
      _working = true;
      _progressTitle = 'Retraining face database';
      _progressDetail = 'Running training on the Raspberry Pi...';
    });

    final result = await PiService.retrainFaces();
    if (!mounted) return;

    setState(() {
      _working = false;
      _progressTitle = null;
      _progressDetail = null;
    });

    final ok = result['success'] == true;
    final message = ok
        ? 'Face database retrained successfully'
        : (result['error']?.toString() ?? 'Failed to retrain face database');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.accentGreen : AppColors.accentRed,
      ),
    );

    if (ok) {
      await _loadFaces();
    }
  }

  Future<void> _registerFace(String name) async {
    setState(() {
      _working = true;
      _progressTitle = 'Preparing phone capture';
      _progressDetail = 'We will collect $_requiredMobileShots photos for $name.';
    });

    final images = <XFile>[];

    for (var i = 0; i < _requiredMobileShots; i++) {
      if (!mounted) return;
      setState(() {
        _progressTitle = 'Capture phone photos';
        _progressDetail =
            'Photo ${i + 1} of $_requiredMobileShots for $name. Keep the face centered and vary the angle slightly.';
      });

      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (shot == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face registration cancelled.'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
        setState(() {
          _working = false;
          _progressTitle = null;
          _progressDetail = null;
        });
        return;
      }

      images.add(shot);
    }

    setState(() {
      _progressTitle = 'Uploading photos';
      _progressDetail = 'Sending ${images.length} phone photos to the Pi.';
    });

    final result = await PiService.uploadFaceImages(
      name,
      images.map((image) => File(image.path)).toList(),
    );
    if (!mounted) return;

    setState(() {
      _working = false;
      _progressTitle = null;
      _progressDetail = null;
    });

    final ok = result['success'] == true;
    final captured = result['captured'];
    final message = ok
        ? '$name added successfully${captured != null ? ' ($captured samples)' : ''}'
        : (result['error']?.toString() ?? 'Face registration failed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.accentGreen : AppColors.accentRed,
        duration: const Duration(seconds: 4),
      ),
    );

    if (ok) {
      await _loadFaces();
    }
  }

  List<Map<String, dynamic>> get _filteredFaces {
    if (_searchQuery.trim().isEmpty) return _faces;
    final query = _searchQuery.toLowerCase();
    return _faces
        .where((face) => _faceName(face).toLowerCase().contains(query))
        .toList();
  }

  int get _totalPhotos => _faces.fold<int>(
        0,
        (sum, face) => sum + ((face['photos'] as num?)?.toInt() ?? 0),
      );

  String _faceName(Map<String, dynamic> face) =>
      '${face['name'] ?? 'Unknown'}'.trim();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Face Database', style: AppText.h3()),
        actions: [
          IconButton(
            onPressed: _working ? null : _showAddPersonSheet,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            onPressed: _working ? null : _retrainDatabase,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Retrain faces',
          ),
          IconButton(
            onPressed: _loading ? null : _loadFaces,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _FaceDatabaseHeader(
            piConnected: app.piConnected,
            faceCount: _faces.length,
            photoCount: _totalPhotos,
            isBusy: _working,
            progressTitle: _progressTitle,
            progressDetail: _progressDetail,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: AppText.bodyM(),
                decoration: InputDecoration(
                  hintText: 'Search registered people',
                  hintStyle: AppText.bodyM(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(app)),
        ],
      ),
    );
  }

  Widget _buildBody(AppProvider app) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!app.piConnected) {
      return _buildEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Pi Offline',
        message:
            'Connect to the Raspberry Pi to load and manage registered faces.',
      );
    }

    if (_faces.isEmpty) {
      return _buildEmptyState(
        icon: Icons.face_retouching_natural,
        title: 'No registered faces yet',
        message:
            'Known people will appear here once face registration is added from the app.',
      );
    }

    if (_filteredFaces.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches found',
        message: 'Try a different name in the search bar.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFaces,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _filteredFaces.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final face = _filteredFaces[index];
          final name = _faceName(face);
          final photos = (face['photos'] as num?)?.toInt() ?? 0;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.face_outlined,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppText.bodyM().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$photos training photo${photos == 1 ? '' : 's'} available on Pi',
                        style: AppText.bodyS(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accentGreen.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Known',
                    style: AppText.bodyS(color: AppColors.accentGreen),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  enabled: !_working,
                  onSelected: (value) async {
                    if (value == 'retrain') {
                      await _showFaceCaptureSheet(existingName: name);
                    } else if (value == 'delete') {
                      await _deleteFace(name);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'retrain',
                      child: Row(
                        children: [
                          Icon(Icons.cameraswitch_outlined),
                          SizedBox(width: 10),
                          Text('Recapture & retrain'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.accentRed),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: AppText.h2()),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppText.bodyM(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceDatabaseHeader extends StatelessWidget {
  final bool piConnected;
  final int faceCount;
  final int photoCount;
  final bool isBusy;
  final String? progressTitle;
  final String? progressDetail;

  const _FaceDatabaseHeader({
    required this.piConnected,
    required this.faceCount,
    required this.photoCount,
    required this.isBusy,
    required this.progressTitle,
    required this.progressDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: piConnected
                  ? AppColors.brand.withOpacity(0.12)
                  : AppColors.accentRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              piConnected ? Icons.face_unlock_outlined : Icons.wifi_off_rounded,
              color: piConnected ? AppColors.brand : AppColors.accentRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  piConnected ? 'Registered People on Pi' : 'Pi Connection Required',
                  style: AppText.bodyM().copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  piConnected
                      ? '$faceCount known face${faceCount == 1 ? '' : 's'} • $photoCount training photo${photoCount == 1 ? '' : 's'}'
                      : 'Reconnect the Pi to manage your known faces.',
                  style: AppText.bodyS(color: AppColors.textMuted),
                ),
                if (isBusy) ...[
                  const SizedBox(height: 6),
                  Text(
                    progressTitle ?? 'Registration in progress...',
                    style: AppText.bodyS(color: AppColors.brand),
                  ),
                  if (progressDetail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        progressDetail!,
                        style: AppText.bodyS(color: AppColors.textMuted),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
