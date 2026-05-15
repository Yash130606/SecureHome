import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/mock_data.dart';
import '../models/alert_model.dart';
import '../models/camera_model.dart';
import '../models/recording_model.dart';
import '../services/pi_service.dart';

enum SystemArmState { disarmed, armed, night, alert, lockdown }

class AppProvider extends ChangeNotifier {
  int _navIndex = 0;
  int get navIndex => _navIndex;

  SystemArmState _armState = SystemArmState.disarmed;
  SystemArmState get armState => _armState;
  DateTime? _armedAt;
  DateTime? get armedAt => _armedAt;
  bool get isArmed => _armState != SystemArmState.disarmed;

  late List<CameraModel> _cameras;
  List<CameraModel> get cameras => List.unmodifiable(_cameras);
  int get onlineCount => _cameras.where((c) => c.isOnline).length;
  int get totalAlerts => _cameras.fold(0, (s, c) => s + c.alerts);
  int get lowBatteryCount => _cameras.where((c) => c.isBatteryLow).length;
  int get offlineCount => _cameras.where((c) => !c.isOnline).length;

  late List<AlertModel> _alerts;
  List<AlertModel> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => _alerts.where((a) => !a.isRead).length;
  int unreadCountByType(String type) => type == 'All'
      ? unreadCount
      : _alerts
          .where((a) => !a.isRead && a.type == type.toLowerCase())
          .length;
  AlertModel? get latestUnreadAlert {
    for (final alert in _alerts) {
      if (!alert.isRead) return alert;
    }
    return null;
  }
  AlertModel? _pendingForegroundAlert;
  AlertModel? get pendingForegroundAlert => _pendingForegroundAlert;

  late List<RecordingModel> _recordings;
  List<RecordingModel> get recordings => List.unmodifiable(_recordings);

  String _recordingCameraFilter = 'All';
  String _recordingTypeFilter = 'All';
  String get recordingCameraFilter => _recordingCameraFilter;
  String get recordingTypeFilter => _recordingTypeFilter;
  String get recordingFilter => _recordingCameraFilter;

  String userName = kUserProfile['name']!;
  String userEmail = kUserProfile['email']!;
  String userPlan = kUserProfile['plan']!;
  String userMemberSince = kUserProfile['memberSince']!;
  String userAvatar = kUserProfile['avatar']!;

  bool notifMotion = true;
  bool notifPerson = true;
  bool notifSystem = true;
  bool doNotDisturb = false;
  String notifSound = 'Default';
  String notifVibration = 'On';
  String notifBannerStyle = 'Temporary';
  String notifSensitivity = 'High';
  int notifCooldownSeconds = 60;
  String notifEmail = '';
  TimeOfDay? quietHoursStart;
  TimeOfDay? quietHoursEnd;

  bool _onboardingDone = false;
  bool get onboardingDone => _onboardingDone;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _piArmed = false;
  bool _piNightMode = false;
  bool _piRunning = false;
  int _piUnknowns = 0;
  bool _piConnected = false;
  List<dynamic> _piAlerts = [];
  int _piSensitivity = 50;
  double _piConfidence = 0.55;
  int _piLoiterSeconds = 9;
  Timer? _piRefreshTimer;
  bool _hasCompletedInitialPiAlertSync = false;

  bool get piArmed => _piArmed;
  bool get piNightMode => _piNightMode;
  bool get piRunning => _piRunning;
  int get piUnknowns => _piUnknowns;
  bool get piConnected => _piConnected;
  List<dynamic> get piAlerts => _piAlerts;
  int get piSensitivity => _piSensitivity;
  double get piConfidence => _piConfidence;
  int get piLoiterSeconds => _piLoiterSeconds;

  AppProvider() {
    _cameras = kCameras
        .map((m) => CameraModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    _alerts = [];
    _recordings = [];
    loadPrefs();
  }

  void setNav(int index) {
    _navIndex = index;
    notifyListeners();
  }

  void setArmState(SystemArmState state) {
    _armState = state;
    _armedAt = state != SystemArmState.disarmed ? DateTime.now() : null;
    notifyListeners();
  }

  void toggleCamera(String id, bool val) {
    final i = _cameras.indexWhere((c) => c.id == id);
    if (i == -1) return;
    _cameras[i] = _cameras[i].copyWith(isOn: val);
    notifyListeners();
  }

  void updateCamera(String id, CameraModel updated) {
    final i = _cameras.indexWhere((c) => c.id == id);
    if (i == -1) return;
    _cameras[i] = updated;
    notifyListeners();
  }

  void addCamera(CameraModel cam) {
    _cameras.add(cam);
    notifyListeners();
  }

  void removeCamera(String id) {
    final cameraIndex = _cameras.indexWhere((c) => c.id == id);
    if (cameraIndex == -1) return;

    final cameraName = _cameras[cameraIndex].name;
    _cameras.removeAt(cameraIndex);
    _alerts.removeWhere((a) => a.camera == cameraName);
    notifyListeners();
  }

  List<String> get zoneNames {
    final zones = _cameras.map((c) => c.zone).toSet().toList()..sort();
    return zones;
  }

  List<AlertModel> alertsByType(String type) => type == 'All'
      ? List.unmodifiable(_alerts)
      : List.unmodifiable(_alerts.where((a) => a.type == type.toLowerCase()));

  int alertCountByType(String type) => type == 'All'
      ? _alerts.length
      : _alerts.where((a) => a.type == type.toLowerCase()).length;

  void markRead(String id) {
    final i = _alerts.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _alerts[i] = _alerts[i].copyWith(isRead: true);
    notifyListeners();
  }

  Future<bool> markAlertRead(String id) async {
    markRead(id);
    if (!_piConnected) return true;
    final ok = await PiService.markAlertRead(id);
    if (!ok) {
      await refreshFromPi();
      return false;
    }
    return true;
  }

  void markAllRead() {
    _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  Future<bool> markAllPiAlertsRead() async {
    final unreadIds =
        _alerts.where((alert) => !alert.isRead).map((alert) => alert.id).toList();
    if (unreadIds.isEmpty) return true;

    markAllRead();
    if (!_piConnected) return true;

    for (final alertId in unreadIds) {
      final ok = await PiService.markAlertRead(alertId);
      if (!ok) {
        await refreshFromPi();
        return false;
      }
    }
    return true;
  }

  void dismissAlert(String id) {
    _alerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<bool> dismissPiAlert(String id) async {
    dismissAlert(id);
    if (!_piConnected) return true;
    final ok = await PiService.deleteAlert(id);
    if (!ok) {
      await refreshFromPi();
      return false;
    }
    _piAlerts.removeWhere((alert) => alert['id'] == id);
    return true;
  }

  void clearAllAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  Future<bool> clearAllPiAlerts() async {
    clearAllAlerts();
    _piAlerts = [];
    notifyListeners();
    if (!_piConnected) return true;
    final ok = await PiService.clearAlerts();
    if (!ok) {
      await refreshFromPi();
      return false;
    }
    return true;
  }

  void _injectAlert(AlertModel alert) {
    _alerts.insert(0, alert);
    notifyListeners();
  }

  List<RecordingModel> get filteredRecordings {
    var list = _recordings.toList();
    if (_recordingCameraFilter != 'All') {
      list = list.where((r) => r.cameraId == _recordingCameraFilter).toList();
    }
    if (_recordingTypeFilter != 'All') {
      list = list
          .where((r) => r.type == _recordingTypeFilter.toLowerCase())
          .toList();
    }
    return list;
  }

  void setRecordingCameraFilter(String filter) {
    _recordingCameraFilter = filter;
    notifyListeners();
  }

  void setRecordingTypeFilter(String filter) {
    _recordingTypeFilter = filter;
    notifyListeners();
  }

  void setRecordingFilter(String filter) => setRecordingCameraFilter(filter);

  void toggleFavourite(String id) {
    final i = _recordings.indexWhere((r) => r.id == id);
    if (i == -1) return;
    _recordings[i] =
        _recordings[i].copyWith(isFavourite: !_recordings[i].isFavourite);
    notifyListeners();
  }

  void deleteRecording(String id) {
    _recordings.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<bool> deletePiRecording(String filename, String id) async {
    deleteRecording(id);
    if (!_piConnected) return true;
    final ok = await PiService.deleteRecording(filename);
    if (!ok) {
      await refreshFromPi();
      return false;
    }
    return true;
  }

  List<String> get cameraNames => ['All', ..._cameras.map((c) => c.name)];
  List<String> get cameraIds => ['All', ..._cameras.map((c) => c.id)];

  Map<String, List<RecordingModel>> get recordingsByDay {
    final map = <String, List<RecordingModel>>{};
    for (final recording in filteredRecordings) {
      final day = '${recording.timestamp.year}-'
          '${recording.timestamp.month.toString().padLeft(2, '0')}-'
          '${recording.timestamp.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(day, () => []).add(recording);
    }
    return map;
  }

  Map<String, List<AlertModel>> get alertsByDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final map = <String, List<AlertModel>>{};

    for (final alert in _alerts) {
      final alertDay =
          DateTime(alert.timestamp.year, alert.timestamp.month, alert.timestamp.day);
      String key;
      if (alertDay == today) {
        key = 'Today';
      } else if (alertDay == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${alert.timestamp.day} ${_monthName(alert.timestamp.month)}';
      }
      map.putIfAbsent(key, () => []).add(alert);
    }
    return map;
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  void updateProfile({String? name, String? email}) {
    if (name != null) userName = name;
    if (email != null) userEmail = email;
    notifyListeners();
  }

  void toggleNotif(String key, bool value) {
    switch (key) {
      case 'motion':
        notifMotion = value;
        break;
      case 'person':
        notifPerson = value;
        break;
      case 'system':
        notifSystem = value;
        break;
      case 'dnd':
        doNotDisturb = value;
        break;
    }
    notifyListeners();
  }

  void setNotifSound(String value) {
    notifSound = value;
    notifyListeners();
  }

  void setNotifVibration(String value) {
    notifVibration = value;
    notifyListeners();
  }

  void setNotifSensitivity(String value) {
    notifSensitivity = value;
    notifyListeners();
  }

  void setNotifCooldown(int value) {
    notifCooldownSeconds = value;
    notifyListeners();
  }

  void setNotifEmail(String value) {
    notifEmail = value;
    notifyListeners();
  }

  void setQuietHours(TimeOfDay? start, TimeOfDay? end) {
    quietHoursStart = start;
    quietHoursEnd = end;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> connectToPi(String ip) async {
    PiService.setIp(ip);
    final ok = await PiService.checkHealth();
    _piConnected = ok;
    if (ok) {
      _startPiRefreshLoop();
      await refreshFromPi();
    } else {
      _resetPiRuntimeState(clearAlerts: true);
    }
    notifyListeners();
    return ok;
  }

  void syncPiSession({String? ip, required bool isConnected}) {
    if (ip != null && ip.isNotEmpty) {
      PiService.setIp(ip);
    }

    if (_piConnected == isConnected) {
      if (isConnected && _piRefreshTimer == null) {
        _startPiRefreshLoop();
      }
      return;
    }

    _piConnected = isConnected;
    if (isConnected) {
      _startPiRefreshLoop();
      unawaited(refreshFromPi());
    } else {
      _resetPiRuntimeState(clearAlerts: true);
      notifyListeners();
    }
  }

  Future<void> refreshFromPi() async {
    try {
      final previousAlertIds = _alerts.map((alert) => alert.id).toSet();
      final previousArmState = _armState;
      final status = await PiService.getStatus();
      if (status.isEmpty) {
        _piConnected = false;
        _resetPiRuntimeState(clearAlerts: true);
        notifyListeners();
        return;
      }

      _piConnected = true;
      _piArmed = status['armed'] ?? false;
      _piNightMode = status['night_mode'] ?? false;
      _piRunning = status['running'] ?? false;
      _piUnknowns = status['unknown_count'] ?? 0;
      _piSensitivity = status['sensitivity'] ?? _piSensitivity;
      _piConfidence = (status['confidence'] ?? _piConfidence).toDouble();
      _piLoiterSeconds = status['loiter_sec'] ?? _piLoiterSeconds;
      _armState = _deriveArmState();
      if (_armState == SystemArmState.disarmed) {
        _armedAt = null;
      } else if (previousArmState == SystemArmState.disarmed ||
          _armedAt == null) {
        _armedAt = DateTime.now();
      }

      final alerts = await PiService.getAlerts();
      _piAlerts = alerts;
      final mappedAlerts = alerts
          .whereType<Map>()
          .map((alert) =>
              AlertModel.fromMap(Map<String, dynamic>.from(alert)))
          .toList();
      _alerts = mappedAlerts;

      final recordings = await PiService.getRecordings();
      _recordings = recordings
          .whereType<Map>()
          .map((recording) {
            final data = Map<String, dynamic>.from(recording);
            final thumb = (data['thumb'] as String?) ?? '';
            if (thumb.isNotEmpty && thumb.startsWith('/')) {
              data['thumb'] = '${PiService.baseUrl}$thumb';
            }
            return RecordingModel.fromMap(data);
          })
          .toList();

      if (_hasCompletedInitialPiAlertSync) {
        final newAlerts = mappedAlerts
            .where((alert) => !previousAlertIds.contains(alert.id))
            .toList();
        if (newAlerts.isNotEmpty) {
          _pendingForegroundAlert = newAlerts.first;
        }
      } else {
        _hasCompletedInitialPiAlertSync = true;
      }
      notifyListeners();
    } catch (_) {
      _piConnected = false;
      _resetPiRuntimeState(clearAlerts: true);
      notifyListeners();
    }
  }

  Future<bool> togglePiArm() async {
    final ok = await PiService.setArmed(!_piArmed);
    if (ok) {
      await refreshFromPi();
      return true;
    }
    return false;
  }

  Future<bool> togglePiNightMode() async {
    final ok = await PiService.setNightMode(!_piNightMode);
    if (ok) {
      await refreshFromPi();
      return true;
    }
    return false;
  }

  Future<bool> startPiDetection() async {
    final ok = await PiService.startDetection();
    if (ok) {
      await refreshFromPi();
      return true;
    }
    return false;
  }

  Future<bool> stopPiDetection() async {
    final ok = await PiService.stopDetection();
    if (ok) {
      await refreshFromPi();
      return true;
    }
    return false;
  }

  Future<bool> updatePiSensitivity(int level) async {
    final result = await PiService.setSensitivity(level);
    if (result.isEmpty) return false;

    _piSensitivity = result['level'] ?? level;
    _piConfidence = (result['confidence'] ?? _piConfidence).toDouble();
    _piLoiterSeconds = result['loiter_sec'] ?? _piLoiterSeconds;
    notifyListeners();
    return true;
  }

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to load preferences';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _armState = SystemArmState.disarmed;
    _armedAt = null;
    _navIndex = 0;
    _resetPiRuntimeState(clearAlerts: true);
    _recordingCameraFilter = 'All';
    _recordingTypeFilter = 'All';
    notifyListeners();
  }

  void _startPiRefreshLoop() {
    _piRefreshTimer?.cancel();
    _piRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_piConnected) {
        unawaited(refreshFromPi());
      }
    });
  }

  void _resetPiRuntimeState({required bool clearAlerts}) {
    _piRefreshTimer?.cancel();
    _piRefreshTimer = null;
    _piArmed = false;
    _piNightMode = false;
    _piRunning = false;
    _piUnknowns = 0;
    _piConnected = false;
    _piSensitivity = 50;
    _piConfidence = 0.55;
    _piLoiterSeconds = 9;
    _piAlerts = [];
    _pendingForegroundAlert = null;
    _hasCompletedInitialPiAlertSync = false;
    if (clearAlerts) {
      _alerts = [];
    }
  }

  void consumeForegroundAlert(String alertId) {
    if (_pendingForegroundAlert?.id == alertId) {
      _pendingForegroundAlert = null;
      notifyListeners();
    }
  }

  SystemArmState _deriveArmState() {
    if (_piNightMode) return SystemArmState.night;
    if (_piArmed) return SystemArmState.armed;
    return SystemArmState.disarmed;
  }

  @override
  void dispose() {
    _piRefreshTimer?.cancel();
    super.dispose();
  }
}
