// lib/providers/auth_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pi_service.dart';
import '../services/push_notification_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;
  String? _piIpAddress;
  String? _userName;
  bool _piConnected = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get piIpAddress => _piIpAddress;
  String? get userName => _userName;
  bool get isAuthenticated => _user != null;
  bool get piConnected => _piConnected;

  // ── Constructor ───────────────────────────────────────────────────────────
  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      if (user != null) {
        _status = AuthStatus.authenticated;
        _loadUserData();
        unawaited(PushNotificationService.refreshToken());
      } else {
        _status = AuthStatus.unauthenticated;
        _piConnected = false;
      }
      notifyListeners();
    });
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user profile to Firestore
      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now().toIso8601String(),
        'plan': 'free',
        'piIpAddress': '',
      });

      await cred.user!.updateDisplayName(name);

      _user = cred.user;
      _status = AuthStatus.authenticated;
      await _loadUserData();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseError(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. Try again.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = cred.user;
      _status = AuthStatus.authenticated;
      await _loadUserData();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseError(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed. Try again.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  Future<bool> forgotPassword(String email) async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();
      await _auth.sendPasswordResetEmail(email: email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _parseError(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Save Pi IP ────────────────────────────────────────────────────────────
  Future<bool> savePiIp(String ip) async {
    if (_user == null) return false;
    try {
      _errorMessage = null;
      _piIpAddress = ip.trim();
      await _db.collection('users').doc(_user!.uid).update({
        'piIpAddress': _piIpAddress,
      });

      // Auto connect to Pi after saving IP
      final connected = await _connectToPi(_piIpAddress!);
      if (!connected) {
        _errorMessage = 'Could not connect to Raspberry Pi at $_piIpAddress';
      }
      notifyListeners();
      return connected;
    } catch (_) {
      _errorMessage = 'Failed to save Raspberry Pi address';
      notifyListeners();
      return false;
    }
  }

  // ── Connect to Pi ─────────────────────────────────────────────────────────
  Future<bool> _connectToPi(String ip) async {
    if (ip.isEmpty) return false;
    try {
      PiService.setIp(ip);
      final ok = await PiService.checkHealth();
      _piConnected = ok;
      notifyListeners();
      return ok;
    } catch (_) {
      _piConnected = false;
      notifyListeners();
      return false;
    }
  }

  // ── Retry Pi Connection ───────────────────────────────────────────────────
  Future<bool> retryPiConnection() async {
    if (_piIpAddress == null || _piIpAddress!.isEmpty) return false;
    _errorMessage = null;
    final ok = await _connectToPi(_piIpAddress!);
    if (!ok) {
      _errorMessage = 'Pi is still offline. Check Wi-Fi, IP, and API server.';
      notifyListeners();
    }
    return ok;
  }

  // ── Update Pi IP ──────────────────────────────────────────────────────────
  Future<bool> updatePiIp(String ip) async {
    return await savePiIp(ip);
  }

  // ── Load User Data ────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    if (_user == null) return;
    try {
      final doc = await _db.collection('users').doc(_user!.uid).get();

      if (doc.exists) {
        final data = doc.data();
        _piIpAddress = data?['piIpAddress'] ?? '';
        _userName = data?['name'] ?? '';
        notifyListeners();

        // Auto connect to Pi if IP saved
        if (_piIpAddress != null && _piIpAddress!.isNotEmpty) {
          await _connectToPi(_piIpAddress!);
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String name,
    required String email,
  }) async {
    if (_user == null) return false;
    try {
      await _db.collection('users').doc(_user!.uid).update({
        'name': name,
        'email': email,
      });
      await _user!.updateDisplayName(name);
      _userName = name;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await PushNotificationService.clearToken();
    await _auth.signOut();
    _user = null;
    _piIpAddress = null;
    _userName = null;
    _piConnected = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Error Parser ──────────────────────────────────────────────────────────
  String _parseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'weak-password':
        return 'Password too weak (min 6 chars)';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Try later';
      case 'network-request-failed':
        return 'No internet connection';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'Something went wrong. Try again';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
