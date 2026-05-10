from collections.abc import Mapping, Sequence

from app.schemas.quest import QuestCategory

DEFAULT_CATEGORY = QuestCategory.WORK

CATEGORY_KEYWORDS: Mapping[QuestCategory, tuple[str, ...]] = {
    QuestCategory.WORK: (
        "work",
        "job",
        "project",
        "meeting",
        "email",
        "document",
        "report",
        "presentation",
        "task",
        "office",
        "업무",
        "회사",
        "회의",
        "문서",
        "보고서",
        "기획",
        "검토",
        "이메일",
        "메일",
        "자료",
    ),
    QuestCategory.LIFE: (
        "life",
        "health",
        "exercise",
        "workout",
        "walk",
        "run",
        "habit",
        "sleep",
        "meal",
        "meditation",
        "운동",
        "스트레칭",
        "러닝",
        "헬스",
        "산책",
        "요가",
        "조깅",
        "필라테스",
    ),
    QuestCategory.STUDY: (
        "study",
        "learn",
        "learning",
        "read",
        "research",
        "lecture",
        "course",
        "practice",
        "review",
        "analysis",
        "공부",
        "학습",
        "독서",
        "강의",
        "리서치",
        "분석",
        "설계",
        "연습",
        "정리본",
    ),
    QuestCategory.HOME: (
        "home",
        "clean",
        "laundry",
        "kitchen",
        "organize",
        "shopping",
        "buy",
        "groceries",
        "todo",
        "house",
        "청소",
        "세탁",
        "장보기",
        "구매",
        "준비",
        "정리",
        "예약",
        "확인",
        "체크",
        "챙기기",
    ),
}


def infer_category_from_title(title: str) -> QuestCategory:
    normalized_title = title.strip().lower()
    if not normalized_title:
        return DEFAULT_CATEGORY

    scores = {
        category: _count_keyword_matches(normalized_title, keywords)
        for category, keywords in CATEGORY_KEYWORDS.items()
    }
    best_category, best_score = max(scores.items(), key=lambda item: item[1])
    if best_score == 0:
        return DEFAULT_CATEGORY
    return best_category


def resolve_category(
    explicit_category: QuestCategory | None,
    title: str,
) -> QuestCategory:
    if explicit_category is not None:
        return explicit_category
    return infer_category_from_title(title)


def _count_keyword_matches(title: str, keywords: Sequence[str]) -> int:
    return sum(1 for keyword in keywords if keyword in title)
