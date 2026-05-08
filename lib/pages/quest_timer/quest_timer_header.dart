import 'package:flutter/material.dart';

class QuestTimerHeader extends StatelessWidget {
  const QuestTimerHeader({
    super.key,
    required this.onBack,
    required this.onDelete,
  });

  final VoidCallback onBack;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const SizedBox(width: 4),
        const Text(
          '퀘스트 진행',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C2940),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('삭제'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF7F88)),
        ),
      ],
    );
  }
}
