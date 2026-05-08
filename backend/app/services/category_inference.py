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
