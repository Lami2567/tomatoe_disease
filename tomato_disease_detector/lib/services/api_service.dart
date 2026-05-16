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
  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : 'https://eligible-henriette-laneglo-afa9e80d.koyeb.app/api';

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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
    final response = await http.get(
      Uri.parse('$baseUrl/auth/user/'),
      headers: await _authHeaders(),
    );
    return User.fromJson(_decodeMap(response));
  }

  Future<List<Scan>> getScanHistory({String? disease}) async {
    final uri = Uri.parse('$baseUrl/scan/history/').replace(
      queryParameters: disease == null ? null : {'disease': disease},
    );
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode == 401) return [];
    final data = _decodeList(response);
    return data.map((scan) => Scan.fromJson(scan)).toList();
  }

  Future<ScanUploadResult> uploadScan(XFile image) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan/upload/'));
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
    final response = await http.Response.fromStream(streamed);
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
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? body['detail'] ?? 'Request failed with ${response.statusCode}');
    }
    return body;
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed with ${response.statusCode}');
    }
    final body = response.body.isEmpty ? [] : jsonDecode(response.body) as List;
    return body.cast<Map<String, dynamic>>();
  }
}
