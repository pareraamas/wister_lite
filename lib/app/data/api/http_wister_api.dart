import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'wister_api.dart';

/// [WisterApi] lewat HTTP ke Laravel (Sanctum, JSON).
class HttpWisterApi implements WisterApi {
  HttpWisterApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  @override
  Future<AuthSession> signInWithGoogle(String idToken) async {
    final body = await _send('POST', '/api/auth/google', body: {'id_token': idToken, 'device_name': Platform.operatingSystem});
    return AuthSession.fromJson(body);
  }

  @override
  Future<void> signOut(String token) => _send('POST', '/api/auth/logout', token: token);

  @override
  Future<void> deleteAccount(String token) => _send('DELETE', '/api/account', token: token);

  @override
  Future<SyncResponse> sync(String token, {String? cursor, required SyncChanges changes}) async {
    final body = await _send('POST', '/api/sync', token: token, body: {'cursor': cursor, 'changes': changes.toJson()});
    return SyncResponse.fromJson(body);
  }

  Future<Map<String, dynamic>> _send(String method, String path, {String? token, Map<String, dynamic>? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException();
    } on http.ClientException {
      throw const OfflineException();
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : const {};
    }
    final message = decoded is Map && decoded['message'] is String ? decoded['message'] as String : 'HTTP ${response.statusCode}';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
