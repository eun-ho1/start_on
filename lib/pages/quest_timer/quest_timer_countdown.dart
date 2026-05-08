import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart' as neu;

class QuestTimerCountdown extends StatelessWidget {
  const QuestTimerCountdown({
    super.key,
    required this.controller,
    required this.durationSeconds,
    required this.elapsedSeconds,
    required this.timerViewRevision,
    required this.running,
    required this.onComplete,
    required this.formatDuration,
  });

  final CountDownController controller;
  final int durationSeconds;
  final int elapsedSeconds;
  final int timerViewRevision;
  final bool running;
  final VoidCallback onComplete;
  final String Function(Duration duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final clampedElapsedSeconds = elapsedSeconds > durationSeconds
        ? durationSeconds
        : elapsedSeconds;

    return Column(
      children: [
        // 패키지가 중앙 child를 직접 받지 않아서 Stack으로 링과 중앙 정보를 겹친다.
        Stack(
          alignment: Alignment.center,
          children: [
            CircularCountDownTimer(
              key: ValueKey(
                '${clampedElapsedSeconds == durationSeconds}:$timerViewRevision',
              ),
              duration: durationSeconds,
              initialDuration: clampedElapsedSeconds,
              controller: controller,
              width: 264,
              height: 264,
              autoStart: false,
              isReverse: false,
              isReverseAnimation: false,
              strokeWidth: 18,
              strokeCap: StrokeCap.round,
              ringColor: const Color(0xFFE8EDF6),
              fillColor: const Color(0xFFFFA0AB),
              backgroundColor: Colors.transparent,
              isTimerTextShown: false,
              onComplete: onComplete,
              timeFormatterFunction: (defaultFormatterFunction, duration) {
                return formatDuration(duration);
              },
            ),
            _QuestTimerCore(
              elapsed: formatDuration(Duration(seconds: elapsedSeconds)),
              maxDurationLabel: 'MAX ${_formatMaxDuration(durationSeconds)}',
              running: running,
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

// 원형 타이머 중앙에 들어가는 상태/시간 표시 영역.
class _QuestTimerCore extends StatelessWidget {
  const _QuestTimerCore({
    required this.elapsed,
    required this.maxDurationLabel,
    required this.running,
  });

  final String elapsed;
  final String maxDurationLabel;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 184,
      height: 184,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: running
                  ? const Color(0xFFFFEEF0)
                  : const Color(0xFFF1F4FA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              running ? 'RUNNING' : 'READY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: running
                    ? const Color(0xFFE76D7B)
                    : const Color(0xFF7E899D),
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          neu.Neumorphic(
            style: neu.NeumorphicStyle(
              depth: 6,
              intensity: 0.9,
              surfaceIntensity: 0.18,
              color: const Color(0xFFF8FBFF),
              shadowLightColor: Colors.white.withValues(alpha: 0.98),
              shadowDarkColor: const Color(0xFFD5DDEA),
              boxShape: neu.NeumorphicBoxShape.roundRect(
                BorderRadius.circular(18),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              elapsed,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C2940),
                letterSpacing: -1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4FA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: Color(0xFF667085),
                ),
                const SizedBox(width: 6),
                Text(
                  maxDurationLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMaxDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) {
    return '$hours시간 ${minutes.toString().padLeft(2, '0')}분';
  }
  return '$minutes분';
}
