import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppAuthUser {
  const AppAuthUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String? email;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
    };
  }

  factory AppAuthUser.fromJson(Map<String, dynamic> json) {
    return AppAuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}

class AppAuthSession {
  const AppAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final AppAuthUser user;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }

  factory AppAuthSession.fromJson(Map<String, dynamic> json) {
    return AppAuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString(),
      user: AppAuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const _sessionStorageKey = 'auth.session';

  final StreamController<AppAuthSession?> _authStateController =
      StreamController<AppAuthSession?>.broadcast();

  String _baseUrl = 'http://10.0.2.2:8000';
  AppAuthSession? _currentSession;

  void configure({required String baseUrl}) {
    _baseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      _currentSession = null;
      _authStateController.add(null);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _currentSession = AppAuthSession.fromJson(decoded);
    } catch (_) {
      _currentSession = null;
      await prefs.remove(_sessionStorageKey);
    }

    _authStateController.add(_currentSession);
  }

  bool get isConfigured {
    return _baseUrl.isNotEmpty;
  }

  AppAuthUser? get currentUser => _currentSession?.user;

  AppAuthSession? get currentSession => _currentSession;

  Stream<AppAuthSession?> get authStateChanges => _authStateController.stream;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    final session = await _authenticate(
      path: '/api/v1/auth/sign-in',
      email: email,
      password: password,
    );
    await _persistSession(session);
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    final session = await _authenticate(
      path: '/api/v1/auth/sign-up',
      email: email,
      password: password,
    );
    await _persistSession(session);
  }

  Future<void> signOut() async {
    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
    _authStateController.add(null);
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Remote auth is not configured. Check REMOTE_API_BASE_URL.',
      );
    }
  }

  Future<AppAuthSession> _authenticate({
    required String path,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.post(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded['detail'];
      if (detail is Map<String, dynamic>) {
        throw Exception(detail['message']?.toString() ?? 'Authentication failed.');
      }
      throw Exception('Authentication failed.');
    }

    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    return AppAuthSession.fromJson(data);
  }

  Future<void> _persistSession(AppAuthSession session) async {
    _currentSession = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
    _authStateController.add(session);
  }
}
