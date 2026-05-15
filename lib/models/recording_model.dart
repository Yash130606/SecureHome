// lib/models/recording_model.dart

class RecordingModel {
  final String id;
  final String cameraId;   // references CameraModel.id (not name string)
  final String camera;     // display name (kept for convenience)
  final String date;       // human-readable display string
  final String duration;
  final String type;       // person | motion
  final String thumb;

  // ── NEW FIELDS ──────────────────────────────────────────────────────────
  final String zone;         // which zone (Exterior / Interior)
  final String fileSize;     // e.g. "14.2 MB"
  final bool isFavourite;    // starred/pinned
  final bool isDownloaded;   // local download state
  final String? alertId;     // linked AlertModel.id
  final String filename;     // backing clip file on Pi
  final DateTime timestamp;  // real DateTime for calendar grouping and sorting

  const RecordingModel({
    required this.id,
    required this.cameraId,
    required this.camera,
    required this.date,
    required this.duration,
    required this.type,
    required this.thumb,
    this.zone = 'Unknown',
    this.fileSize = '0 MB',
    this.isFavourite = false,
    this.isDownloaded = false,
    this.alertId,
    required this.filename,
    required this.timestamp,
  });

  // ── FROM MAP ─────────────────────────────────────────────────────────────
  factory RecordingModel.fromMap(Map<String, dynamic> m) => RecordingModel(
    id: m['id'] as String,
    cameraId: (m['cameraId'] as String?) ?? (m['camera'] as String),
    camera: m['camera'] as String,
    date: m['date'] as String,
    duration: m['duration'] as String,
    type: m['type'] as String,
    thumb: m['thumb'] as String,
    zone: (m['zone'] as String?) ?? 'Unknown',
    fileSize: (m['fileSize'] as String?) ?? '0 MB',
    isFavourite: (m['isFavourite'] as bool?) ?? false,
    isDownloaded: (m['isDownloaded'] as bool?) ?? false,
    alertId: m['alertId'] as String?,
    filename: (m['filename'] as String?) ?? '${m['id']}.mp4',
    timestamp: m['timestamp'] != null
        ? DateTime.tryParse(m['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  // ── TO MAP ───────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id': id, 'cameraId': cameraId, 'camera': camera, 'date': date,
    'duration': duration, 'type': type, 'thumb': thumb,
    'zone': zone, 'fileSize': fileSize, 'isFavourite': isFavourite,
    'isDownloaded': isDownloaded, 'alertId': alertId,
    'filename': filename,
    'timestamp': timestamp.toIso8601String(),
  };

  // ── COPY WITH ─────────────────────────────────────────────────────────────
  RecordingModel copyWith({
    String? cameraId, String? camera, String? date, String? duration,
    String? type, String? thumb, String? zone, String? fileSize,
    bool? isFavourite, bool? isDownloaded, String? alertId, String? filename, DateTime? timestamp,
  }) => RecordingModel(
    id: id,
    cameraId: cameraId ?? this.cameraId,
    camera: camera ?? this.camera,
    date: date ?? this.date,
    duration: duration ?? this.duration,
    type: type ?? this.type,
    thumb: thumb ?? this.thumb,
    zone: zone ?? this.zone,
    fileSize: fileSize ?? this.fileSize,
    isFavourite: isFavourite ?? this.isFavourite,
    isDownloaded: isDownloaded ?? this.isDownloaded,
    alertId: alertId ?? this.alertId,
    filename: filename ?? this.filename,
    timestamp: timestamp ?? this.timestamp,
  );
}
