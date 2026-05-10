import re
from collections.abc import Iterable

from app.schemas.quest import QuestDifficulty
from app.schemas.quest_generation import (
    OCRTextQuestExtractionResponse,
    QuestCandidateResponse,
)
from app.services.category_inference import infer_category_from_title
from app.services.difficulty_rules import (
    duration_from_difficulty,
    exp_from_difficulty,
)

MIN_LINE_LENGTH = 2
MAX_LINE_LENGTH = 80
MAX_CANDIDATES = 8

EASY_KEYWORDS: tuple[str, ...] = (
    "check",
    "email",
    "buy",
    "organize",
    "clean",
    "review",
    "plan",
    "call",
    "확인",
    "정리",
    "체크",
    "구매",
    "장보기",
    "준비",
    "예약",
    "메일",
    "답장",
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
    "발표",
    "기획",
    "분석",
    "설계",
    "리포트",
    "보고서",
    "프로젝트",
    "정리본",
    "강의",
    "학습",
)


class QuestTextExtractionService:
    def extract(self, raw_text: str) -> OCRTextQuestExtractionResponse:
        normalized_lines = split_and_normalize_lines(raw_text)
        cleaned_lines, duplicate_removed_count = filter_and_deduplicate_lines(
            normalized_lines,
        )
        quests = build_quest_candidates(cleaned_lines[:MAX_CANDIDATES])
        return OCRTextQuestExtractionResponse(
            quests=quests,
            cleaned_lines=cleaned_lines,
            duplicate_removed_count=duplicate_removed_count,
        )


def split_and_normalize_lines(raw_text: str) -> list[str]:
    return [_normalize_line(line) for line in raw_text.splitlines()]


def filter_and_deduplicate_lines(
    lines: Iterable[str],
) -> tuple[list[str], int]:
    seen: set[str] = set()
    cleaned_lines: list[str] = []
    duplicate_removed_count = 0

    for line in lines:
        if not is_meaningful_candidate_line(line):
            continue

        dedupe_key = line.lower()
        if dedupe_key in seen:
            duplicate_removed_count += 1
            continue

        seen.add(dedupe_key)
        cleaned_lines.append(line)

    return cleaned_lines, duplicate_removed_count


def build_quest_candidates(lines: Iterable[str]) -> list[QuestCandidateResponse]:
    return [build_quest_candidate(line) for line in lines]


def build_quest_candidate(title: str) -> QuestCandidateResponse:
    difficulty = infer_difficulty_from_title(title)
    category = infer_category_from_title(title)
    return QuestCandidateResponse(
        title=title,
        difficulty=difficulty,
        category=category,
        exp=exp_from_difficulty(difficulty),
        defaultDurationSeconds=duration_from_difficulty(difficulty),
        reason="Generated from cleaned OCR text.",
    )


def infer_difficulty_from_title(title: str) -> QuestDifficulty:
    normalized_title = title.strip().lower()
    if not normalized_title:
        return QuestDifficulty.NORMAL

    if contains_any_keyword(normalized_title, HARD_KEYWORDS) or len(normalized_title) >= 28:
        return QuestDifficulty.HARD
    if contains_any_keyword(normalized_title, EASY_KEYWORDS) or len(normalized_title) <= 10:
        return QuestDifficulty.EASY
    return QuestDifficulty.NORMAL


def is_meaningful_candidate_line(line: str) -> bool:
    if not line:
        return False
    if len(line) < MIN_LINE_LENGTH or len(line) > MAX_LINE_LENGTH:
        return False
    if re.fullmatch(r"[0-9\s:/.-]+", line):
        return False
    if re.fullmatch(r"[ㄱ-ㅎㅏ-ㅣa-zA-Z0-9 ]{1,2}", line):
        return False
    return True


def contains_any_keyword(value: str, keywords: Iterable[str]) -> bool:
    return any(keyword in value for keyword in keywords)


def _normalize_line(value: str) -> str:
    normalized = re.sub(
        r"^\s*(?:[-*•·▪▫]|\d+[.)]|☐|☑|✓|✔|\[[ xX]?\])\s*",
        "",
        value,
    )
    normalized = re.sub(r"\s+", " ", normalized)
    normalized = re.sub(r"[.,;:]+$", "", normalized)
    return normalized.strip()
