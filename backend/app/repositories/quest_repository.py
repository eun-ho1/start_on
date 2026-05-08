from typing import Any

from app.repositories.base import QuestRecord, QuestRepository
from app.schemas.quest_generation import QuestCandidateResponse
from app.schemas.quest import QuestItemResponse


class SupabaseQuestRepository(QuestRepository):
    def __init__(self, client: Any) -> None:
        self._client = client

    def list_quests(self, user_id: str) -> list[QuestItemResponse]:
        response = (
            self._client.table("quests")
            .select(
                "id, title, exp, difficulty, category, elapsed_seconds, "
                "default_duration_seconds",
            )
            .eq("user_id", user_id)
            .eq("status", "active")
            .order("created_at", desc=True)
            .execute()
        )
        return [_map_quest_row(row) for row in response.data or []]

    def create_quest(
        self,
        user_id: str,
        quest: QuestItemResponse,
    ) -> QuestItemResponse:
        profile_id = _get_profile_id(self._client, user_id)
        payload = {
            "user_id": user_id,
            "profile_id": profile_id,
            "client_quest_id": quest.id,
            "title": quest.title,
            "exp": quest.exp,
            "difficulty": quest.difficulty.value,
            "category": quest.category.value,
            "elapsed_seconds": quest.elapsedSeconds,
            "default_duration_seconds": quest.defaultDurationSeconds,
            "status": "active",
            "source": "manual",
        }
        response = self._client.table("quests").insert(payload).execute()
        created = _single_row(response)
        return _map_quest_row(created)

    def update_quest(
        self,
        user_id: str,
        quest_id: str,
        quest: QuestItemResponse,
    ) -> QuestItemResponse:
        payload = {
            "title": quest.title,
            "exp": quest.exp,
            "difficulty": quest.difficulty.value,
            "category": quest.category.value,
            "elapsed_seconds": quest.elapsedSeconds,
            "default_duration_seconds": quest.defaultDurationSeconds,
        }
        existing = self.get_active_quest(user_id, quest_id)
        response = (
            self._client.table("quests")
            .update(payload)
            .eq("user_id", user_id)
            .eq("id", quest_id)
            .eq("status", "active")
            .execute()
        )
        _ensure_mutation_succeeded(response, "Quest update did not affect any rows.")
        refreshed = self.get_active_quest(user_id, quest_id)
        return QuestItemResponse(
            id=refreshed.id,
            title=refreshed.title,
            exp=refreshed.exp,
            difficulty=refreshed.difficulty,
            category=refreshed.category,
            elapsedSeconds=refreshed.elapsed_seconds,
            defaultDurationSeconds=refreshed.default_duration_seconds,
        )

    def delete_quest(self, user_id: str, quest_id: str) -> None:
        _get_quest_for_delete(self._client, user_id, quest_id)
        response = (
            self._client.table("quests")
            .delete()
            .eq("user_id", user_id)
            .eq("id", quest_id)
            .execute()
        )
        _ensure_mutation_succeeded(response, "Quest delete did not affect any rows.")

    def get_active_quest(self, user_id: str, quest_id: str) -> QuestRecord:
        response = (
            self._client.table("quests")
            .select(
                "id, profile_id, title, exp, difficulty, category, "
                "elapsed_seconds, default_duration_seconds",
            )
            .eq("user_id", user_id)
            .eq("id", quest_id)
            .eq("status", "active")
            .limit(1)
            .execute()
        )
        return _map_quest_record(_single_row(response))

    def mark_completed(self, user_id: str, quest_id: str) -> None:
        self.get_active_quest(user_id, quest_id)
        response = (
            self._client.table("quests")
            .update({"status": "completed"})
            .eq("user_id", user_id)
            .eq("id", quest_id)
            .eq("status", "active")
            .execute()
        )
        _ensure_mutation_succeeded(response, "Quest completion update did not affect any rows.")

    def upsert_notion_quests(
        self,
        *,
        user_id: str,
        profile_id: str,
        source_reference: str,
        quests: list[QuestCandidateResponse],
        pages: list[dict[str, Any]],
    ) -> None:
        page_by_title = {
            _page_title(page).strip().lower(): page
            for page in pages
            if _page_title(page).strip()
        }
        for quest in quests:
            page = page_by_title.get(quest.title.strip().lower())
            page_id = page.get("id") if page else None
            payload = {
                "user_id": user_id,
                "profile_id": profile_id,
                "client_quest_id": f"notion:{page_id}" if page_id else None,
                "title": quest.title,
                "exp": quest.exp,
                "difficulty": quest.difficulty.value,
                "category": quest.category.value,
                "elapsed_seconds": 0,
                "default_duration_seconds": quest.defaultDurationSeconds,
                "status": "active",
                "source": "notion",
                "source_reference": source_reference,
            }
            query = (
                self._client.table("quests")
                .select("id")
                .eq("user_id", user_id)
                .eq("source", "notion")
                .eq("title", quest.title)
                .limit(1)
                .execute()
            )
            rows = query.data or []
            if rows:
                (
                    self._client.table("quests")
                    .update(payload)
                    .eq("id", rows[0]["id"])
                    .execute()
                )
            else:
                self._client.table("quests").insert(payload).execute()


def _get_profile_id(client: Any, user_id: str) -> str:
    response = (
        client.table("users_profile")
        .select("id")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    rows = response.data or []
    if not rows:
        raise ValueError("Profile was not found for the given user_id.")
    row = rows[0]
    return row["id"]


def _single_row(response: Any) -> dict[str, Any]:
    rows = response.data or []
    if not rows:
        raise ValueError("Quest was not found for the given user_id.")
    return rows[0]


def _get_quest_for_delete(client: Any, user_id: str, quest_id: str) -> dict[str, Any]:
    response = (
        client.table("quests")
        .select("id")
        .eq("user_id", user_id)
        .eq("id", quest_id)
        .limit(1)
        .execute()
    )
    return _single_row(response)


def _ensure_mutation_succeeded(response: Any, message: str) -> None:
    if getattr(response, "data", None) is None:
        return
    if isinstance(response.data, list) and response.data == []:
        raise ValueError(message)


def _map_quest_row(row: dict[str, Any]) -> QuestItemResponse:
    return QuestItemResponse(
        id=row["id"],
        title=row["title"],
        exp=row["exp"],
        difficulty=row["difficulty"],
        category=row["category"],
        elapsedSeconds=row["elapsed_seconds"],
        defaultDurationSeconds=row["default_duration_seconds"],
    )


def _map_quest_record(row: dict[str, Any]) -> QuestRecord:
    return QuestRecord(
        id=row["id"],
        profile_id=row["profile_id"],
        title=row["title"],
        exp=row["exp"],
        difficulty=row["difficulty"],
        category=row["category"],
        elapsed_seconds=row["elapsed_seconds"],
        default_duration_seconds=row["default_duration_seconds"],
    )


def _page_title(page: dict[str, Any]) -> str:
    properties = page.get("properties", {})
    if not isinstance(properties, dict):
        return ""
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
