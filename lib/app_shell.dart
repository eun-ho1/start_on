import 'dart:async';

import 'package:start_on/models/app_local_data.dart';
import 'package:start_on/pages/add_quest_screen.dart';
import 'package:start_on/pages/auth_screen.dart';
import 'package:start_on/pages/auto_quest_from_gallery_screen.dart';
import 'package:start_on/pages/dungeon_screen.dart';
import 'package:start_on/pages/home_screen.dart';
import 'package:start_on/pages/quest_timer_screen.dart';
import 'package:start_on/pages/record_screen.dart';
import 'package:start_on/pages/settings_screen.dart';
import 'package:start_on/pages/shop_screen.dart';
import 'package:start_on/services/auth_service.dart';
import 'package:start_on/services/quest_timer_background_service.dart';
import 'package:start_on/services/remote_quest_api.dart';
import 'package:start_on/storage/app_settings_store.dart';
import 'package:start_on/storage/local_data_store.dart';
import 'package:start_on/widgets/common.dart';
import 'package:start_on/widgets/quest_completion_celebration.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AdFocusApp extends StatelessWidget {
  const AdFocusApp({
    super.key,
    this.useRemoteBackend = false,
    this.remoteBaseUrl = 'http://10.0.2.2:8000',
  });

  final bool useRemoteBackend;
  final String remoteBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Start On',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F3F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F63FF),
          brightness: Brightness.light,
        ),
        fontFamily: 'Pretendard',
      ),
      home: useRemoteBackend
          ? _RemoteAuthGate(remoteBaseUrl: remoteBaseUrl)
          : AdFocusShell(
              useRemoteBackend: useRemoteBackend,
              remoteBaseUrl: remoteBaseUrl,
            ),
    );
  }
}

class _RemoteAuthGate extends StatefulWidget {
  const _RemoteAuthGate({required this.remoteBaseUrl});

  final String remoteBaseUrl;

  @override
  State<_RemoteAuthGate> createState() => _RemoteAuthGateState();
}

class _RemoteAuthGateState extends State<_RemoteAuthGate> {
  final AuthService _authService = AuthService.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppAuthSession?>(
      stream: _authService.authStateChanges,
      initialData: _authService.currentSession,
      builder: (context, snapshot) {
        final session = snapshot.data ?? _authService.currentSession;
        if (session == null) {
          return AuthScreen(
            onSignIn: _signIn,
            onSignUp: _signUp,
          );
        }

        return AdFocusShell(
          useRemoteBackend: true,
          remoteBaseUrl: widget.remoteBaseUrl,
        );
      },
    );
  }

  Future<void> _signIn(String email, String password) async {
    try {
      await _authService.signIn(email: email, password: password);
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _signUp(String email, String password) async {
    try {
      await _authService.signUp(email: email, password: password);
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }
}

class AdFocusShell extends StatefulWidget {
  const AdFocusShell({
    super.key,
    this.useRemoteBackend = false,
    this.remoteBaseUrl = 'http://10.0.2.2:8000',
  });

  final bool useRemoteBackend;
  final String remoteBaseUrl;

  @override
  State<AdFocusShell> createState() => _AdFocusShellState();
}

class _AdFocusShellState extends State<AdFocusShell>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService.instance;
  final AppSettingsStore _settingsStore = const AppSettingsStore();
  final LocalDataStore _store = const LocalDataStore();
  final QuestTimerBackgroundService _questTimerService =
      QuestTimerBackgroundService.instance;
  late final RemoteQuestApi _remoteQuestApi = RemoteQuestApi(
    baseUrl: widget.remoteBaseUrl,
  );

  int _currentIndex = 0;
  int _celebrationSeed = 0;
  bool _isLoading = true;
  bool _isOpeningQuestTimer = false;
  bool _isQuestTimerRouteOpen = false;
  bool _notificationsEnabled = true;
  bool _showQuestCelebration = false;
  AppLocalData _localData = AppLocalData.initial();
  StreamSubscription<QuestTimerSnapshot>? _questTimerTickSubscription;
  late final AnimationController _fabPopController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fabPopScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.16,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 42,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.16,
        end: 0.94,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.94,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 30,
    ),
  ]).animate(_fabPopController);

  @override
  void initState() {
    super.initState();
    _listenToQuestTimerTicks();
    unawaited(_initializeAppState());
  }

  @override
  void dispose() {
    _lifecycleObserver.dispose();
    _questTimerTickSubscription?.cancel();
    _fabPopController.dispose();
    super.dispose();
  }

  late final AppLifecycleListener _lifecycleObserver = AppLifecycleListener(
    onResume: _handleAppResumed,
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(color: Color(0xFFF1F3F8)),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF6F63FF)),
          ),
        ),
      );
    }

    final screens = [
      HomeScreen(
        data: _localData,
        userName: _currentUserName,
        onAddQuest: _openAddQuest,
        onAddQuestForCategory: _openAddQuestForCategory,
        onQuestTap: _openQuestTimer,
        onDeleteQuest: _deleteQuest,
        onOpenSettings: _openSettings,
        onOpenAutoQuestFromGallery: _openAutoQuestFromGallery,
        onTabChange: _changeTab,
      ),
      DungeonScreen(data: _localData, onClearDungeon: _completeDungeon),
      ShopScreen(data: _localData),
      RecordScreen(data: _localData),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFFF1F3F8)),
            child: SafeArea(child: screens[_currentIndex]),
          ),
          if (_showQuestCelebration)
            Positioned(
              left: 0,
              right: 0,
              bottom: 46,
              height: 220,
              child: QuestCompletionCelebration(
                key: ValueKey(_celebrationSeed),
                seed: _celebrationSeed,
                onComplete: _hideQuestCelebration,
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: ScaleTransition(
        scale: _fabPopScale,
        child: NeumorphicRoundedCard(
          padding: EdgeInsets.zero,
          color: const Color(0xFFD0CBFF),
          borderRadius: 18,
          child: SizedBox(
            width: 56,
            height: 42,
            child: FloatingActionButton(
              onPressed: _openAddQuest,
              backgroundColor: const Color(0xFFD0CBFF),
              foregroundColor: const Color(0xFF6358FF),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded, size: 23),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  void _changeTab(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _openAddQuest() async {
    await _openAddQuestScreen();
  }

  Future<void> _openAddQuestForCategory(String category) async {
    await _openAddQuestScreen(initialCategory: category);
  }

  Future<void> _openAddQuestScreen({String? initialCategory}) async {
    final quest = await Navigator.of(context).push<QuestItem>(
      MaterialPageRoute<QuestItem>(
        builder: (_) => AddQuestScreen(initialCategory: initialCategory),
      ),
    );

    if (quest == null) {
      return;
    }

    if (widget.useRemoteBackend) {
      try {
        final createdQuest = await _remoteQuestApi.createQuest(
          _requireAccessToken(),
          quest,
        );
        _setLocalData(
          _localData.copyWith(quests: [createdQuest, ..._localData.quests]),
        );
        return;
      } on RemoteQuestApiException catch (error) {
        _showStyledSnackBar(error.message);
        return;
      } catch (_) {
        _showStyledSnackBar('Failed to create quest on the server.');
        return;
      }
    }

    _setLocalData(_localData.copyWith(quests: [quest, ..._localData.quests]));
  }

  Future<void> _openQuestTimer(QuestItem quest) async {
    _isOpeningQuestTimer = true;
    _isQuestTimerRouteOpen = true;
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => QuestTimerScreen(
          quest: quest,
          notificationsEnabled: _notificationsEnabled,
          onDelete: () => _deleteQuest(quest),
        ),
      ),
    );
    _isOpeningQuestTimer = false;
    _isQuestTimerRouteOpen = false;

    if (result == null) {
      return;
    }

    if (result case CompletedQuestRecord completedRecord) {
      if (widget.useRemoteBackend) {
        try {
          final remoteCompleted = await _remoteQuestApi.completeQuest(
            _requireAccessToken(),
            completedRecord.questId,
            completedRecord.elapsedSeconds,
            completedRecord.proofImagePath,
          );
          _setLocalData(_store.completeQuest(_localData, remoteCompleted));
          _triggerQuestCelebration();
          return;
        } on RemoteQuestApiException catch (error) {
          _showStyledSnackBar(error.message);
          return;
        } catch (_) {
          _showStyledSnackBar('Failed to complete quest on the server.');
          return;
        }
      }

      _setLocalData(_store.completeQuest(_localData, completedRecord));
      _triggerQuestCelebration();
      return;
    }

    if (result case QuestTimerScreenResult timerResult) {
      _updateQuest(timerResult.quest);
      if (timerResult.didPauseTimer) {
        _showStyledSnackBar('타이머 일시중지됨', centerText: true, compact: true);
      }
      return;
    }

    if (result case QuestItem updatedQuest) {
      _updateQuest(updatedQuest);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(
      context,
    ).push<SettingsScreenResult>(
      MaterialPageRoute<SettingsScreenResult>(
        builder: (_) => SettingsScreen(
          userName: _currentUserName,
          userEmail: _authService.currentUser?.email,
        ),
      ),
    );

    if (result == SettingsScreenResult.changeAccount && widget.useRemoteBackend) {
      await _authService.signOut();
      return;
    }

    await _reloadSettingsAfterSettingsScreen();
    await _reloadLocalDataAfterSettingsScreen();
  }

  Future<void> _openAutoQuestFromGallery() async {
    final generatedQuests = await Navigator.of(context).push<List<QuestItem>>(
      MaterialPageRoute<List<QuestItem>>(
        builder: (_) => const AutoQuestFromGalleryScreen(),
      ),
    );

    if (!mounted || generatedQuests == null || generatedQuests.isEmpty) {
      return;
    }

    _setLocalData(
      _localData.copyWith(quests: [...generatedQuests, ..._localData.quests]),
    );
    _showStyledSnackBar('${generatedQuests.length}개의 퀘스트를 추가했어요.');
  }

  void _deleteQuest(QuestItem quest) {
    unawaited(_deleteQuestAsync(quest));
  }

  void _updateQuest(QuestItem updatedQuest) {
    unawaited(_updateQuestAsync(updatedQuest));
  }

  void _completeDungeon(String dungeonId) {
    const dungeonRewards = {
      'dungeon_meditation': 8,
      'dungeon_evening_workout': 12,
    };

    final reward = dungeonRewards[dungeonId];
    if (reward == null) {
      return;
    }

    _setLocalData(
      _store.completeDungeon(
        _localData,
        dungeonId: dungeonId,
        creditReward: reward,
      ),
    );
  }

  Future<void> _loadLocalData() async {
    final data = await _buildLoadedLocalData();
    final activeSnapshot = await _safeCurrentQuestTimerState();

    if (!mounted) {
      return;
    }

    setState(() {
      _localData = data;
      _isLoading = false;
    });

    if (_notificationsEnabled && activeSnapshot?.isRunning == true) {
      unawaited(
        _openActiveQuestTimerIfNeeded(questId: activeSnapshot!.questId),
      );
    }
  }

  void _setLocalData(AppLocalData data) {
    setState(() => _localData = data);
    unawaited(_store.save(data, scope: _localDataScope));
  }

  void _showStyledSnackBar(
    String message, {
    bool centerText = false,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final textStyle =
        theme.snackBarTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        );

    final compactWidth = compact
        ? (() {
            final textPainter = TextPainter(
              text: TextSpan(text: message, style: textStyle),
              maxLines: 1,
              textDirection: Directionality.of(context),
            )..layout(maxWidth: mediaQuery.size.width - 72);
            return (textPainter.width + 32).clamp(
              120.0,
              mediaQuery.size.width - 40,
            );
          })()
        : null;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: centerText ? TextAlign.center : null,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF8B93),
          margin: compact ? null : const EdgeInsets.fromLTRB(20, 0, 20, 20),
          width: compact ? compactWidth : null,
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          duration: const Duration(seconds: 2),
        ),
        snackBarAnimationStyle: const AnimationStyle(
          curve: Curves.easeOutCubic,
          duration: Duration(milliseconds: 420),
          reverseCurve: Curves.easeInCubic,
          reverseDuration: Duration(milliseconds: 320),
        ),
      );
  }

  void _listenToQuestTimerTicks() {
    _questTimerTickSubscription = _questTimerService.timerTicks.listen((tick) {
      if (!mounted) {
        return;
      }

      setState(() {
        _localData = _copyWithQuestElapsed(
          _localData,
          questId: tick.questId,
          elapsedSeconds: tick.elapsedSeconds,
        );
      });
    });
  }

  AppLocalData _copyWithQuestElapsed(
    AppLocalData data, {
    required String questId,
    required int elapsedSeconds,
  }) {
    final nextQuests = data.quests
        .map(
          (item) => item.id == questId
              ? item.copyWith(elapsedSeconds: elapsedSeconds)
              : item,
        )
        .toList();
    return data.copyWith(quests: nextQuests);
  }

  Future<void> _stopQuestTimerIfActive(String questId) async {
    final snapshot = await _questTimerService.currentState();
    if (snapshot?.questId == questId && snapshot?.isRunning == true) {
      await _questTimerService.stopTimer();
    }
  }

  Future<void> _handleAppResumed() async {
    if (!_notificationsEnabled) {
      return;
    }

    final activeSnapshot = await _questTimerService.currentState();
    if (activeSnapshot?.isRunning != true) {
      return;
    }

    await _openActiveQuestTimerIfNeeded(questId: activeSnapshot!.questId);
  }

  Future<void> _openActiveQuestTimerIfNeeded({required String questId}) async {
    if (!mounted ||
        _isLoading ||
        _isOpeningQuestTimer ||
        _isQuestTimerRouteOpen) {
      return;
    }

    QuestItem? quest;
    for (final item in _localData.quests) {
      if (item.id == questId) {
        quest = item;
        break;
      }
    }

    if (quest == null) {
      return;
    }

    await _openQuestTimer(quest);
  }

  Future<void> _requestNotificationPermissionOnLaunch() async {
    if (!_notificationsEnabled) {
      return;
    }

    final status = await Permission.notification.status;
    if (status.isGranted || status.isPermanentlyDenied) {
      return;
    }

    await Permission.notification.request();
  }

  Future<void> _initializeAppState() async {
    try {
      await _loadNotificationSetting().timeout(const Duration(seconds: 3));
      await _requestNotificationPermissionOnLaunch().timeout(
        const Duration(seconds: 3),
      );
      await _loadLocalData().timeout(const Duration(seconds: 8));
    } catch (error) {
      final fallbackData = await _store.load(scope: _safeLocalDataScope);
      final activeSnapshot = await _safeCurrentQuestTimerState();
      final nextData = activeSnapshot == null
          ? fallbackData
          : _copyWithQuestElapsed(
              fallbackData,
              questId: activeSnapshot.questId,
              elapsedSeconds: activeSnapshot.elapsedSeconds,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _localData = nextData;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showStyledSnackBar('Failed to finish startup cleanly. Loaded local data instead.');
      });
    }
  }

  Future<void> _loadNotificationSetting() async {
    final settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    setState(() => _notificationsEnabled = settings.notificationsEnabled);
  }

  Future<void> _reloadSettingsAfterSettingsScreen() async {
    final previousValue = _notificationsEnabled;
    final settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    setState(() => _notificationsEnabled = settings.notificationsEnabled);

    if (previousValue && !settings.notificationsEnabled) {
      final activeSnapshot = await _questTimerService.currentState();
      if (activeSnapshot?.isRunning == true) {
        await _questTimerService.pauseTimer(
          questId: activeSnapshot!.questId,
          questTitle: activeSnapshot.questTitle,
          elapsedSeconds: activeSnapshot.elapsedSeconds,
          defaultDurationSeconds: activeSnapshot.defaultDurationSeconds,
        );
      }
    }
  }

  Future<void> _reloadLocalDataAfterSettingsScreen() async {
    final data = await _buildLoadedLocalData();
    if (!mounted) {
      return;
    }
    setState(() => _localData = data);
  }

  Future<AppLocalData> _buildLoadedLocalData() async {
    var data = await _store.load(scope: _safeLocalDataScope);
    if (widget.useRemoteBackend &&
        _authService.isConfigured &&
        _authService.currentSession != null) {
      try {
        final accessToken = _requireAccessToken();
        final remoteProfile = await _remoteQuestApi.fetchProfile(accessToken);
        final remoteStats = await _remoteQuestApi.fetchStats(accessToken);
        final remoteQuests = await _remoteQuestApi.fetchQuests(accessToken);
        data = data.copyWith(
          userName: remoteProfile['userName']?.toString() ?? data.userName,
          userRole: remoteProfile['userRole']?.toString() ?? data.userRole,
          level: _readInt(remoteProfile['level'], fallback: data.level),
          currentExp: _readInt(
            remoteProfile['currentExp'],
            fallback: data.currentExp,
          ),
          maxExp: _readInt(remoteProfile['maxExp'], fallback: data.maxExp),
          credits: _readInt(remoteProfile['credits'], fallback: data.credits),
          completedQuestCount: _readInt(
            remoteProfile['completedQuestCount'],
            fallback: data.completedQuestCount,
          ),
          earnedExp: _readInt(
            remoteProfile['earnedExp'],
            fallback: data.earnedExp,
          ),
          dailyRewardCount: _readInt(
            remoteStats['dailyRewardCount'],
            fallback: data.dailyRewardCount,
          ),
          dailyRewardTarget: _readInt(
            remoteStats['dailyRewardTarget'],
            fallback: data.dailyRewardTarget,
          ),
          weeklyRewardCount: _readInt(
            remoteStats['weeklyRewardCount'],
            fallback: data.weeklyRewardCount,
          ),
          weeklyRewardTarget: _readInt(
            remoteStats['weeklyRewardTarget'],
            fallback: data.weeklyRewardTarget,
          ),
          monthlyRewardCount: _readInt(
            remoteStats['monthlyRewardCount'],
            fallback: data.monthlyRewardCount,
          ),
          monthlyRewardTarget: _readInt(
            remoteStats['monthlyRewardTarget'],
            fallback: data.monthlyRewardTarget,
          ),
          weeklyCompletedCount: _readInt(
            remoteStats['weeklyCompletedCount'],
            fallback: data.weeklyCompletedCount,
          ),
          weeklyCompletionRate: _readInt(
            remoteStats['weeklyCompletionRate'],
            fallback: data.weeklyCompletionRate,
          ),
          weeklyRateDelta: _readInt(
            remoteStats['weeklyRateDelta'],
            fallback: data.weeklyRateDelta,
          ),
          diligenceStat: _readInt(
            remoteStats['diligenceStat'],
            fallback: data.diligenceStat,
          ),
          orderStat: _readInt(
            remoteStats['orderStat'],
            fallback: data.orderStat,
          ),
          intelligenceStat: _readInt(
            remoteStats['intelligenceStat'],
            fallback: data.intelligenceStat,
          ),
          healthStat: _readInt(
            remoteStats['healthStat'],
            fallback: data.healthStat,
          ),
          quests: remoteQuests,
        );
      } on RemoteQuestApiException catch (error) {
        if (mounted) {
          _showStyledSnackBar(error.message);
        }
      } catch (_) {
        if (mounted) {
          _showStyledSnackBar('Failed to load remote quests. Showing local data.');
        }
      }
    }
    final activeSnapshot = await _safeCurrentQuestTimerState();
    if (activeSnapshot != null) {
      data = _copyWithQuestElapsed(
        data,
        questId: activeSnapshot.questId,
        elapsedSeconds: activeSnapshot.elapsedSeconds,
      );
    }
    return data;
  }

  Future<QuestTimerSnapshot?> _safeCurrentQuestTimerState() async {
    try {
      return await _questTimerService.currentState();
    } catch (_) {
      return null;
    }
  }

  void _triggerQuestCelebration() {
    _fabPopController.forward(from: 0);
    setState(() {
      _celebrationSeed += 1;
      _showQuestCelebration = true;
    });
  }

  void _hideQuestCelebration() {
    if (!mounted) {
      return;
    }
    setState(() => _showQuestCelebration = false);
  }

  Future<void> _deleteQuestAsync(QuestItem quest) async {
    await _stopQuestTimerIfActive(quest.id);

    if (widget.useRemoteBackend) {
      try {
        await _remoteQuestApi.deleteQuest(_requireAccessToken(), quest.id);
      } on RemoteQuestApiException catch (error) {
        _showStyledSnackBar(error.message);
        return;
      } catch (_) {
        _showStyledSnackBar('Failed to delete quest on the server.');
        return;
      }
    }

    _setLocalData(
      _localData.copyWith(
        quests: _localData.quests.where((item) => item.id != quest.id).toList(),
      ),
    );
  }

  Future<void> _updateQuestAsync(QuestItem updatedQuest) async {
    QuestItem nextQuest = updatedQuest;
    if (widget.useRemoteBackend) {
      try {
        nextQuest = await _remoteQuestApi.updateQuest(
          _requireAccessToken(),
          updatedQuest.id,
          updatedQuest.toJson(),
        );
      } on RemoteQuestApiException catch (error) {
        _showStyledSnackBar(error.message);
        return;
      } catch (_) {
        _showStyledSnackBar('Failed to update quest on the server.');
        return;
      }
    }

    _setLocalData(
      _localData.copyWith(
        quests: _localData.quests
            .map((item) => item.id == updatedQuest.id ? nextQuest : item)
            .toList(),
      ),
    );
  }

  String get _localDataScope {
    final userId = _authService.currentUser?.id;
    if (widget.useRemoteBackend && userId != null && userId.isNotEmpty) {
      return userId;
    }
    return 'guest';
  }

  String get _safeLocalDataScope {
    try {
      return _localDataScope;
    } catch (_) {
      return 'guest';
    }
  }

  String _requireAccessToken() {
    final token = _authService.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const RemoteQuestApiException('로그인 세션이 만료되었습니다. 다시 로그인해주세요.');
    }
    return token;
  }

  int _readInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  String get _currentUserName {
    final email = _authService.currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Guest';
  }
}
