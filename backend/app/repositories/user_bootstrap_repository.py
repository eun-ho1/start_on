from typing import Any


class SupabaseUserBootstrapRepository:
    def __init__(self, client: Any) -> None:
        self._client = client

    def ensure_user_records(self, user_id: str, *, email: str | None = None) -> None:
        profile = self._ensure_profile(user_id, email=email)
        self._ensure_stats(user_id, profile_id=profile["id"])

    def _ensure_profile(self, user_id: str, *, email: str | None = None) -> dict[str, Any]:
        response = (
            self._client.table("users_profile")
            .upsert(
                {
                    "user_id": user_id,
                    "user_name": _default_user_name(email),
                },
                on_conflict="user_id",
            )
            .execute()
        )
        rows = response.data or []
        if rows:
            return rows[0]

        fallback = (
            self._client.table("users_profile")
            .select("id")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        fallback_rows = fallback.data or []
        if not fallback_rows:
            raise ValueError("Unable to create or load the profile for the authenticated user.")
        return fallback_rows[0]

    def _ensure_stats(self, user_id: str, *, profile_id: str) -> None:
        self._client.table("user_stats").upsert(
            {
                "user_id": user_id,
                "profile_id": profile_id,
            },
            on_conflict="user_id",
        ).execute()


def _default_user_name(email: str | None) -> str:
    if not email:
        return "Adventurer"
    candidate = email.split("@", 1)[0].strip()
    return candidate[:40] or "Adventurer"
