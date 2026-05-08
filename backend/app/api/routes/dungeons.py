from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user_id, get_dungeon_service
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.dungeon import (
    DungeonClearResponse,
    DungeonListResponse,
)
from app.services.dungeon_service import DungeonService

router = APIRouter()

DungeonListApiResponse = ApiResponse[DungeonListResponse]
DungeonClearApiResponse = ApiResponse[DungeonClearResponse]


@router.get(
    "/dungeons",
    response_model=DungeonListApiResponse,
    summary="List dungeon clear status",
)
async def list_dungeons(
    user_id: str = Depends(get_current_user_id),
    dungeon_service: DungeonService = Depends(get_dungeon_service),
) -> DungeonListApiResponse:
    dungeons = dungeon_service.list_dungeons(user_id)
    return DungeonListApiResponse(
        success=True,
        data=DungeonListResponse(dungeons=dungeons),
        error=None,
    )


@router.post(
    "/dungeons/{dungeon_id}/clear",
    response_model=DungeonClearApiResponse,
    summary="Clear a dungeon and grant rewards",
)
async def clear_dungeon(
    dungeon_id: str,
    user_id: str = Depends(get_current_user_id),
    dungeon_service: DungeonService = Depends(get_dungeon_service),
) -> DungeonClearApiResponse:
    try:
        result = dungeon_service.clear_dungeon(user_id, dungeon_id)
    except ValueError as error:
        if "Profile" in str(error):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=ErrorDetail(
                    code="profile_not_found",
                    message=str(error),
                ).model_dump(),
            ) from error
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=ErrorDetail(
                code="dungeon_not_found",
                message=str(error),
            ).model_dump(),
        ) from error
    return DungeonClearApiResponse(success=True, data=result, error=None)
