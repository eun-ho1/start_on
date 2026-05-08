import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart' as neu;

class QuestTimerActionButtons extends StatelessWidget {
  const QuestTimerActionButtons({
    super.key,
    required this.isCompleting,
    required this.running,
    required this.canReset,
    required this.onResetTimer,
    required this.onToggleTimer,
    required this.onStopTimer,
  });

  final bool isCompleting;
  final bool running;
  final bool canReset;
  final VoidCallback onResetTimer;
  final VoidCallback onToggleTimer;
  final VoidCallback onStopTimer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QuestTimerCircleButton(
          icon: Icons.replay_rounded,
          color: const Color(0xFF89C2FF),
          onTap: isCompleting || !canReset ? null : onResetTimer,
        ),
        const SizedBox(width: 18),
        _QuestTimerCircleButton(
          icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: const Color(0xFFFF8B93),
          iconSize: running ? 28 : 32,
          onTap: isCompleting ? null : onToggleTimer,
          loading: isCompleting,
        ),
        const SizedBox(width: 18),
        _QuestTimerCircleButton(
          icon: Icons.stop_rounded,
          color: const Color(0xFFBFC8D7),
          onTap: isCompleting ? null : onStopTimer,
        ),
      ],
    );
  }
}

class _QuestTimerCircleButton extends StatelessWidget {
  const _QuestTimerCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconSize = 26,
    this.loading = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double iconSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.42,
        child: neu.Neumorphic(
          style: neu.NeumorphicStyle(
            depth: 7,
            intensity: 0.9,
            surfaceIntensity: 0.22,
            color: Color.alphaBlend(
              color.withValues(alpha: 0.14),
              const Color(0xFFF8FBFF),
            ),
            shadowLightColor: Colors.white.withValues(alpha: 0.98),
            shadowDarkColor: color.withValues(alpha: 0.28),
            boxShape: const neu.NeumorphicBoxShape.circle(),
          ),
          child: SizedBox(
            width: 70,
            height: 70,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}
