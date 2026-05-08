from app.providers.notion_client import NotionClient, NotionClientError
from app.schemas.notion import NotionSyncRequest, NotionSyncResponse
from app.services.notion_parser import parse_notion_pages_to_quests


class IntegrationException(Exception):
    pass


class NotionSyncService:
    """Token handling is request-scoped only. Persisted token policy should be decided separately."""

    def __init__(self, client: NotionClient | None = None) -> None:
        self._client = client or NotionClient()

    def sync(self, request: NotionSyncRequest) -> NotionSyncResponse:
        raise IntegrationException(
            "Direct request-scoped Notion sync is deprecated. Use the saved connection flow.",
        )
