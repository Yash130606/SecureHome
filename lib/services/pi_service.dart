import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class PiService {
  static String _baseUrl = '';

  // ── Set Pi IP ────────────────────────────────────
  static void setIp(String ip) {
    _baseUrl = 'http://$ip:5000';
  }

  static String get streamUrl => _baseUrl.isEmpty ? '' : '$_baseUrl/api/stream';
  static String get baseUrl => _baseUrl;

  // ── Health Check ─────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/health'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Get Status ───────────────────────────────────
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/status'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {};
  }

  // ── Arm / Disarm ─────────────────────────────────
  static Future<bool> setArmed(bool armed) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/arm'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'armed': armed}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Night Mode ───────────────────────────────────
  static Future<bool> setNightMode(bool enabled) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/nightmode'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Get Alerts ───────────────────────────────────
  static Future<List<dynamic>> getAlerts() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/alerts'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  // ── Clear Alerts ─────────────────────────────────
  static Future<bool> clearAlerts() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/alerts/clear'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markAlertRead(String alertId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/alerts/$alertId/read'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteAlert(String alertId) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/api/alerts/$alertId'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Get Known Faces ──────────────────────────────
  static Future<List<dynamic>> getKnownFaces() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/faces'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  // ── Delete Face ──────────────────────────────────
  static Future<bool> deleteFace(String name) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/api/faces/${Uri.encodeComponent(name)}'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> registerFace(String name) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/faces/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      final body = jsonDecode(res.body);
      return {
        'success': false,
        'error': body['error'] ?? 'Face registration failed',
        'captured': body['captured'],
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Could not reach the Pi face registration service',
      };
    }
  }

  static Future<Map<String, dynamic>> uploadFaceImages(
    String name,
    List<File> images,
  ) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/faces/register'));
      request.fields['name'] = name;
      for (final image in images) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(body);
      }

      return {
        'success': false,
        'error': body['error'] ?? 'Face registration failed',
        'captured': body['captured'],
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Could not upload face photos to the Pi',
      };
    }
  }

  static Future<Map<String, dynamic>> retrainFaces() async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/api/faces/retrain'))
          .timeout(const Duration(seconds: 120));
      final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(body);
      }
      return {
        'success': false,
        'error': body['error'] ?? 'Failed to retrain face database',
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Could not reach the Pi training service',
      };
    }
  }

  // ── Get Logs ─────────────────────────────────────
  static Future<List<dynamic>> getLogs() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/logs'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  // ── Start Detection ──────────────────────────────
  static Future<bool> startDetection() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/detection/start'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Stop Detection ───────────────────────────────
  static Future<bool> stopDetection() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/detection/stop'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Get Unknown Faces ────────────────────────────
  static Future<List<dynamic>> getUnknowns() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/unknowns'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  // ── Get Zone Config ──────────────────────────────
  static Future<Map<String, dynamic>> getZone() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/zone'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> getSensitivity() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/sensitivity'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> setSensitivity(int level) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/sensitivity'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'level': level}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {};
  }

  // ── Save Snapshot ─────────────────────────
  static Future<bool> saveSnapshot() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/snapshot'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Get Snapshots ─────────────────────────
  static Future<List<dynamic>> getSnapshots() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/snapshots'),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

// ── Snapshot Image URL ────────────────────
  static String snapshotUrl(String filename) =>
      '$_baseUrl/api/snapshots/$filename';

// ── Delete Snapshot ───────────────────────
  static Future<bool> deleteSnapshot(String filename) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/api/snapshots/$filename'),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Latest frame thumbnail URL ────────────────────
  static Future<List<dynamic>> getRecordings() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/recordings'),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> deleteRecording(String filename) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/api/recordings/$filename'),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String recordingUrl(String filename) =>
      '$_baseUrl/api/recordings/$filename';

  static String recordingThumbUrl(String filename) =>
      '$_baseUrl/api/recordings/thumbs/$filename';

  static String get thumbnailUrl => '$_baseUrl/api/snapshot/latest';
}
