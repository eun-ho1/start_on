import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:start_on/dialogs/add_quest_dialog.dart';
import 'package:start_on/models/quest_category.dart';
import 'package:start_on/models/quest_item.dart';
import 'package:start_on/services/quest_candidate_generator.dart';
import 'package:start_on/services/quest_ocr_service.dart';
import 'package:start_on/widgets/common.dart';

class AutoQuestFromGalleryScreen extends StatefulWidget {
  const AutoQuestFromGalleryScreen({super.key});

  @override
  State<AutoQuestFromGalleryScreen> createState() =>
      _AutoQuestFromGalleryScreenState();
}

class _AutoQuestFromGalleryScreenState
    extends State<AutoQuestFromGalleryScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final QuestOcrService _ocrService = QuestOcrService();
  final QuestCandidateGenerator _candidateGenerator = QuestCandidateGenerator();
  final TextEditingController _ocrTextController = TextEditingController();

  XFile? _selectedImage;
  bool _isPicking = false;
  bool _isRecognizing = false;
  bool _isGeneratingCandidates = false;
  List<_QuestCandidateDraft> _candidateDrafts = const [];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickFromGallery();
    });
  }

  @override
  void dispose() {
    _ocrTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _candidateDrafts
        .where((item) => item.isSelected)
        .length;
    final hasRecognizedText = _ocrTextController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8EF), Color(0xFFF7FBFF), Color(0xFFFFF0F3)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '자동 퀘스트 추가',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C2940),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              RoundedCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      icon: Icons.auto_fix_high_rounded,
                      title: '이미지 -> OCR -> 퀘스트 후보',
                    ),
                    const SizedBox(height: 18),
                    _ImagePreviewCard(
                      imagePath: _selectedImage?.path,
                      isPicking: _isPicking,
                      isRecognizing: _isRecognizing,
                      onPickAgain: _pickFromGallery,
                      onRunOcr: _selectedImage == null ? null : _runOcrPipeline,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: _selectedImage == null ? '이미지 대기' : '이미지 준비',
                          icon: Icons.image_outlined,
                          color: const Color(0xFFFFE8CC),
                          foregroundColor: const Color(0xFF925A00),
                        ),
                        _StatusChip(
                          label: _isRecognizing ? 'OCR 실행 중' : 'OCR 준비',
                          icon: Icons.text_snippet_outlined,
                          color: const Color(0xFFE5F0FF),
                          foregroundColor: const Color(0xFF2B5DA8),
                        ),
                        _StatusChip(
                          label: selectedCount == 0
                              ? '후보 미선택'
                              : '$selectedCount개 선택됨',
                          icon: Icons.task_alt_rounded,
                          color: const Color(0xFFEAF9EF),
                          foregroundColor: const Color(0xFF2B7B46),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              RoundedCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: SectionHeading(
                            icon: Icons.subject_rounded,
                            title: 'OCR 결과 텍스트',
                          ),
                        ),
                        IconButton(
                          onPressed: hasRecognizedText ? _copyOcrText : null,
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 20,
                          ),
                          color: const Color(0xFF54657E),
                          tooltip: 'OCR 결과 복사',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ocrTextController,
                      minLines: 6,
                      maxLines: 10,
                      onChanged: (_) => setState(() {
                        _errorText = null;
                      }),
                      decoration: InputDecoration(
                        hintText:
                            'OCR 결과가 여기에 들어옵니다. 필요하면 직접 수정한 뒤 후보를 다시 만들 수 있어요.',
                        filled: true,
                        fillColor: const Color(0xFFF9FBFF),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed:
                                hasRecognizedText && !_isGeneratingCandidates
                                ? _regenerateCandidatesFromText
                                : null,
                            icon: _isGeneratingCandidates
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              _isGeneratingCandidates
                                  ? '후보 만드는 중...'
                                  : '텍스트로 후보 다시 만들기',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE9F1FF),
                              foregroundColor: const Color(0xFF2856A8),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC45B5B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              RoundedCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      icon: Icons.auto_awesome_rounded,
                      title: '예상 생성 결과',
                    ),
                    const SizedBox(height: 16),
                    if (_candidateDrafts.isEmpty)
                      _EmptyCandidateState(
                        onAddManualQuest: _addManualCandidate,
                      )
                    else ...[
                      for (var i = 0; i < _candidateDrafts.length; i++) ...[
                        _CandidateCard(
                          draft: _candidateDrafts[i],
                          onChanged: (selected) =>
                              _toggleCandidate(i, selected),
                          onCategoryChanged: (category) =>
                              _updateCandidateCategory(i, category),
                          onEdit: () => _editCandidate(i),
                        ),
                        if (i != _candidateDrafts.length - 1)
                          const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _addManualCandidate,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('직접 추가'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4D5D77),
                          side: const BorderSide(color: Color(0xFFD6DEEA)),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 18,
                      color: Color(0xFFC77717),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '백엔드 연동 전 단계라서 현재는 OCR 텍스트를 앱 내부 규칙으로 후보화합니다.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF8A5A17),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: selectedCount == 0 ? null : _confirmSelectedQuests,
                icon: const Icon(Icons.task_alt_rounded),
                label: Text('선택한 퀘스트 $selectedCount개 저장'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8B93),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
      _errorText = null;
    });

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2200,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
      _isPicking = false;
      _ocrTextController.clear();
      _candidateDrafts = const [];
    });

    if (image == null) {
      return;
    }

    await _runOcrPipeline();
  }

  Future<void> _runOcrPipeline() async {
    final imagePath = _selectedImage?.path;
    if (imagePath == null || _isRecognizing) {
      return;
    }

    setState(() {
      _isRecognizing = true;
      _errorText = null;
      _candidateDrafts = const [];
    });

    try {
      final recognizedText = await _ocrService.extractText(imagePath);
      if (!mounted) {
        return;
      }

      _ocrTextController.text = recognizedText;
      setState(() => _isRecognizing = false);
      await _regenerateCandidatesFromText();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecognizing = false;
        _errorText = 'OCR 실행에 실패했어요. 이미지를 다시 선택하거나 텍스트를 직접 입력해 주세요.';
      });
    }
  }

  Future<void> _regenerateCandidatesFromText() async {
    final sourceText = _ocrTextController.text.trim();
    if (sourceText.isEmpty) {
      setState(() {
        _candidateDrafts = const [];
        _errorText = 'OCR 결과가 비어 있어 후보를 만들 수 없어요.';
      });
      return;
    }

    setState(() {
      _isGeneratingCandidates = true;
      _errorText = null;
    });

    final candidates = _candidateGenerator.generateFromText(sourceText);

    if (!mounted) {
      return;
    }

    setState(() {
      _candidateDrafts = candidates
          .map((quest) => _QuestCandidateDraft(quest: quest))
          .toList();
      _isGeneratingCandidates = false;
      if (candidates.isEmpty) {
        _errorText = '텍스트는 읽었지만 할 일 형태의 줄을 찾지 못했어요. 텍스트를 다듬거나 후보를 직접 추가해 주세요.';
      }
    });
  }

  Future<void> _addManualCandidate() async {
    final quest = await showDialog<QuestItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => const AddQuestDialog(),
    );

    if (!mounted || quest == null) {
      return;
    }

    setState(() {
      _candidateDrafts = [
        ..._candidateDrafts,
        _QuestCandidateDraft(quest: quest),
      ];
    });
  }

  Future<void> _editCandidate(int index) async {
    final draft = _candidateDrafts[index];
    final updatedQuest = await showDialog<QuestItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => AddQuestDialog(
        initialQuest: draft.quest,
        title: '후보 수정',
        submitLabel: '적용',
      ),
    );

    if (!mounted || updatedQuest == null) {
      return;
    }

    setState(() {
      _candidateDrafts = [
        for (var i = 0; i < _candidateDrafts.length; i++)
          if (i == index)
            _candidateDrafts[i].copyWith(quest: updatedQuest)
          else
            _candidateDrafts[i],
      ];
    });
  }

  void _toggleCandidate(int index, bool selected) {
    setState(() {
      _candidateDrafts = [
        for (var i = 0; i < _candidateDrafts.length; i++)
          if (i == index)
            _candidateDrafts[i].copyWith(isSelected: selected)
          else
            _candidateDrafts[i],
      ];
    });
  }

  void _updateCandidateCategory(int index, String category) {
    setState(() {
      _candidateDrafts = [
        for (var i = 0; i < _candidateDrafts.length; i++)
          if (i == index)
            _candidateDrafts[i].copyWith(
              quest: _candidateDrafts[i].quest.copyWith(category: category),
            )
          else
            _candidateDrafts[i],
      ];
    });
  }

  void _confirmSelectedQuests() {
    final selectedQuests = _candidateDrafts
        .where((item) => item.isSelected)
        .map((item) => item.quest)
        .toList();

    if (selectedQuests.isEmpty) {
      return;
    }

    Navigator.of(context).pop(selectedQuests);
  }

  Future<void> _copyOcrText() async {
    final text = _ocrTextController.text.trim();
    if (text.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('OCR 결과 텍스트를 복사했어요.')));
  }
}

class _ImagePreviewCard extends StatelessWidget {
  const _ImagePreviewCard({
    required this.imagePath,
    required this.isPicking,
    required this.isRecognizing,
    required this.onPickAgain,
    required this.onRunOcr,
  });

  final String? imagePath;
  final bool isPicking;
  final bool isRecognizing;
  final VoidCallback onPickAgain;
  final VoidCallback? onRunOcr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: 220,
              color: const Color(0xFFF0F4FA),
              child: imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 34,
                          color: Color(0xFF91A0B8),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '선택된 이미지가 없습니다',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF708096),
                          ),
                        ),
                      ],
                    )
                  : Image.file(File(imagePath!), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isPicking ? null : onPickAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8B93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isPicking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.image_search_rounded),
                  label: Text(isPicking ? '이미지 불러오는 중...' : '다시 선택'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: isRecognizing ? null : onRunOcr,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE9F1FF),
                    foregroundColor: const Color(0xFF2856A8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: isRecognizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(isRecognizing ? 'OCR 실행 중...' : 'OCR 재실행'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.draft,
    required this.onChanged,
    required this.onCategoryChanged,
    required this.onEdit,
  });

  final _QuestCandidateDraft draft;
  final ValueChanged<bool> onChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final quest = draft.quest;
    final isExpanded = draft.isSelected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        isExpanded ? 16 : 12,
        16,
        isExpanded ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: isExpanded ? const Color(0xFFF9FBFF) : const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? const Color(0xFFFFD5D9) : const Color(0xFFE2E8F1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: isExpanded
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: draft.isSelected,
                activeColor: const Color(0xFFFF8B93),
                onChanged: (value) => onChanged(value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: isExpanded ? 4 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          quest.title,
                          maxLines: isExpanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF243248),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1,
                              child: child,
                            ),
                          );
                        },
                        child: isExpanded
                            ? Padding(
                                key: const ValueKey('candidate-expanded'),
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _MetaChip(
                                          label: _difficultyDurationLabel(
                                            difficulty: quest.difficulty,
                                            durationSeconds:
                                                quest.defaultDurationSeconds,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        for (final category
                                            in questCategories) ...[
                                          Expanded(
                                            child: Center(
                                              child: _CategoryChoiceChip(
                                                category: category,
                                                selected:
                                                    quest.category == category,
                                                onTap: () =>
                                                    onCategoryChanged(category),
                                              ),
                                            ),
                                          ),
                                          if (category != questCategories.last)
                                            const SizedBox(width: 6),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('candidate-collapsed'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      axisAlignment: 1,
                      child: child,
                    ),
                  );
                },
                child: isExpanded
                    ? IconButton(
                        key: const ValueKey('candidate-edit-visible'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        color: const Color(0xFF7A8AA3),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('candidate-edit-hidden'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _difficultyDurationLabel({
  required String difficulty,
  required int durationSeconds,
}) {
  final difficultyLabel = switch (difficulty) {
    '보통' => '중간',
    _ => difficulty,
  };
  return '$difficultyLabel:${durationSeconds ~/ 60}분';
}

class _CategoryChoiceChip extends StatelessWidget {
  const _CategoryChoiceChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryStyle = questCategoryStyleFor(category);
    final style = (icon: categoryStyle.icon, color: categoryStyle.accentColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? style.color.withValues(alpha: 0.14) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? style.color : const Color(0xFFD8E0EC),
            width: selected ? 1.6 : 1.1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: style.color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(style.icon, size: 16, color: style.color),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _EmptyCandidateState extends StatelessWidget {
  const _EmptyCandidateState({required this.onAddManualQuest});

  final VoidCallback onAddManualQuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_motion_rounded,
            size: 30,
            color: Color(0xFF91A0B8),
          ),
          const SizedBox(height: 10),
          const Text(
            '아직 생성된 후보가 없습니다',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF304056),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이미지를 고르거나 OCR 텍스트를 수정한 뒤 다시 후보를 만들어 보세요. 필요하면 직접 퀘스트를 추가할 수도 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF708096),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAddManualQuest,
            icon: const Icon(Icons.add_rounded),
            label: const Text('직접 추가'),
          ),
        ],
      ),
    );
  }
}

class _QuestCandidateDraft {
  const _QuestCandidateDraft({required this.quest, this.isSelected = true});

  final QuestItem quest;
  final bool isSelected;

  _QuestCandidateDraft copyWith({QuestItem? quest, bool? isSelected}) {
    return _QuestCandidateDraft(
      quest: quest ?? this.quest,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
