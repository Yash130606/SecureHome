// lib/models/alert_model.dart

class AlertModel {
  final String id;
  final String type;      // person | motion | system | recording
  final String title;
  final String subtitle;
  final String camera;
  final String time;      // human-readable "2 min ago"
  final bool isRead;
  final String? thumb;

  // ── NEW FIELDS ──────────────────────────────────────────────────────────
  final String zone;      // which zone triggered the alert e.g. "Exterior"
  final String severity;  // low | medium | high
  final String? clipId;   // foreign key to RecordingModel
  final DateTime timestamp; // real DateTime for grouping and sorting

  const AlertModel({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.camera,
    required this.time,
    required this.isRead,
    this.thumb,
    this.zone = 'Unknown',
    this.severity = 'medium',
    this.clipId,
    required this.timestamp,
  });

  // ── COMPUTED ─────────────────────────────────────────────────────────────
  bool get hasThumb => thumb != null && thumb!.isNotEmpty;
  bool get hasClip  => clipId != null && clipId!.isNotEmpty;

  bool get isHighSeverity  => severity == 'high';
  bool get isMediumSeverity => severity == 'medium';
  bool get isLowSeverity   => severity == 'low';

  // ── FROM MAP ─────────────────────────────────────────────────────────────
  factory AlertModel.fromMap(Map<String, dynamic> m) => AlertModel(
    id: m['id'] as String,
    type: m['type'] as String,
    title: m['title'] as String,
    subtitle: m['subtitle'] as String,
    camera: m['camera'] as String,
    time: m['time'] as String,
    isRead: m['isRead'] as bool,
    thumb: m['thumb'] as String?,
    zone: (m['zone'] as String?) ?? 'Unknown',
    severity: (m['severity'] as String?) ?? 'medium',
    clipId: m['clipId'] as String?,
    timestamp: m['timestamp'] != null
        ? DateTime.tryParse(m['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  // ── TO MAP ───────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id': id, 'type': type, 'title': title, 'subtitle': subtitle,
    'camera': camera, 'time': time, 'isRead': isRead, 'thumb': thumb,
    'zone': zone, 'severity': severity, 'clipId': clipId,
    'timestamp': timestamp.toIso8601String(),
  };

  // ── COPY WITH ─────────────────────────────────────────────────────────────
  AlertModel copyWith({
    String? type, String? title, String? subtitle, String? camera,
    String? time, bool? isRead, String? thumb,
    String? zone, String? severity, String? clipId, DateTime? timestamp,
  }) => AlertModel(
    id: id,
    type: type ?? this.type,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    camera: camera ?? this.camera,
    time: time ?? this.time,
    isRead: isRead ?? this.isRead,
    thumb: thumb ?? this.thumb,
    zone: zone ?? this.zone,
    severity: severity ?? this.severity,
    clipId: clipId ?? this.clipId,
    timestamp: timestamp ?? this.timestamp,
  );
}