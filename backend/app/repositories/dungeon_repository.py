from datetime import datetime
from typing import Any

from app.repositories.base import DungeonRepository
from app.schemas.dungeon import (
    DungeonClearResponse,
    DungeonStatusResponse,
)

_DUNGEON_REWARDS = {
    "dungeon_meditation": 8,
    "dungeon_evening_workout": 12,
}


class SupabaseDungeonRepository(DungeonRepository):
    def __init__(self, client: Any) -> None:
        self._client = client

    def list_dungeons(self, user_id: str) -> list[DungeonStatusResponse]:
        response = (
            self._client.table("dungeon_clears")
            .select("dungeon_id, cleared_at")
            .eq("user_id", user_id)
            .execute()
        )
        rows = response.data or []
        cleared_by_id = {row["dungeon_id"]: row for row in rows}
        return [
            DungeonStatusResponse(
                dungeonId=dungeon_id,
                cleared=dungeon_id in cleared_by_id,
                creditReward=reward,
                clearedAt=cleared_by_id.get(dungeon_id, {}).get("cleared_at"),
            )
            for dungeon_id, reward in _DUNGEON_REWARDS.items()
        ]

    def clear_dungeon(
        self,
        user_id: str,
        dungeon_id: str,
        credit_reward: int,
    ) -> DungeonClearResponse:
        existing = (
            self._client.table("dungeon_clears")
            .select("id, cleared_at")
            .eq("user_id", user_id)
            .eq("dungeon_id", dungeon_id)
            .limit(1)
            .execute()
        )
        rows = existing.data or []
        if rows:
            profile = (
                self._client.table("users_profile")
                .select("credits")
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
            profile_row = (profile.data or [{}])[0]
            return DungeonClearResponse(
                dungeonId=dungeon_id,
                cleared=True,
                credits=profile_row.get("credits", 0),
                clearedAt=rows[0]["cleared_at"],
            )

        profile_response = (
            self._client.table("users_profile")
            .select("id, credits")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        profile_rows = profile_response.data or []
        if not profile_rows:
            raise ValueError("Profile was not found for the given user_id.")
        profile_row = profile_rows[0]
        cleared_at = datetime.utcnow().isoformat()
        self._client.table("dungeon_clears").insert(
            {
                "user_id": user_id,
                "profile_id": profile_row["id"],
                "dungeon_id": dungeon_id,
                "cleared_at": cleared_at,
            },
        ).execute()
        next_credits = profile_row["credits"] + credit_reward
        (
            self._client.table("users_profile")
            .update({"credits": next_credits})
            .eq("user_id", user_id)
            .execute()
        )
        return DungeonClearResponse(
            dungeonId=dungeon_id,
            cleared=True,
            credits=next_credits,
            clearedAt=cleared_at,
        )
