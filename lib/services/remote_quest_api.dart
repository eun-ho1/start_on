import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:start_on/models/completed_quest_record.dart';
import 'package:start_on/models/quest_item.dart';

class RemoteQuestApi {
  RemoteQuestApi({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _baseUrl = _normalizeBaseUrl(baseUrl),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration _timeout;

  Future<List<QuestItem>> fetchQuests(String accessToken) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'GET',
      path: '/api/v1/quests',
    );
    final data = _extractData(response, operation: 'fetch quests');
    if (data is! List) {
      throw const RemoteQuestApiException(
        'Failed to fetch quests: unexpected response format.',
      );
    }

    return data
        .map(
          (item) => QuestItem.fromJson(
            _normalizeQuestJson(Map<String, dynamic>.from(item as Map)),
          ),
        )
        .toList();
  }

  Future<QuestItem> createQuest(String accessToken, QuestItem quest) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'POST',
      path: '/api/v1/quests',
      body: <String, dynamic>{
        'title': quest.title,
        'exp': quest.exp,
        'difficulty': _toApiDifficulty(
          quest.difficulty,
          exp: quest.exp,
          defaultDurationSeconds: quest.defaultDurationSeconds,
        ),
        'category': quest.category,
        'defaultDurationSeconds': quest.defaultDurationSeconds,
      },
    );
    final data = _extractData(response, operation: 'create quest');
    return QuestItem.fromJson(
      _normalizeQuestJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<QuestItem> updateQuest(
    String accessToken,
    String questId,
    Map<String, dynamic> data,
  ) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'PATCH',
      path: '/api/v1/quests/$questId',
      body: _normalizeQuestUpdatePayload(data),
    );
    final responseData = _extractData(response, operation: 'update quest');
    return QuestItem.fromJson(
      _normalizeQuestJson(Map<String, dynamic>.from(responseData as Map)),
    );
  }

  Future<void> deleteQuest(String accessToken, String questId) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'DELETE',
      path: '/api/v1/quests/$questId',
    );
    _extractData(response, operation: 'delete quest');
  }

  Future<CompletedQuestRecord> completeQuest(
    String accessToken,
    String questId,
    int elapsedSeconds,
    String? proofImagePath,
  ) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'POST',
      path: '/api/v1/quests/$questId/complete',
      body: <String, dynamic>{
        'elapsedSeconds': elapsedSeconds,
        'proofImagePath': proofImagePath,
      },
    );
    final data = _extractData(response, operation: 'complete quest');
    return CompletedQuestRecord.fromJson(
      _normalizeCompletedQuestJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<Map<String, dynamic>> fetchProfile(String accessToken) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'GET',
      path: '/api/v1/profile',
    );
    return Map<String, dynamic>.from(
      _extractData(response, operation: 'fetch profile') as Map,
    );
  }

  Future<Map<String, dynamic>> fetchStats(String accessToken) async {
    final response = await _sendRequest(
      accessToken: accessToken,
      method: 'GET',
      path: '/api/v1/stats/summary',
    );
    return Map<String, dynamic>.from(
      _extractData(response, operation: 'fetch stats') as Map,
    );
  }

  Future<http.Response> _sendRequest({
    required String accessToken,
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      switch (method) {
        case 'GET':
          return await _httpClient
              .get(uri, headers: headers)
              .timeout(_timeout);
        case 'POST':
          return await _httpClient
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
        case 'PATCH':
          return await _httpClient
              .patch(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
        case 'DELETE':
          return await _httpClient
              .delete(uri, headers: headers)
              .timeout(_timeout);
      }
    } on TimeoutException {
      throw RemoteQuestApiException(
        'Request timed out while trying to $method $path.',
      );
    } on http.ClientException catch (error) {
      throw RemoteQuestApiException(
        'Network error while trying to $method $path: ${error.message}',
      );
    } on FormatException catch (error) {
      throw RemoteQuestApiException(
        'Invalid request payload for $method $path: ${error.message}',
      );
    }

    throw RemoteQuestApiException(
      'Unsupported HTTP method for remote quest API: $method.',
    );
  }

  dynamic _extractData(http.Response response, {required String operation}) {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object.');
      }
      decoded = parsed;
    } on FormatException {
      throw RemoteQuestApiException(
        'Failed to $operation: server returned invalid JSON '
        '(status ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteQuestApiException(
        _buildErrorMessage(decoded, operation, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    if (decoded['success'] != true) {
      throw RemoteQuestApiException(
        'Failed to $operation: API returned success=false.',
        statusCode: response.statusCode,
      );
    }

    return decoded['data'];
  }

  Map<String, dynamic> _normalizeQuestUpdatePayload(Map<String, dynamic> data) {
    final normalized = _normalizeQuestJson(data);
    return <String, dynamic>{
      'title': normalized['title'] ?? '',
      'exp': _toInt(normalized['exp']),
      'difficulty': _toApiDifficulty(
        normalized['difficulty']?.toString(),
        exp: _toInt(normalized['exp']),
        defaultDurationSeconds: _toInt(normalized['defaultDurationSeconds']),
      ),
      'category': normalized['category'] ?? 'work',
      'elapsedSeconds': _toInt(normalized['elapsedSeconds']),
      'defaultDurationSeconds': _toInt(normalized['defaultDurationSeconds']),
    };
  }

  Map<String, dynamic> _normalizeQuestJson(Map<String, dynamic> json) {
    return <String, dynamic>{
      'id': json['id']?.toString(),
      'title': json['title'],
      'exp': _toInt(json['exp']),
      'difficulty': json['difficulty']?.toString(),
      'category': json['category']?.toString(),
      'elapsedSeconds': _toInt(
        json['elapsedSeconds'] ?? json['elapsed_seconds'],
      ),
      'defaultDurationSeconds': _toInt(
        json['defaultDurationSeconds'] ?? json['default_duration_seconds'],
      ),
    };
  }

  Map<String, dynamic> _normalizeCompletedQuestJson(
    Map<String, dynamic> json,
  ) {
    return <String, dynamic>{
      'questId': json['questId'] ?? json['quest_id'] ?? '',
      'title': json['title'] ?? '',
      'difficulty': json['difficulty']?.toString() ?? 'normal',
      'category': json['category'] ?? 'work',
      'earnedExp': _toInt(json['earnedExp'] ?? json['earned_exp']),
      'completedAt':
          json['completedAt']?.toString() ??
          json['completed_at']?.toString() ??
          '',
      'elapsedSeconds': _toInt(
        json['elapsedSeconds'] ?? json['elapsed_seconds'],
      ),
      'proofImagePath':
          json['proofImagePath']?.toString() ??
          json['proof_image_path']?.toString(),
    };
  }

  String _buildErrorMessage(
    Map<String, dynamic> responseJson,
    String operation,
    int statusCode,
  ) {
    final detail = responseJson['detail'];
    if (detail is Map<String, dynamic>) {
      final code = detail['code']?.toString();
      final message = detail['message']?.toString();
      if (message != null && message.isNotEmpty) {
        if (code != null && code.isNotEmpty) {
          return 'Failed to $operation [$code]: $message';
        }
        return 'Failed to $operation: $message';
      }
    }

    final error = responseJson['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code']?.toString();
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        if (code != null && code.isNotEmpty) {
          return 'Failed to $operation [$code]: $message';
        }
        return 'Failed to $operation: $message';
      }
    }

    return 'Failed to $operation: server returned status $statusCode.';
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static String _toApiDifficulty(
    String? difficulty, {
    required int exp,
    required int defaultDurationSeconds,
  }) {
    if (difficulty == 'easy' || difficulty == 'normal' || difficulty == 'hard') {
      return difficulty!;
    }
    if (exp <= 30 || defaultDurationSeconds <= 25 * 60) {
      return 'easy';
    }
    if (exp >= 100 || defaultDurationSeconds >= 90 * 60) {
      return 'hard';
    }
    return 'normal';
  }
}

class RemoteQuestApiException implements Exception {
  const RemoteQuestApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'RemoteQuestApiException('
        'statusCode: $statusCode, '
        'message: $message'
        ')';
  }
}
