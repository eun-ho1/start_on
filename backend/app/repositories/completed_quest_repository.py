from datetime import datetime
from typing import Any

from app.repositories.base import CompletedQuestRepository, QuestRecord
from app.schemas.quest import CompletedQuestRecordSchema


class SupabaseCompletedQuestRepository(CompletedQuestRepository):
    def __init__(self, client: Any) -> None:
        self._client = client

    def create_completed_quest(
        self,
        user_id: str,
        quest: QuestRecord,
        earned_exp: int,
        completed_at: datetime,
        elapsed_seconds: int,
        proof_image_path: str | None = None,
    ) -> tuple[str, CompletedQuestRecordSchema]:
        payload = {
            "user_id": user_id,
            "profile_id": quest.profile_id,
            "quest_id": quest.id,
            "client_quest_id": quest.id,
            "title": quest.title,
            "difficulty": quest.difficulty,
            "category": quest.category,
            "earned_exp": earned_exp,
            "completed_at": completed_at.isoformat(),
            "elapsed_seconds": elapsed_seconds,
            "proof_image_path": proof_image_path,
            "completion_source": "timer" if elapsed_seconds > 0 else "manual",
        }
        completed_response = (
            self._client.table("completed_quests").insert(payload).execute()
        )
        created_row = _single_row(completed_response)
        return created_row["id"], _map_completed_row(created_row)

    def create_recent_activity(
        self,
        user_id: str,
        profile_id: str,
        completed_quest_id: str,
        activity_date: datetime,
        subtitle: str,
        exp: int,
    ) -> None:
        payload = {
            "user_id": user_id,
            "profile_id": profile_id,
            "completed_quest_id": completed_quest_id,
            "activity_date": activity_date.date().isoformat(),
            "subtitle": subtitle,
            "exp": exp,
            "activity_type": "quest_completed",
        }
        self._client.table("recent_activities").insert(payload).execute()


def _single_row(response: Any) -> dict[str, Any]:
    rows = response.data or []
    if not rows:
        raise ValueError("Requested resource was not found for the given user_id.")
    return rows[0]


def _map_completed_row(row: dict[str, Any]) -> CompletedQuestRecordSchema:
    return CompletedQuestRecordSchema(
        questId=row["quest_id"] or "",
        title=row["title"],
        difficulty=row["difficulty"],
        category=row["category"],
        earnedExp=row["earned_exp"],
        completedAt=row["completed_at"],
        elapsedSeconds=row["elapsed_seconds"],
        proofImagePath=row.get("proof_image_path"),
    )
