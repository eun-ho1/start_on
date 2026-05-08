from app.core.crypto import SecretCipher
from app.providers.notion_client import NotionClient, NotionClientError
from app.repositories.notion_connection_repository import NotionConnectionRepository
from app.repositories.profile_repository import SupabaseProfileRepository
from app.repositories.quest_repository import SupabaseQuestRepository
from app.schemas.notion import (
    NotionConnectRequest,
    NotionConnectResponse,
    NotionSyncRequest,
    NotionSyncResponse,
)
from app.services.notion_parser import parse_notion_pages_to_quests
from app.services.notion_sync_service import IntegrationException


class NotionBackendService:
    def __init__(
        self,
        *,
        notion_client: NotionClient,
        notion_connection_repository: NotionConnectionRepository,
        profile_repository: SupabaseProfileRepository,
        quest_repository: SupabaseQuestRepository,
        secret_cipher: SecretCipher,
    ) -> None:
        self._notion_client = notion_client
        self._notion_connection_repository = notion_connection_repository
        self._profile_repository = profile_repository
        self._quest_repository = quest_repository
        self._secret_cipher = secret_cipher

    def connect(self, user_id: str, request: NotionConnectRequest) -> NotionConnectResponse:
        try:
            resolved = self._notion_client.resolve_source(
                notion_api_token=request.notion_api_token,
                database_id=request.data_source_id or request.database_id,
                database_url=request.database_url,
            )
            profile = self._profile_repository.get_profile_state(user_id)
            connection = self._notion_connection_repository.upsert_connection(
                user_id=user_id,
                profile_id=profile.profile_id,
                database_id=resolved.database_id,
                database_title=resolved.database_title,
                database_url=request.database_url or resolved.database_id,
                access_token_encrypted=self._secret_cipher.encrypt(
                    request.notion_api_token.strip(),
                ),
                sync_status="active",
            )
            return NotionConnectResponse(
                connection_id=connection["id"],
                database_id=resolved.database_id,
                database_title=resolved.database_title,
                sync_status=connection.get("sync_status", "active"),
            )
        except NotionClientError as error:
            raise IntegrationException(str(error)) from error
        except ValueError as error:
            raise IntegrationException(str(error)) from error

    def sync(self, user_id: str, request: NotionSyncRequest) -> NotionSyncResponse:
        try:
            connection = self._notion_connection_repository.get_connection_by_user_id(
                user_id,
            )
            notion_token = self._secret_cipher.decrypt(
                connection["access_token_encrypted"],
            )
            resolved = self._notion_client.resolve_source(
                notion_api_token=notion_token,
                database_id=connection.get("database_id"),
                database_url=connection.get("database_url"),
            )
            quests = parse_notion_pages_to_quests(resolved.pages)
            self._quest_repository.upsert_notion_quests(
                user_id=user_id,
                profile_id=connection["profile_id"],
                source_reference=resolved.database_id,
                quests=quests,
                pages=resolved.pages,
            )
            self._notion_connection_repository.mark_synced(connection["id"])
            return NotionSyncResponse(
                database_id=resolved.database_id,
                database_title=resolved.database_title,
                quests=quests,
            )
        except NotionClientError as error:
            raise IntegrationException(str(error)) from error
        except ValueError as error:
            raise IntegrationException(str(error)) from error
