import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan.dart';
import '../models/user.dart';

class AuthPayload {
  final User user;
  final String accessToken;
  final String refreshToken;

  const AuthPayload({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}

class ScanUploadResult {
  final Scan scan;
  final String diseaseClass;
  final double confidence;
  final String recommendation;

  const ScanUploadResult({
    required this.scan,
    required this.diseaseClass,
    required this.confidence,
    required this.recommendation,
  });
}

class ApiService {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final String baseUrl = _normalizeBaseUrl(
    _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : 'https://eligible-henriette-laneglo-afa9e80d.koyeb.app/api',
  );

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<Map<String, String>> _authHeaders(
      {bool json = true, String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = token ?? prefs.getString('access_token');
    return {
      if (json) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Future<String?> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response = await http.post(
      Uri.parse('$baseUrl/auth/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = _tryDecodeMap(response);
    final accessToken = body['access'] as String?;
    if (accessToken == null || accessToken.isEmpty) return null;
    await prefs.setString('access_token', accessToken);
    final rotatedRefresh = body['refresh'] as String?;
    if (rotatedRefresh != null && rotatedRefresh.isNotEmpty) {
      await prefs.setString('refresh_token', rotatedRefresh);
    }
    return accessToken;
  }

  Future<AuthPayload> loginWithGoogleToken(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    final data = _decodeMap(response);
    final tokens = data['tokens'] as Map<String, dynamic>;
    return AuthPayload(
      user: User.fromJson(data['user']),
      accessToken: tokens['access'],
      refreshToken: tokens['refresh'],
    );
  }

  Future<User> getCurrentUser() async {
    var response = await http.get(Uri.parse('$baseUrl/auth/user/'),
        headers: await _authHeaders());
    if (response.statusCode == 401) {
      final token = await refreshAccessToken();
      if (token != null) {
        response = await http.get(Uri.parse('$baseUrl/auth/user/'),
            headers: await _authHeaders(token: token));
      }
    }
    return User.fromJson(_decodeMap(response));
  }

  Future<List<Scan>> getScanHistory({String? disease}) async {
    final uri = Uri.parse('$baseUrl/scan/history/').replace(
      queryParameters: disease == null ? null : {'disease': disease},
    );
    var response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode == 401) {
      final token = await refreshAccessToken();
      if (token != null) {
        response =
            await http.get(uri, headers: await _authHeaders(token: token));
      }
    }
    if (response.statusCode == 401) return [];
    final data = _decodeList(response);
    return data.map((scan) => Scan.fromJson(scan)).toList();
  }

  Future<ScanUploadResult> uploadScan(XFile image) async {
    Future<http.Response> sendUpload() async {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/scan/upload/'));
      request.headers.addAll(await _authHeaders(json: false));
      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name.isEmpty ? 'tomato-leaf.jpg' : image.name,
        ),
      );

      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    var response = await sendUpload();
    if (response.statusCode == 401 && await refreshAccessToken() != null) {
      response = await sendUpload();
    }
    final data = _decodeMap(response);
    final scan = Scan.fromJson(data['scan']);
    return ScanUploadResult(
      scan: scan,
      diseaseClass: data['class'] ?? scan.disease,
      confidence: (data['confidence'] as num?)?.toDouble() ?? scan.confidence,
      recommendation: data['recommendation'] ?? scan.recommendation,
    );
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final body = _tryDecodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          body['error'] ?? body['detail'] ?? _fallbackErrorMessage(response));
    }
    return body;
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_fallbackErrorMessage(response));
    }
    try {
      final body =
          response.body.isEmpty ? [] : jsonDecode(response.body) as List;
      return body.cast<Map<String, dynamic>>();
    } on FormatException {
      throw Exception(_fallbackErrorMessage(response));
    }
  }

  Map<String, dynamic> _tryDecodeMap(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'detail': 'Unexpected API response format.'};
    } on FormatException {
      return {'detail': _fallbackErrorMessage(response)};
    }
  }

  String _fallbackErrorMessage(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final looksLikeHtml = contentType.contains('text/html') ||
        response.body.trimLeft().startsWith('<!DOCTYPE') ||
        response.body.trimLeft().startsWith('<html');

    if (looksLikeHtml) {
      return 'Backend URL is not serving the AgroScan API. Check API_BASE_URL: $baseUrl';
    }
    return 'Request failed with ${response.statusCode}';
  }
}
