from datetime import datetime
from typing import Any


class QuestGenerationLogRepository:
    def __init__(self, client: Any) -> None:
        self._client = client

    def create_log(
        self,
        *,
        user_id: str,
        provider: str,
        source_text: str,
        generated_count: int,
        accepted_count: int,
        request_payload: dict[str, Any],
        response_payload: dict[str, Any],
        status: str,
        error_message: str | None = None,
        created_at: datetime | None = None,
    ) -> None:
        payload = {
            "user_id": user_id,
            "provider": provider,
            "source_text": source_text,
            "generated_count": generated_count,
            "accepted_count": accepted_count,
            "request_payload": request_payload,
            "response_payload": response_payload,
            "status": status,
            "error_message": error_message,
            "created_at": (created_at or datetime.utcnow()).isoformat(),
        }
        self._client.table("quest_generation_logs").insert(payload).execute()
