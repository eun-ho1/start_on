import 'package:start_on/models/app_local_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart' as neu;

//퀘스트 추가dialog
class AddQuestDialog extends StatefulWidget {
  const AddQuestDialog({
    super.key,
    this.initialCategory,
    this.initialQuest,
    this.title = 'Create New Task',
    this.submitLabel = 'Create',
  });

  final String? initialCategory;
  final QuestItem? initialQuest;
  final String title;
  final String submitLabel;

  @override
  State<AddQuestDialog> createState() => _AddQuestDialogState();
}

class _AddQuestDialogState extends State<AddQuestDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  String _difficulty = '보통';
  String _category = 'work';
  bool _showTitleError = false;

  @override
  void initState() {
    super.initState();
    final initialQuest = widget.initialQuest;
    if (initialQuest != null) {
      _controller.text = initialQuest.title;
      _difficulty = initialQuest.difficulty;
      _category = normalizeQuestCategory(initialQuest.category);
      return;
    }

    final initialCategory = widget.initialCategory;
    if (initialCategory != null && questCategories.contains(initialCategory)) {
      _category = initialCategory;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final defaultDurationSeconds = defaultQuestDurationSecondsForDifficulty(
      _difficulty,
    );
    final categoryStyle = questCategoryStyleFor(_category);
    final hasTitleText = _controller.text.trim().isNotEmpty;
    final insetLightShadow = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.88),
      categoryStyle.backgroundColor,
    );
    final insetDarkShadow = Color.alphaBlend(
      categoryStyle.accentColor.withValues(alpha: 0.44),
      categoryStyle.backgroundColor,
    );
    final raisedFill = Color.alphaBlend(
      categoryStyle.accentColor.withValues(alpha: 0.12),
      categoryStyle.backgroundColor,
    );

    return Dialog(
      backgroundColor: categoryStyle.backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: categoryStyle.accentColor.withValues(alpha: 0.24),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(28, 26, 28, 28 + viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: categoryStyle.accentColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF95A0B4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF33415C),
                ),
              ),
              const SizedBox(height: 10),
              neu.Neumorphic(
                style: neu.NeumorphicStyle(
                  depth: hasTitleText ? 8 : -3,
                  intensity: hasTitleText ? 0.88 : 0.92,
                  surfaceIntensity: hasTitleText ? 0.26 : 0.28,
                  color: hasTitleText
                      ? raisedFill
                      : categoryStyle.backgroundColor,
                  shadowLightColor: hasTitleText
                      ? Colors.white.withValues(alpha: 0.98)
                      : insetLightShadow,
                  shadowDarkColor: hasTitleText
                      ? categoryStyle.accentColor.withValues(alpha: 0.4)
                      : insetDarkShadow,
                  boxShape: neu.NeumorphicBoxShape.roundRect(
                    BorderRadius.circular(18),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _controller,
                  focusNode: _titleFocusNode,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_showTitleError && _controller.text.trim().isNotEmpty) {
                      setState(() => _showTitleError = false);
                      return;
                    }
                    setState(() {});
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: '예: 아침 운동하기',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 18),
                    isCollapsed: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF33415C),
                  ),
                ),
              ),
              if (_showTitleError) ...[
                const SizedBox(height: 10),
                Text(
                  'Title을 입력해야 태스크를 만들 수 있어요.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: categoryStyle.accentColor,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF33415C),
                ),
              ),
              const SizedBox(height: 12),
              ChoiceRow(
                values: const ['쉬움', '보통', '어려움'],
                selected: _difficulty,
                selectedColor: categoryStyle.accentColor,
                backgroundColor: categoryStyle.backgroundColor,
                onSelected: (value) => setState(() => _difficulty = value),
              ),
              const SizedBox(height: 10),
              Text(
                '진행시간 : ${_formatMinutesLabel(defaultDurationSeconds)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7E899D),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF33415C),
                ),
              ),
              const SizedBox(height: 12),
              ChoiceRow(
                values: questCategories,
                selected: _category,
                selectedColor: categoryStyle.accentColor,
                backgroundColor: categoryStyle.backgroundColor,
                labelBuilder: questCategoryLabel,
                onSelected: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: categoryStyle.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(widget.submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showTitleError = true);
      _titleFocusNode.requestFocus();
      return;
    }

    final initialQuest = widget.initialQuest;
    final exp = expForDifficulty(_difficulty);

    Navigator.of(context).pop(
      (initialQuest ??
              QuestItem(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: '',
                exp: exp,
                difficulty: _difficulty,
                category: _category,
                elapsedSeconds: 0,
                defaultDurationSeconds:
                    defaultQuestDurationSecondsForDifficulty(_difficulty),
              ))
          .copyWith(
            title: name,
            exp: exp,
            difficulty: _difficulty,
            category: _category,
            elapsedSeconds: initialQuest?.elapsedSeconds ?? 0,
            defaultDurationSeconds: defaultQuestDurationSecondsForDifficulty(
              _difficulty,
            ),
          ),
    );
  }

  String _formatMinutesLabel(int seconds) {
    return '${seconds ~/ 60}분';
  }
}

int expForDifficulty(String difficulty) {
  return switch (difficulty) {
    '쉬움' => 30,
    '보통' => 50,
    _ => 100,
  };
}

class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    required this.values,
    required this.selected,
    required this.selectedColor,
    required this.backgroundColor,
    required this.onSelected,
    this.labelBuilder,
    super.key,
  });

  final List<String> values;
  final String selected;
  final Color selectedColor;
  final Color backgroundColor;
  final ValueChanged<String> onSelected;
  final String Function(String value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(values[i]),
              child: neu.Neumorphic(
                style: _styleFor(values[i] == selected),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labelBuilder?.call(values[i]) ?? values[i],
                        maxLines: 1,
                        style: TextStyle(
                          color: values[i] == selected
                              ? selectedColor
                              : const Color(0xFF667085),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i != values.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  neu.NeumorphicStyle _styleFor(bool isSelected) {
    final selectedFill = Color.alphaBlend(
      selectedColor.withValues(alpha: 0.16),
      backgroundColor,
    );
    final insetLightShadow = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.88),
      backgroundColor,
    );
    final insetDarkShadow = Color.alphaBlend(
      selectedColor.withValues(alpha: 0.34),
      backgroundColor,
    );

    return neu.NeumorphicStyle(
      depth: isSelected ? 3 : -3,
      intensity: isSelected ? 0.88 : 0.94,
      surfaceIntensity: isSelected ? 0.32 : 0.22,
      color: isSelected ? selectedFill : backgroundColor,
      shadowLightColor: isSelected
          ? Colors.white.withValues(alpha: 0.98)
          : insetLightShadow,
      shadowDarkColor: isSelected
          ? selectedColor.withValues(alpha: 0.42)
          : insetDarkShadow,
      boxShape: neu.NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
    );
  }
}
