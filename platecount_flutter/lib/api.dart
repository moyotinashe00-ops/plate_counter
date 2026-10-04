import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000');

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api extends ChangeNotifier {
  Api._();
  static final Api instance = Api._();

  String? _token;
  Map<String, dynamic>? user;
  bool get signedIn => _token != null && user != null;
  bool get isChef => user?['role'] == 'chef';

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
    if (_token != null) {
      try {
        user = Map<String, dynamic>.from(await get('/me'));
      } catch (_) {
        await signOut();
      }
    }
    notifyListeners();
  }

  Future<void> _setSession(Map res) async {
    _token = res['token'];
    user = Map<String, dynamic>.from(res['user']);
    (await SharedPreferences.getInstance()).setString('token', _token!);
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _setSession(await post('/auth/login', {'email': email, 'password': password}));

  Future<void> signup(String email, String password, String name) async =>
      _setSession(await post('/auth/signup', {'email': email, 'password': password, 'display_name': name}));

  Future<void> signOut() async {
    _token = null;
    user = null;
    (await SharedPreferences.getInstance()).remove('token');
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _handle(http.Response r) async {
    if (r.statusCode == 401 && _token != null && !r.request!.url.path.startsWith('/auth')) {
      await signOut();
    }
    final ct = r.headers['content-type'] ?? '';
    final body = ct.contains('json') ? jsonDecode(r.body) : r.body;
    if (r.statusCode >= 400) {
      throw ApiException(body is Map ? (body['error'] ?? 'Request failed') : 'Request failed');
    }
    return body;
  }

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$apiUrl$path').replace(queryParameters: q);

  Future<dynamic> get(String path, [Map<String, String>? q]) async =>
      _handle(await http.get(_u(path, q), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) async =>
      _handle(await http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> patch(String path, Object body) async =>
      _handle(await http.patch(_u(path), headers: _headers, body: jsonEncode(body)));
}

final api = Api.instance;
