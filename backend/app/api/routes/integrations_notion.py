from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user_id, get_notion_backend_service
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.notion import (
    NotionConnectRequest,
    NotionConnectResponse,
    NotionSyncRequest,
    NotionSyncResponse,
)
from app.services.notion_backend_service import NotionBackendService
from app.services.notion_sync_service import IntegrationException

router = APIRouter()

NotionConnectApiResponse = ApiResponse[NotionConnectResponse]
NotionSyncApiResponse = ApiResponse[NotionSyncResponse]


@router.post(
    "/integrations/notion/connect",
    response_model=NotionConnectApiResponse,
    summary="Connect a user's Notion integration",
    description=(
        "Stores an encrypted Notion token and the selected database or data source "
        "for later server-side sync."
    ),
)
async def connect_notion(
    payload: NotionConnectRequest,
    user_id: str = Depends(get_current_user_id),
    notion_service: NotionBackendService = Depends(get_notion_backend_service),
) -> NotionConnectApiResponse:
    try:
        result = notion_service.connect(user_id, payload)
    except IntegrationException as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=ErrorDetail(
                code="notion_connection_failed",
                message=str(error),
            ).model_dump(),
        ) from error
    except Exception as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=ErrorDetail(
                code="notion_connection_failed",
                message="Notion connection failed unexpectedly.",
            ).model_dump(),
        ) from error
    return NotionConnectApiResponse(success=True, data=result, error=None)


@router.post(
    "/integrations/notion/sync",
    response_model=NotionSyncApiResponse,
    summary="Sync quests from a saved Notion connection",
    description=(
        "Uses the saved Notion connection to fetch incomplete pages and upsert them "
        "into Supabase quests."
    ),
)
async def sync_notion_database(
    payload: NotionSyncRequest,
    user_id: str = Depends(get_current_user_id),
    notion_service: NotionBackendService = Depends(get_notion_backend_service),
) -> NotionSyncApiResponse:
    try:
        result = notion_service.sync(user_id, payload)
    except IntegrationException as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=ErrorDetail(
                code="notion_integration_failed",
                message=str(error),
            ).model_dump(),
        ) from error
    except Exception as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=ErrorDetail(
                code="notion_sync_failed",
                message="Notion sync failed unexpectedly.",
            ).model_dump(),
        ) from error

    return NotionSyncApiResponse(success=True, data=result, error=None)
