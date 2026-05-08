from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_current_user_id, get_stats_service
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.stats import StatsSummaryResponse
from app.services.stats_service import StatsService

router = APIRouter()

StatsSummaryApiResponse = ApiResponse[StatsSummaryResponse]


@router.get(
    "/stats/summary",
    response_model=StatsSummaryApiResponse,
    summary="Get stats summary",
    description="Calculate the user's daily, weekly, and monthly stats from completed quests.",
)
async def get_stats_summary(
    user_id: str = Depends(get_current_user_id),
    stats_service: StatsService = Depends(get_stats_service),
) -> StatsSummaryApiResponse:
    try:
        summary = stats_service.get_stats_summary(user_id)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=ErrorDetail(
                code="stats_not_found",
                message=str(error),
            ).model_dump(),
        ) from error
    return StatsSummaryApiResponse(success=True, data=summary, error=None)
