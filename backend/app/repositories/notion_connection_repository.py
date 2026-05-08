from datetime import datetime
from typing import Any


class NotionConnectionRepository:
    def __init__(self, client: Any) -> None:
        self._client = client

    def upsert_connection(
        self,
        *,
        user_id: str,
        profile_id: str,
        database_id: str,
        database_title: str,
        database_url: str,
        access_token_encrypted: str,
        sync_status: str = "active",
    ) -> dict[str, Any]:
        existing = (
            self._client.table("notion_connections")
            .select("id")
            .eq("user_id", user_id)
            .eq("database_id", database_id)
            .limit(1)
            .execute()
        )
        rows = existing.data or []
        payload = {
            "user_id": user_id,
            "profile_id": profile_id,
            "database_id": database_id,
            "database_title": database_title,
            "database_url": database_url,
            "access_token_encrypted": access_token_encrypted,
            "sync_status": sync_status,
        }
        if rows:
            response = (
                self._client.table("notion_connections")
                .update(payload)
                .eq("id", rows[0]["id"])
                .execute()
            )
            return (response.data or [])[0]

        response = self._client.table("notion_connections").insert(payload).execute()
        return (response.data or [])[0]

    def get_connection_by_user_id(self, user_id: str) -> dict[str, Any]:
        response = (
            self._client.table("notion_connections")
            .select("*")
            .eq("user_id", user_id)
            .order("updated_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = response.data or []
        if not rows:
            raise ValueError("No saved Notion connection was found for this user.")
        return rows[0]

    def mark_synced(self, connection_id: str) -> None:
        (
            self._client.table("notion_connections")
            .update(
                {
                    "last_synced_at": datetime.utcnow().isoformat(),
                    "sync_status": "active",
                },
            )
            .eq("id", connection_id)
            .execute()
        )
