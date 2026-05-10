from app.schemas.quest import QuestCategory, QuestDifficulty
from app.schemas.quest_generation import QuestCandidateResponse
from app.services.category_inference import infer_category_from_title
from app.services.difficulty_rules import (
    duration_from_difficulty,
    exp_from_difficulty,
)


def parse_notion_pages_to_quests(pages: list[dict]) -> list[QuestCandidateResponse]:
    quests: list[QuestCandidateResponse] = []
    for page in pages:
        if is_completed_page(page):
            continue
        candidate = parse_notion_page_to_quest(page)
        if candidate is not None:
            quests.append(candidate)
    return quests


def parse_notion_page_to_quest(page: dict) -> QuestCandidateResponse | None:
    properties = get_page_properties(page)
    title = read_title(properties)
    if not title:
        return None

    duration_minutes = read_duration_minutes(properties)
    difficulty = read_difficulty(properties, duration_minutes=duration_minutes)
    category = read_category(properties, title=title)
    exp = read_exp(properties, difficulty=difficulty)

    return QuestCandidateResponse(
        title=title,
        difficulty=difficulty,
        category=category,
        exp=exp,
        defaultDurationSeconds=duration_minutes * 60
        if duration_minutes > 0
        else duration_from_difficulty(difficulty),
        reason="Generated from Notion sync.",
    )


def is_completed_page(page: dict) -> bool:
    if page.get("archived") is True or page.get("in_trash") is True:
        return True

    for name, raw_property in get_page_properties(page).items():
        if not isinstance(raw_property, dict):
            continue
        normalized_name = normalize_key(name)
        if not is_completion_property(normalized_name):
            continue

        property_type = raw_property.get("type", "")
        if property_type == "checkbox" and raw_property.get("checkbox") is True:
            return True

        label = read_select_like_name(raw_property).lower()
        if any(
            word in label
            for word in (
                "done",
                "complete",
                "completed",
                "finished",
                "closed",
                "완료",
            )
        ):
            return True

    return False


def get_page_properties(page: dict) -> dict:
    properties = page.get("properties", {})
    return properties if isinstance(properties, dict) else {}


def read_title(properties: dict) -> str:
    for raw_property in properties.values():
        if not isinstance(raw_property, dict):
            continue
        if raw_property.get("type") != "title":
            continue
        title_items = raw_property.get("title", [])
        return "".join(
            item.get("plain_text", "")
            for item in title_items
            if isinstance(item, dict)
        ).strip()
    return ""


def read_duration_minutes(properties: dict) -> int:
    property_value = find_property(
        properties,
        ("duration", "minutes", "time", "estimate", "소요시간", "예상시간"),
    )
    if property_value is None:
        return 0

    property_type = property_value.get("type", "")
    if property_type == "number":
        number = property_value.get("number")
        return int(round(number)) if isinstance(number, (int, float)) else 0

    raw_text = read_plain_text(property_value)
    return parse_duration_minutes(raw_text)


def read_difficulty(
    properties: dict,
    *,
    duration_minutes: int,
) -> QuestDifficulty:
    property_value = find_property(
        properties,
        ("difficulty", "level", "priority", "난이도", "우선순위"),
    )
    raw_value = read_plain_text(property_value).lower() if property_value else ""

    if any(word in raw_value for word in ("easy", "low", "쉬움")):
        return QuestDifficulty.EASY
    if any(word in raw_value for word in ("hard", "high", "어려움")):
        return QuestDifficulty.HARD
    if any(word in raw_value for word in ("medium", "mid", "normal", "보통")):
        return QuestDifficulty.NORMAL

    if duration_minutes <= 0:
        return QuestDifficulty.NORMAL
    if duration_minutes <= 30:
        return QuestDifficulty.EASY
    if duration_minutes <= 60:
        return QuestDifficulty.NORMAL
    return QuestDifficulty.HARD


def read_category(properties: dict, *, title: str) -> QuestCategory:
    property_value = find_property(
        properties,
        ("category", "type", "tag", "area", "분류", "카테고리", "영역"),
    )
    raw_value = read_plain_text(property_value) if property_value else ""
    mapped = map_category(raw_value)
    if mapped is not None:
        return mapped
    return infer_category_from_title(title)


def read_exp(properties: dict, *, difficulty: QuestDifficulty) -> int:
    property_value = find_property(properties, ("exp", "xp"))
    if property_value is not None and property_value.get("type") == "number":
        number = property_value.get("number")
        if isinstance(number, (int, float)) and int(round(number)) > 0:
            return int(round(number))
    return exp_from_difficulty(difficulty)


def find_property(properties: dict, candidate_names: tuple[str, ...]) -> dict | None:
    normalized_candidates = {normalize_key(name) for name in candidate_names}
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict):
            continue
        if normalize_key(name) in normalized_candidates:
            return raw_property
    return None


def read_plain_text(property_value: dict | None) -> str:
    if property_value is None:
        return ""
    property_type = property_value.get("type", "")
    if property_type in {"select", "status"}:
        return read_select_like_name(property_value)
    if property_type == "multi_select":
        values = property_value.get("multi_select", [])
        return " ".join(
            item.get("name", "")
            for item in values
            if isinstance(item, dict) and item.get("name")
        ).strip()
    if property_type == "rich_text":
        values = property_value.get("rich_text", [])
        return "".join(
            item.get("plain_text", "")
            for item in values
            if isinstance(item, dict)
        ).strip()
    if property_type == "number":
        value = property_value.get("number")
        return "" if value is None else str(value)
    if property_type == "checkbox":
        return "true" if property_value.get("checkbox") is True else "false"
    return ""


def read_select_like_name(property_value: dict) -> str:
    property_type = property_value.get("type", "")
    nested = property_value.get(property_type, {})
    return nested.get("name", "") if isinstance(nested, dict) else ""


def parse_duration_minutes(raw_text: str) -> int:
    normalized = raw_text.lower().replace(" ", "")
    hours_match = __import__("re").search(r"(\d+)h", normalized)
    minutes_match = __import__("re").search(r"(\d+)m", normalized)
    if hours_match or minutes_match:
        hours = int(hours_match.group(1)) if hours_match else 0
        minutes = int(minutes_match.group(1)) if minutes_match else 0
        return hours * 60 + minutes

    if "시간" in normalized:
        hours_text = __import__("re").search(r"\d+", normalized)
        return int(hours_text.group(0)) * 60 if hours_text is not None else 0

    if "분" in normalized:
        minutes_text = __import__("re").search(r"\d+", normalized)
        return int(minutes_text.group(0)) if minutes_text is not None else 0

    first_number_match = __import__("re").search(r"\d+", normalized)
    if first_number_match is None:
        return 0
    return int(first_number_match.group(0))


def map_category(value: str) -> QuestCategory | None:
    normalized = value.strip().lower()
    if not normalized:
        return None
    if any(word in normalized for word in ("work", "job", "project", "office")):
        return QuestCategory.WORK
    if any(word in normalized for word in ("study", "learn", "research", "course")):
        return QuestCategory.STUDY
    if any(word in normalized for word in ("life", "health", "exercise", "habit")):
        return QuestCategory.LIFE
    if any(word in normalized for word in ("home", "todo", "house", "clean")):
        return QuestCategory.HOME
    if any(word in normalized for word in ("업무", "회사")):
        return QuestCategory.WORK
    if any(word in normalized for word in ("공부", "학습")):
        return QuestCategory.STUDY
    if any(word in normalized for word in ("운동", "건강")):
        return QuestCategory.LIFE
    if any(word in normalized for word in ("집", "정리")):
        return QuestCategory.HOME
    return None


def is_completion_property(normalized_name: str) -> bool:
    return any(
        token in normalized_name
        for token in (
            "status",
            "done",
            "complete",
            "state",
            "finished",
            "closed",
            "상태",
            "완료",
        )
    )


def normalize_key(value: str) -> str:
    return "".join(character for character in value.lower() if character not in " _-")
