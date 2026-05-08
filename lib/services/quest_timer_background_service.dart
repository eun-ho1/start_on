import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:start_on/storage/app_settings_store.dart';

const String _questTimerTickEvent = 'quest_timer_tick';
const String _questTimerResumeAction = 'quest_timer_resume';
const String _questTimerPauseAction = 'quest_timer_pause';
const String _questTimerStopAction = 'quest_timer_stop';

const String _prefsQuestIdKey = 'quest_timer.quest_id';
const String _prefsQuestTitleKey = 'quest_timer.quest_title';
const String _prefsElapsedSecondsKey = 'quest_timer.elapsed_seconds';
const String _prefsDefaultDurationKey = 'quest_timer.default_duration_seconds';
const String _prefsIsRunningKey = 'quest_timer.is_running';

class QuestTimerSnapshot {
  const QuestTimerSnapshot({
    required this.questId,
    required this.questTitle,
    required this.elapsedSeconds,
    required this.defaultDurationSeconds,
    required this.isRunning,
  });

  final String questId;
  final String questTitle;
  final int elapsedSeconds;
  final int defaultDurationSeconds;
  final bool isRunning;

  QuestTimerSnapshot copyWith({
    String? questId,
    String? questTitle,
    int? elapsedSeconds,
    int? defaultDurationSeconds,
    bool? isRunning,
  }) {
    return QuestTimerSnapshot(
      questId: questId ?? this.questId,
      questTitle: questTitle ?? this.questTitle,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      defaultDurationSeconds:
          defaultDurationSeconds ?? this.defaultDurationSeconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questId': questId,
      'questTitle': questTitle,
      'elapsedSeconds': elapsedSeconds,
      'defaultDurationSeconds': defaultDurationSeconds,
      'isRunning': isRunning,
    };
  }

  static QuestTimerSnapshot? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }

    final questId = map['questId'] as String?;
    if (questId == null || questId.isEmpty) {
      return null;
    }

    return QuestTimerSnapshot(
      questId: questId,
      questTitle: map['questTitle'] as String? ?? '',
      elapsedSeconds: (map['elapsedSeconds'] as num?)?.toInt() ?? 0,
      defaultDurationSeconds:
          (map['defaultDurationSeconds'] as num?)?.toInt() ?? 0,
      isRunning: map['isRunning'] as bool? ?? false,
    );
  }
}

class QuestTimerBackgroundService {
  QuestTimerBackgroundService._();

  static final QuestTimerBackgroundService instance =
      QuestTimerBackgroundService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Stream<QuestTimerSnapshot> get timerTicks {
    return _service
        .on(_questTimerTickEvent)
        .map((data) {
          final normalized = data == null
              ? null
              : Map<String, dynamic>.from(data);
          return QuestTimerSnapshot.fromMap(normalized);
        })
        .where((snapshot) => snapshot != null)
        .cast<QuestTimerSnapshot>();
  }

  Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: questTimerBackgroundOnStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        initialNotificationTitle: '퀘스트 진행 중',
        initialNotificationContent: '백그라운드 타이머 준비 중',
        foregroundServiceNotificationId: 9042,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: questTimerBackgroundOnStart,
        onBackground: questTimerBackgroundOnIosBackground,
      ),
    );

    final settings = await const AppSettingsStore().load();
    final snapshot = await currentState();
    if (!settings.notificationsEnabled) {
      if (snapshot?.isRunning == true) {
        await pauseTimer(
          questId: snapshot!.questId,
          questTitle: snapshot.questTitle,
          elapsedSeconds: snapshot.elapsedSeconds,
          defaultDurationSeconds: snapshot.defaultDurationSeconds,
        );
      }
      return;
    }

    if (snapshot?.isRunning != true) {
      return;
    }

    if (!await _service.isRunning()) {
      await _service.startService();
    }
  }

  Future<void> startOrResumeTimer({
    required String questId,
    required String questTitle,
    required int elapsedSeconds,
    required int defaultDurationSeconds,
  }) async {
    final snapshot = QuestTimerSnapshot(
      questId: questId,
      questTitle: questTitle,
      elapsedSeconds: elapsedSeconds,
      defaultDurationSeconds: defaultDurationSeconds,
      isRunning: true,
    );

    await _persistSnapshot(snapshot);

    if (await _service.isRunning()) {
      _service.invoke(_questTimerResumeAction, snapshot.toMap());
      return;
    }

    await _service.startService();
  }

  Future<void> pauseTimer({
    required String questId,
    required String questTitle,
    required int elapsedSeconds,
    required int defaultDurationSeconds,
  }) async {
    final snapshot = QuestTimerSnapshot(
      questId: questId,
      questTitle: questTitle,
      elapsedSeconds: elapsedSeconds,
      defaultDurationSeconds: defaultDurationSeconds,
      isRunning: false,
    );

    await _persistSnapshot(snapshot);

    if (await _service.isRunning()) {
      _service.invoke(_questTimerPauseAction, snapshot.toMap());
    }
  }

  Future<void> stopTimer() async {
    await _clearSnapshot();

    if (await _service.isRunning()) {
      _service.invoke(_questTimerStopAction);
    }
  }

  Future<QuestTimerSnapshot?> currentState() async {
    final prefs = await SharedPreferences.getInstance();
    final questId = prefs.getString(_prefsQuestIdKey);
    if (questId == null || questId.isEmpty) {
      return null;
    }

    return QuestTimerSnapshot(
      questId: questId,
      questTitle: prefs.getString(_prefsQuestTitleKey) ?? '',
      elapsedSeconds: prefs.getInt(_prefsElapsedSecondsKey) ?? 0,
      defaultDurationSeconds: prefs.getInt(_prefsDefaultDurationKey) ?? 0,
      isRunning: prefs.getBool(_prefsIsRunningKey) ?? false,
    );
  }

  Future<void> _persistSnapshot(QuestTimerSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsQuestIdKey, snapshot.questId);
    await prefs.setString(_prefsQuestTitleKey, snapshot.questTitle);
    await prefs.setInt(_prefsElapsedSecondsKey, snapshot.elapsedSeconds);
    await prefs.setInt(
      _prefsDefaultDurationKey,
      snapshot.defaultDurationSeconds,
    );
    await prefs.setBool(_prefsIsRunningKey, snapshot.isRunning);
  }

  Future<void> _clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsQuestIdKey);
    await prefs.remove(_prefsQuestTitleKey);
    await prefs.remove(_prefsElapsedSecondsKey);
    await prefs.remove(_prefsDefaultDurationKey);
    await prefs.remove(_prefsIsRunningKey);
  }
}

@pragma('vm:entry-point')
Future<bool> questTimerBackgroundOnIosBackground(
  ServiceInstance service,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void questTimerBackgroundOnStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  Timer? ticker;

  Future<QuestTimerSnapshot?> loadSnapshot() async {
    final questId = prefs.getString(_prefsQuestIdKey);
    if (questId == null || questId.isEmpty) {
      return null;
    }

    return QuestTimerSnapshot(
      questId: questId,
      questTitle: prefs.getString(_prefsQuestTitleKey) ?? '',
      elapsedSeconds: prefs.getInt(_prefsElapsedSecondsKey) ?? 0,
      defaultDurationSeconds: prefs.getInt(_prefsDefaultDurationKey) ?? 0,
      isRunning: prefs.getBool(_prefsIsRunningKey) ?? false,
    );
  }

  Future<void> persistSnapshot(QuestTimerSnapshot snapshot) async {
    await prefs.setString(_prefsQuestIdKey, snapshot.questId);
    await prefs.setString(_prefsQuestTitleKey, snapshot.questTitle);
    await prefs.setInt(_prefsElapsedSecondsKey, snapshot.elapsedSeconds);
    await prefs.setInt(
      _prefsDefaultDurationKey,
      snapshot.defaultDurationSeconds,
    );
    await prefs.setBool(_prefsIsRunningKey, snapshot.isRunning);
  }

  Future<void> clearSnapshot() async {
    await prefs.remove(_prefsQuestIdKey);
    await prefs.remove(_prefsQuestTitleKey);
    await prefs.remove(_prefsElapsedSecondsKey);
    await prefs.remove(_prefsDefaultDurationKey);
    await prefs.remove(_prefsIsRunningKey);
  }

  Future<void> updateNotification(QuestTimerSnapshot snapshot) async {
    if (service is! AndroidServiceInstance) {
      return;
    }

    await service.setForegroundNotificationInfo(
      title: '퀘스트 진행 중',
      content:
          '${snapshot.questTitle}  ${_formatElapsed(snapshot.elapsedSeconds)}',
    );
  }

  Future<void> emitSnapshot(QuestTimerSnapshot snapshot) async {
    service.invoke(_questTimerTickEvent, snapshot.toMap());
    await updateNotification(snapshot);
  }

  void stopTicker() {
    ticker?.cancel();
    ticker = null;
  }

  Future<void> startTicker(QuestTimerSnapshot snapshot) async {
    stopTicker();
    await emitSnapshot(snapshot);

    ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final current = await loadSnapshot();
      if (current == null || !current.isRunning) {
        return;
      }

      final nextSnapshot = current.copyWith(
        elapsedSeconds: current.elapsedSeconds + 1,
      );
      await persistSnapshot(nextSnapshot);
      await emitSnapshot(nextSnapshot);
    });
  }

  final initialSnapshot = await loadSnapshot();
  if (initialSnapshot == null || !initialSnapshot.isRunning) {
    service.stopSelf();
    return;
  }

  await startTicker(initialSnapshot);

  service.on(_questTimerResumeAction).listen((data) async {
    final snapshot = QuestTimerSnapshot.fromMap(
      data == null ? null : Map<String, dynamic>.from(data),
    );
    if (snapshot == null) {
      return;
    }

    await persistSnapshot(snapshot.copyWith(isRunning: true));
    await startTicker(snapshot.copyWith(isRunning: true));
  });

  service.on(_questTimerPauseAction).listen((data) async {
    final snapshot = QuestTimerSnapshot.fromMap(
      data == null ? null : Map<String, dynamic>.from(data),
    );
    if (snapshot == null) {
      stopTicker();
      service.stopSelf();
      return;
    }

    final pausedSnapshot = snapshot.copyWith(isRunning: false);
    await persistSnapshot(pausedSnapshot);
    await emitSnapshot(pausedSnapshot);
    stopTicker();
    service.stopSelf();
  });

  service.on(_questTimerStopAction).listen((_) async {
    stopTicker();
    await clearSnapshot();
    service.stopSelf();
  });
}

String _formatElapsed(int elapsedSeconds) {
  final hours = (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
