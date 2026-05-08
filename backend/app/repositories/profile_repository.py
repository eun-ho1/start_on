from typing import Any

from app.repositories.base import ProfileRepository, ProfileState
from app.schemas.profile import ProfileResponse


class SupabaseProfileRepository(ProfileRepository):
    def __init__(self, client: Any) -> None:
        self._client = client

    def get_profile_summary(self, user_id: str) -> ProfileResponse:
        row = self._fetch_profile_with_stats(user_id)
        raw_stats = row.get("user_stats")
        if isinstance(raw_stats, list):
            stats = raw_stats[0] if raw_stats else {}
        elif isinstance(raw_stats, dict):
            stats = raw_stats
        else:
            stats = {}
        return ProfileResponse(
            userName=row["user_name"],
            userRole=row["user_role"],
            level=row["level"],
            currentExp=row["current_exp"],
            maxExp=row["max_exp"],
            credits=row["credits"],
            completedQuestCount=stats.get("completed_quest_count", 0),
            earnedExp=stats.get("earned_exp", 0),
        )

    def get_profile_state(self, user_id: str) -> ProfileState:
        response = (
            self._client.table("users_profile")
            .select(
                "id, user_name, user_role, level, current_exp, max_exp, credits, "
                "daily_reset_key, weekly_reset_key, monthly_reset_key",
            )
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        row = _single_row(response)
        return ProfileState(
            profile_id=row["id"],
            user_name=row["user_name"],
            user_role=row["user_role"],
            level=row["level"],
            current_exp=row["current_exp"],
            max_exp=row["max_exp"],
            credits=row["credits"],
            daily_reset_key=row["daily_reset_key"],
            weekly_reset_key=row["weekly_reset_key"],
            monthly_reset_key=row["monthly_reset_key"],
        )

    def update_profile_progress(
        self,
        user_id: str,
        *,
        level: int,
        current_exp: int,
        max_exp: int,
        user_role: str,
        credits: int,
        daily_reset_key: str,
        weekly_reset_key: str,
        monthly_reset_key: str,
    ) -> None:
        payload = {
            "level": level,
            "current_exp": current_exp,
            "max_exp": max_exp,
            "user_role": user_role,
            "credits": credits,
            "daily_reset_key": daily_reset_key,
            "weekly_reset_key": weekly_reset_key,
            "monthly_reset_key": monthly_reset_key,
        }
        (
            self._client.table("users_profile")
            .update(payload)
            .eq("user_id", user_id)
            .execute()
        )

    def update_profile(
        self,
        user_id: str,
        *,
        user_name: str | None = None,
        user_role: str | None = None,
    ) -> ProfileResponse:
        payload: dict[str, str] = {}
        if user_name is not None:
            payload["user_name"] = user_name
        if user_role is not None:
            payload["user_role"] = user_role
        if payload:
            (
                self._client.table("users_profile")
                .update(payload)
                .eq("user_id", user_id)
                .execute()
            )
        return self.get_profile_summary(user_id)

    def _fetch_profile_with_stats(self, user_id: str) -> dict[str, Any]:
        profile_response = (
            self._client.table("users_profile")
            .select(
                "user_name, user_role, level, current_exp, max_exp, credits, "
                "user_stats(completed_quest_count, earned_exp)",
            )
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return _single_row(profile_response)


def _single_row(response: Any) -> dict[str, Any]:
    rows = response.data or []
    if not rows:
        raise ValueError("Profile was not found for the given user_id.")
    return rows[0]
