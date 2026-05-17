import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static const _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '987949308230-nk5l7n528fsgr1i226t5j6jv47im8odh.apps.googleusercontent.com',
  );

  final ApiService _api = ApiService();
  late final GoogleSignIn _googleSignIn = _createGoogleSignIn();

  User? _user;
  String? _accessToken;
  bool _isLoading = false;
  String? _lastError;

  AuthService({String? initialToken}) {
    _accessToken = initialToken;
    _restoreSession();
  }

  User? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('user');
    if (savedUser != null) {
      _user = User.fromJson(jsonDecode(savedUser));
      notifyListeners();
    }
    if (_accessToken != null) {
      await fetchUser();
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception(
            'Google did not return an ID token. Check OAuth client configuration.');
      }

      final payload = await _api.loginWithGoogleToken(idToken);
      _user = payload.user;
      _accessToken = payload.accessToken;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', payload.accessToken);
      await prefs.setString('refresh_token', payload.refreshToken);
      await prefs.setString(
          'user',
          jsonEncode({
            'id': payload.user.id,
            'username': payload.user.username,
            'email': payload.user.email,
            'first_name': payload.user.firstName,
            'last_name': payload.user.lastName,
            'full_name': payload.user.fullName,
          }));
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchUser() async {
    if (_accessToken == null) return;
    try {
      _user = await _api.getCurrentUser();
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error.toString();
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('user');
      if (savedUser == null) {
        await logout(signOutGoogle: false);
      }
    }
  }

  Future<void> logout({bool signOutGoogle = true}) async {
    if (signOutGoogle) {
      await _googleSignIn.signOut();
    }
    _user = null;
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  GoogleSignIn _createGoogleSignIn() {
    if (kIsWeb) {
      return GoogleSignIn(
        scopes: const ['email'],
        clientId: _webClientId,
      );
    }

    return GoogleSignIn(
      scopes: const ['email'],
      serverClientId: _webClientId,
    );
  }
}
