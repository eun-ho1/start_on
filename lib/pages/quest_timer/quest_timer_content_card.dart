import 'package:flutter/material.dart';
import 'package:start_on/widgets/common.dart';

class QuestTimerContentCard extends StatelessWidget {
  const QuestTimerContentCard({
    super.key,
    required this.questSummary,
    required this.countdown,
    required this.actionButtons,
    required this.proofSection,
  });

  final Widget questSummary;
  final Widget countdown;
  final Widget actionButtons;
  final Widget proofSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        questSummary,
        const SizedBox(height: 28),
        countdown,
        const SizedBox(height: 20),
        actionButtons,
        const SizedBox(height: 28),
        proofSection,
      ],
    );
  }
}
