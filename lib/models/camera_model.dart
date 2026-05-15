// lib/models/camera_model.dart

class CameraModel {
  final String id;
  final String name;
  final String zone;
  final String status;
  final bool isOn;
  final int alerts;
  final bool recording;
  final bool nightVision;
  final bool motionDetection;
  final bool audioRecording;
  final bool personAlerts;
  final bool motionAlerts;
  final bool soundDetection;
  final String videoQuality;
  final String storageLocation;
  final bool continuousRecording;
  final String ip;
  final String firmware;
  final int battery;
  final int signal;
  final String thumb;

  // ── NEW FIELDS ──────────────────────────────────────────────────────────
  final String? lastMotion;        // human-readable "2 min ago" or null
  final DateTime? lastSeen;        // when offline camera was last reachable
  final bool isRecording;          // live recording state (separate from 'recording' setting)
  final bool ptzSupported;         // PTZ controls available
  final bool privacyMask;          // privacy mask enabled

  const CameraModel({
    required this.id,
    required this.name,
    required this.zone,
    required this.status,
    required this.isOn,
    required this.alerts,
    required this.recording,
    required this.nightVision,
    required this.motionDetection,
    required this.audioRecording,
    required this.personAlerts,
    required this.motionAlerts,
    required this.soundDetection,
    required this.videoQuality,
    required this.storageLocation,
    required this.continuousRecording,
    required this.ip,
    required this.firmware,
    required this.battery,
    required this.signal,
    required this.thumb,
    this.lastMotion,
    this.lastSeen,
    this.isRecording = false,
    this.ptzSupported = false,
    this.privacyMask = false,
  });

  // ── COMPUTED ─────────────────────────────────────────────────────────────
  bool get isOnline => status == 'online';
  bool get isBatteryLow => battery < 20;
  bool get isSignalWeak => signal < 30;

  // ── FROM MAP ─────────────────────────────────────────────────────────────
  factory CameraModel.fromMap(Map<String, dynamic> m) => CameraModel(
    id: m['id'] as String,
    name: m['name'] as String,
    zone: m['zone'] as String,
    status: (m['status'] as String).toLowerCase(),   // normalise casing
    isOn: m['isOn'] as bool,
    alerts: m['alerts'] as int,
    recording: m['recording'] as bool,
    nightVision: m['nightVision'] as bool,
    motionDetection: m['motionDetection'] as bool,
    audioRecording: m['audioRecording'] as bool,
    personAlerts: m['personAlerts'] as bool,
    motionAlerts: m['motionAlerts'] as bool,
    soundDetection: m['soundDetection'] as bool,
    videoQuality: m['videoQuality'] as String,
    storageLocation: m['storageLocation'] as String,
    continuousRecording: m['continuousRecording'] as bool,
    ip: m['ip'] as String,
    firmware: m['firmware'] as String,
    battery: m['battery'] as int,
    signal: m['signal'] as int,
    thumb: m['thumb'] as String,
    lastMotion: m['lastMotion'] as String?,
    lastSeen: m['lastSeen'] != null ? DateTime.tryParse(m['lastSeen'] as String) : null,
    isRecording: (m['isRecording'] as bool?) ?? false,
    ptzSupported: (m['ptzSupported'] as bool?) ?? false,
    privacyMask: (m['privacyMask'] as bool?) ?? false,
  );

  // ── TO MAP ───────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'zone': zone, 'status': status, 'isOn': isOn,
    'alerts': alerts, 'recording': recording, 'nightVision': nightVision,
    'motionDetection': motionDetection, 'audioRecording': audioRecording,
    'personAlerts': personAlerts, 'motionAlerts': motionAlerts,
    'soundDetection': soundDetection, 'videoQuality': videoQuality,
    'storageLocation': storageLocation, 'continuousRecording': continuousRecording,
    'ip': ip, 'firmware': firmware, 'battery': battery, 'signal': signal, 'thumb': thumb,
    'lastMotion': lastMotion, 'lastSeen': lastSeen?.toIso8601String(),
    'isRecording': isRecording, 'ptzSupported': ptzSupported, 'privacyMask': privacyMask,
  };

  // ── COPY WITH (ALL FIELDS) ───────────────────────────────────────────────
  CameraModel copyWith({
    String? name, String? zone, String? status, bool? isOn, int? alerts,
    bool? recording, bool? nightVision, bool? motionDetection,
    bool? audioRecording, bool? personAlerts, bool? motionAlerts,
    bool? soundDetection, String? videoQuality, String? storageLocation,
    bool? continuousRecording, String? ip, String? firmware,
    int? battery, int? signal, String? thumb,
    String? lastMotion, DateTime? lastSeen,
    bool? isRecording, bool? ptzSupported, bool? privacyMask,
  }) => CameraModel(
    id: id,
    name: name ?? this.name,
    zone: zone ?? this.zone,
    status: status ?? this.status,
    isOn: isOn ?? this.isOn,
    alerts: alerts ?? this.alerts,
    recording: recording ?? this.recording,
    nightVision: nightVision ?? this.nightVision,
    motionDetection: motionDetection ?? this.motionDetection,
    audioRecording: audioRecording ?? this.audioRecording,
    personAlerts: personAlerts ?? this.personAlerts,
    motionAlerts: motionAlerts ?? this.motionAlerts,
    soundDetection: soundDetection ?? this.soundDetection,
    videoQuality: videoQuality ?? this.videoQuality,
    storageLocation: storageLocation ?? this.storageLocation,
    continuousRecording: continuousRecording ?? this.continuousRecording,
    ip: ip ?? this.ip,
    firmware: firmware ?? this.firmware,
    battery: battery ?? this.battery,
    signal: signal ?? this.signal,
    thumb: thumb ?? this.thumb,
    lastMotion: lastMotion ?? this.lastMotion,
    lastSeen: lastSeen ?? this.lastSeen,
    isRecording: isRecording ?? this.isRecording,
    ptzSupported: ptzSupported ?? this.ptzSupported,
    privacyMask: privacyMask ?? this.privacyMask,
  );
}