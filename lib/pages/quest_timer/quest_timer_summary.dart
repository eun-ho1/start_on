import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart' as neu;
import 'package:start_on/models/app_local_data.dart';

class QuestTimerSummary extends StatelessWidget {
  const QuestTimerSummary({
    super.key,
    required this.quest,
    required this.earnedExp,
    required this.maxDurationSeconds,
  });

  final QuestItem quest;
  final int earnedExp;
  final int maxDurationSeconds;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = questCategoryLabel(quest.category);

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 280),
            child: neu.Neumorphic(
              style: neu.NeumorphicStyle(
                depth: 7,
                intensity: 0.9,
                surfaceIntensity: 0.18,
                color: const Color(0xFFF8FBFF),
                shadowLightColor: Colors.white.withValues(alpha: 0.98),
                shadowDarkColor: const Color(0xFFD5DDEA),
                boxShape: neu.NeumorphicBoxShape.roundRect(
                  BorderRadius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Text(
                quest.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C2940),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            QuestTimerInfoChip(
              icon: Icons.workspace_premium_outlined,
              label: quest.difficulty,
              backgroundColor: const Color(0xFFFFF2DC),
              foregroundColor: const Color(0xFFC98A0A),
            ),
            QuestTimerInfoChip(
              icon: Icons.auto_awesome_rounded,
              label: '$earnedExp EXP',
              backgroundColor: const Color(0xFFFFEEF0),
              foregroundColor: const Color(0xFFD96A77),
            ),
            QuestTimerInfoChip(
              icon: Icons.category_outlined,
              label: categoryLabel,
              backgroundColor: const Color(0xFFEEF5FF),
              foregroundColor: const Color(0xFF4A78B8),
            ),
          ],
        ),
      ],
    );
  }
}

// 퀘스트 난이도, 보상, 카테고리 같은 요약 정보를 공통 칩으로 표시한다.
class QuestTimerInfoChip extends StatelessWidget {
  const QuestTimerInfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return neu.Neumorphic(
      style: neu.NeumorphicStyle(
        depth: 5,
        intensity: 0.88,
        surfaceIntensity: 0.18,
        color: backgroundColor,
        shadowLightColor: Colors.white.withValues(alpha: 0.98),
        shadowDarkColor: foregroundColor.withValues(alpha: 0.18),
        boxShape: const neu.NeumorphicBoxShape.stadium(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}
