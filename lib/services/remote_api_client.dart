import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:start_on/models/completed_quest_record.dart';
import 'package:start_on/models/quest_item.dart';


class RemoteApiClientConfig {
  const RemoteApiClientConfig({
    required this.baseUrl,
    this.userId = _defaultUserId,
    this.timeout = const Duration(seconds: 10),
  });

  final String baseUrl;
  final String userId;
  final Duration timeout;

  static const String _defaultUserId = '00000000-0000-0000-0000-000000000001';
}


class RemoteApiException implements Exception {
  const RemoteApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RemoteApiException(statusCode: $statusCode, message: $message)';
}


class RemoteApiClient {
  RemoteApiClient({
    required RemoteApiClientConfig config,
    http.Client? httpClient,
  }) : _config = config,
       _httpClient = httpClient ?? http.Client();

  final RemoteApiClientConfig _config;
  final http.Client _httpClient;

  Uri _buildUri(String path) {
    final normalizedBaseUrl = _config.baseUrl.endsWith('/')
        ? _config.baseUrl.substring(0, _config.baseUrl.length - 1)
        : _config.baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBaseUrl$normalizedPath');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-User-Id': _config.userId,
  };

  Future<List<QuestItem>> fetchQuests() async {
    final response = await _httpClient
        .get(_buildUri('/api/v1/quests'), headers: _headers)
        .timeout(_config.timeout);
    final data = _extractData(response);
    if (data is! List) {
      throw const RemoteApiException('Unexpected quests response shape.');
    }
    return data
        .map((item) => QuestItem.fromJson(_normalizeQuestJson(Map<String, dynamic>.from(item as Map))))
        .toList();
  }

  Future<QuestItem> createQuest(QuestItem quest) async {
    final response = await _httpClient
        .post(
          _buildUri('/api/v1/quests'),
          headers: _headers,
          body: jsonEncode({
            'title': quest.title,
            'exp': quest.exp,
            'difficulty': quest.difficulty,
            'category': quest.category,
            'defaultDurationSeconds': quest.defaultDurationSeconds,
          }),
        )
        .timeout(_config.timeout);
    final data = _extractData(response);
    return QuestItem.fromJson(_normalizeQuestJson(Map<String, dynamic>.from(data as Map)));
  }

  Future<QuestItem> updateQuest(QuestItem quest) async {
    final response = await _httpClient
        .patch(
          _buildUri('/api/v1/quests/${quest.id}'),
          headers: _headers,
          body: jsonEncode({
            'title': quest.title,
            'exp': quest.exp,
            'difficulty': quest.difficulty,
            'category': quest.category,
            'elapsedSeconds': quest.elapsedSeconds,
            'defaultDurationSeconds': quest.defaultDurationSeconds,
          }),
        )
        .timeout(_config.timeout);
    final data = _extractData(response);
    return QuestItem.fromJson(_normalizeQuestJson(Map<String, dynamic>.from(data as Map)));
  }

  Future<void> deleteQuest(String questId) async {
    final response = await _httpClient
        .delete(_buildUri('/api/v1/quests/$questId'), headers: _headers)
        .timeout(_config.timeout);
    _extractData(response);
  }

  Future<CompletedQuestRecord> completeQuest(String questId) async {
    final response = await _httpClient
        .post(_buildUri('/api/v1/quests/$questId/complete'), headers: _headers)
        .timeout(_config.timeout);
    final data = _extractData(response);
    return CompletedQuestRecord.fromJson(
      _normalizeCompletedQuestJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  dynamic _extractData(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic>
          ? (error['message'] as String? ?? 'Request failed.')
          : 'Request failed.';
      throw RemoteApiException(message, statusCode: response.statusCode);
    }

    if (decoded['success'] != true) {
      throw RemoteApiException(
        'API request was not successful.',
        statusCode: response.statusCode,
      );
    }

    return decoded['data'];
  }

  Map<String, dynamic> _normalizeQuestJson(Map<String, dynamic> json) {
    return {
      'id': json['id'],
      'title': json['title'],
      'exp': json['exp'],
      'difficulty': json['difficulty'],
      'category': json['category'],
      'elapsedSeconds': json['elapsedSeconds'] ?? json['elapsed_seconds'] ?? 0,
      'defaultDurationSeconds':
          json['defaultDurationSeconds'] ?? json['default_duration_seconds'] ?? 0,
    };
  }

  Map<String, dynamic> _normalizeCompletedQuestJson(Map<String, dynamic> json) {
    return {
      'questId': json['questId'] ?? json['quest_id'] ?? '',
      'title': json['title'],
      'difficulty': json['difficulty'],
      'category': json['category'],
      'earnedExp': json['earnedExp'] ?? json['earned_exp'] ?? 0,
      'completedAt': json['completedAt'] ?? json['completed_at'] ?? '',
      'elapsedSeconds': json['elapsedSeconds'] ?? json['elapsed_seconds'] ?? 0,
      'proofImagePath': json['proofImagePath'] ?? json['proof_image_path'],
    };
  }
}
