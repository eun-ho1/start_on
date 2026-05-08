import 'package:flutter/foundation.dart';
import 'package:start_on/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:start_on/services/auth_service.dart';
import 'package:start_on/services/quest_timer_background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const remoteBackendFromEnv = bool.fromEnvironment(
    'USE_REMOTE_BACKEND',
    defaultValue: true,
  );
  const remoteBaseUrl = String.fromEnvironment(
    'REMOTE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  final useRemoteBackend = remoteBackendFromEnv;

  if (useRemoteBackend) {
    AuthService.instance.configure(baseUrl: remoteBaseUrl);
    await AuthService.instance.initialize();
    debugPrint('[Startup] Remote auth service initialized.');
  }

  try {
    await QuestTimerBackgroundService.instance.initialize().timeout(
      const Duration(seconds: 5),
    );
  } catch (error, stackTrace) {
    debugPrint('[Startup] Background service initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    AdFocusApp(
      useRemoteBackend: useRemoteBackend,
      remoteBaseUrl: remoteBaseUrl,
    ),
  );
}
