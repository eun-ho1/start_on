import re
from collections.abc import Sequence

from app.providers.base import QuestGenerationProvider
from app.schemas.quest import QuestCategory, QuestDifficulty
from app.schemas.quest_generation import (
    OCRTextQuestExtractionRequest,
    OCRTextQuestExtractionResponse,
    QuestCandidateResponse,
    QuestGenerationRequest,
    QuestGenerationResponse,
)
from app.services.category_inference import resolve_category
from app.services.difficulty_rules import (
    duration_from_difficulty,
    exp_from_difficulty,
)

DEFAULT_MAX_ITEMS = 5
MAX_CANDIDATES_FROM_TEXT = 8

EASY_KEYWORDS: tuple[str, ...] = (
    "check",
    "email",
    "buy",
    "organize",
    "clean",
    "review",
    "plan",
    "call",
)

HARD_KEYWORDS: tuple[str, ...] = (
    "analyze",
    "design",
    "build",
    "implement",
    "research",
    "presentation",
    "write",
    "study",
)


class RuleBasedQuestGenerationProvider(QuestGenerationProvider):
    def generate(self, request: QuestGenerationRequest) -> QuestGenerationResponse:
        titles = self._build_candidate_titles(request)
        max_items = request.max_items or DEFAULT_MAX_ITEMS
        quests = [
            self._build_candidate_response(
                title=title,
                explicit_difficulty=request.difficulty,
                explicit_category=request.category,
                reason=self._build_reason(
                    title=title,
                    explicit_difficulty=request.difficulty,
                    explicit_category=request.category,
                ),
            )
            for title in titles[:max_items]
        ]
        return QuestGenerationResponse(quests=quests)

    def extract_from_text(
        self,
        request: OCRTextQuestExtractionRequest,
    ) -> OCRTextQuestExtractionResponse:
        cleaned_lines, duplicate_removed_count = _extract_candidate_lines(
            request.raw_text,
        )
        quests = [
            self._build_candidate_response(
                title=line,
                explicit_difficulty=None,
                explicit_category=None,
                reason="Generated from cleaned OCR text.",
            )
            for line in cleaned_lines[:MAX_CANDIDATES_FROM_TEXT]
        ]
        return OCRTextQuestExtractionResponse(
            quests=quests,
            cleaned_lines=cleaned_lines,
            duplicate_removed_count=duplicate_removed_count,
        )

    def _build_candidate_titles(
        self,
        request: QuestGenerationRequest,
    ) -> list[str]:
        titles: list[str] = []

        if request.prompt and request.prompt.strip():
            prompt_title = _normalize_candidate_title(request.prompt)
            if prompt_title:
                titles.append(prompt_title)

        if request.source_text and request.source_text.strip():
            extracted_titles, _ = _extract_candidate_lines(request.source_text)
            titles.extend(extracted_titles)

        return _deduplicate_titles(titles)

    def _build_candidate_response(
        self,
        *,
        title: str,
        explicit_difficulty: QuestDifficulty | None,
        explicit_category: QuestCategory | None,
        reason: str | None,
    ) -> QuestCandidateResponse:
        difficulty = explicit_difficulty or infer_difficulty_from_title(title)
        category = resolve_category(explicit_category, title)
        return QuestCandidateResponse(
            title=title,
            difficulty=difficulty,
            category=category,
            exp=exp_from_difficulty(difficulty),
            defaultDurationSeconds=duration_from_difficulty(difficulty),
            reason=reason,
        )

    def _build_reason(
        self,
        *,
        title: str,
        explicit_difficulty: QuestDifficulty | None,
        explicit_category: QuestCategory | None,
    ) -> str:
        reason_parts: list[str] = []
        if explicit_difficulty is not None:
            reason_parts.append("Applied explicit difficulty.")
        else:
            reason_parts.append(
                f"Inferred difficulty from title '{title}'.",
            )

        if explicit_category is not None:
            reason_parts.append("Applied explicit category.")
        else:
            reason_parts.append(
                f"Inferred category from title '{title}'.",
            )
        return " ".join(reason_parts)


def infer_difficulty_from_title(title: str) -> QuestDifficulty:
    normalized_title = title.strip().lower()
    if not normalized_title:
        return QuestDifficulty.NORMAL

    if _contains_any_keyword(normalized_title, HARD_KEYWORDS) or len(normalized_title) >= 28:
        return QuestDifficulty.HARD
    if _contains_any_keyword(normalized_title, EASY_KEYWORDS) or len(normalized_title) <= 10:
        return QuestDifficulty.EASY
    return QuestDifficulty.NORMAL


def _extract_candidate_lines(raw_text: str) -> tuple[list[str], int]:
    seen: set[str] = set()
    cleaned_lines: list[str] = []
    duplicate_removed_count = 0

    for raw_line in raw_text.splitlines():
        line = _normalize_candidate_title(raw_line)
        if not _is_candidate_line(line):
            continue

        dedupe_key = line.lower()
        if dedupe_key in seen:
            duplicate_removed_count += 1
            continue

        seen.add(dedupe_key)
        cleaned_lines.append(line)

    return cleaned_lines, duplicate_removed_count


def _normalize_candidate_title(value: str) -> str:
    normalized = re.sub(r"^\s*(?:[-*•]|\d+[.)])\s*", "", value)
    normalized = re.sub(r"\s+", " ", normalized)
    normalized = re.sub(r"[.,;:]+$", "", normalized)
    return normalized.strip()


def _is_candidate_line(line: str) -> bool:
    if len(line) < 2 or len(line) > 80:
        return False
    if re.fullmatch(r"[0-9\s:/.-]+", line):
        return False
    return True


def _deduplicate_titles(titles: Sequence[str]) -> list[str]:
    seen: set[str] = set()
    unique_titles: list[str] = []
    for title in titles:
        normalized = title.strip()
        if not normalized:
            continue

        dedupe_key = normalized.lower()
        if dedupe_key in seen:
            continue

        seen.add(dedupe_key)
        unique_titles.append(normalized)
    return unique_titles


def _contains_any_keyword(value: str, keywords: Sequence[str]) -> bool:
    return any(keyword in value for keyword in keywords)


def _normalize_candidate_title(value: str) -> str:
    normalized = re.sub(r"^\s*(?:[-*]|\d+[.)])\s*", "", value)
    normalized = re.sub(r"\s+", " ", normalized)
    normalized = re.sub(r"[.,;:]+$", "", normalized)
    return normalized.strip()
