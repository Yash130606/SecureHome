import 'dart:async';
import 'package:flutter/material.dart';
import 'pi_service.dart';

class AlertService extends ChangeNotifier {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = false;
  Timer? _timer;
  int _unread = 0;

  List<Map<String, dynamic>> get alerts => _alerts;
  bool get loading => _loading;
  int get unread => _unread;

  // ── Start auto refresh ────────────────────────
  void startPolling() {
    _timer?.cancel();
    fetchAlerts(); // fetch immediately
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchAlerts());
  }

  void stopPolling() => _timer?.cancel();

  // ── Fetch alerts from Pi ──────────────────────
  Future<void> fetchAlerts() async {
    try {
      _loading = true;
      notifyListeners();

      final data = await PiService.getAlerts();
      _alerts = data.map((a) => Map<String, dynamic>.from(a)).toList();
      _unread = _alerts.where((a) => a['isRead'] == false).length;

      _loading = false;
      notifyListeners();
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Mark alert as read ────────────────────────
  void markRead(String id) {
    final i = _alerts.indexWhere((a) => a['id'] == id);
    if (i != -1) {
      _alerts[i]['isRead'] = true;
      _unread = _alerts.where((a) => a['isRead'] == false).length;
      notifyListeners();
    }
  }

  // ── Clear all alerts ──────────────────────────
  Future<void> clearAll() async {
    await PiService.clearAlerts();
    _alerts.clear();
    _unread = 0;
    notifyListeners();
  }

  // ── Get alerts by type ────────────────────────
  List<Map<String, dynamic>> byType(String type) {
    if (type == 'All') return _alerts;
    return _alerts.where((a) => a['type'] == type.toLowerCase()).toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
