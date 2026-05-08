import 'dart:convert';
import 'dart:io';

import 'package:start_on/models/app_local_data.dart';

class NotionSyncConfig {
  const NotionSyncConfig({required this.apiToken, required this.databaseInput});

  final String apiToken;
  final String databaseInput;
}

class NotionSyncResult {
  const NotionSyncResult({
    required this.databaseId,
    required this.databaseTitle,
    required this.quests,
  });

  final String databaseId;
  final String databaseTitle;
  final List<QuestItem> quests;
}

class NotionSyncException implements Exception {
  const NotionSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotionSyncService {
  const NotionSyncService();

  static const _backendBaseUrl = String.fromEnvironment(
    'REMOTE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const _defaultUserId = '00000000-0000-0000-0000-000000000001';

  Future<NotionSyncResult> syncDatabase(NotionSyncConfig config) async {
    final trimmedToken = config.apiToken.trim();
    final trimmedInput = config.databaseInput.trim();
    if (trimmedToken.isEmpty) {
      throw const NotionSyncException('Notion integration secret을 입력해 주세요.');
    }
    if (trimmedInput.isEmpty) {
      throw const NotionSyncException(
        'Notion data source ID 또는 데이터베이스 URL/ID를 입력해 주세요.',
      );
    }

    await _postJson(
      path: '/api/v1/integrations/notion/connect',
      body: {
        'user_id': _defaultUserId,
        'notion_api_token': trimmedToken,
        'database_id': normalizeDatabaseId(trimmedInput),
        'database_url': trimmedInput,
      },
    );

    final data = await _postJson(
      path: '/api/v1/integrations/notion/sync',
      body: {'user_id': _defaultUserId},
    );

    return NotionSyncResult(
      databaseId: data['database_id'] as String? ?? '',
      databaseTitle: data['database_title'] as String? ?? '',
      quests: ((data['quests'] as List<dynamic>? ?? const []))
          .map(
            (item) => QuestItem.fromJson(
              _normalizeQuest(Map<String, dynamic>.from(item as Map)),
            ),
          )
          .toList(),
    );
  }

  static String normalizeDatabaseId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final match = RegExp(
      r'[0-9a-fA-F]{8}(?:-?[0-9a-fA-F]{4}){3}-?[0-9a-fA-F]{12}',
    ).firstMatch(trimmed);
    if (match == null) {
      return '';
    }

    final compact = match.group(0)!.replaceAll('-', '');
    return [
      compact.substring(0, 8),
      compact.substring(8, 12),
      compact.substring(12, 16),
      compact.substring(16, 20),
      compact.substring(20, 32),
    ].join('-');
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$_backendBaseUrl$path'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(responseBody) as Map);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        final error = decoded['error'];
        final message = error is Map<String, dynamic>
            ? (error['message'] as String? ?? 'Notion sync failed.')
            : 'Notion sync failed.';
        throw NotionSyncException(message);
      }

      return Map<String, dynamic>.from(decoded['data'] as Map? ?? const {});
    } on SocketException {
      throw const NotionSyncException(
        '네트워크 연결이 없어 Notion 동기화에 실패했습니다.',
      );
    } on FormatException {
      throw const NotionSyncException('백엔드 응답을 해석하지 못했습니다.');
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _normalizeQuest(Map<String, dynamic> json) {
    return {
      'id': json['id'] ?? 'notion:${json['title'] ?? DateTime.now().microsecondsSinceEpoch}',
      'title': json['title'] ?? '',
      'exp': json['exp'] ?? 0,
      'difficulty': json['difficulty'] ?? 'normal',
      'category': json['category'] ?? 'work',
      'elapsedSeconds': json['elapsedSeconds'] ?? 0,
      'defaultDurationSeconds': json['defaultDurationSeconds'] ?? 0,
    };
  }
}
