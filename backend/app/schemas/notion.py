from pydantic import BaseModel, Field, model_validator

from app.schemas.quest_generation import QuestCandidateResponse


class NotionConnectRequest(BaseModel):
    notion_api_token: str = Field(..., min_length=1)
    database_id: str | None = None
    database_url: str | None = None
    data_source_id: str | None = None

    @model_validator(mode="after")
    def validate_database_identifier(self) -> "NotionConnectRequest":
        has_database_id = bool(self.database_id and self.database_id.strip())
        has_database_url = bool(self.database_url and self.database_url.strip())
        has_data_source_id = bool(self.data_source_id and self.data_source_id.strip())
        if not has_database_id and not has_database_url and not has_data_source_id:
            raise ValueError(
                "Either database_id, database_url, or data_source_id must be provided.",
            )
        return self


class NotionConnectResponse(BaseModel):
    connection_id: str
    database_id: str
    database_title: str
    sync_status: str


class NotionSyncRequest(BaseModel):
    pass


class NotionSyncResponse(BaseModel):
    database_id: str
    database_title: str
    quests: list[QuestCandidateResponse]
