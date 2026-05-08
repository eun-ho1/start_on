from fastapi import APIRouter, Depends
from fastapi import HTTPException, status

from app.api.dependencies import get_current_user_id, get_profile_service
from app.schemas.common import ApiResponse, ErrorDetail
from app.schemas.profile import ProfileResponse, ProfileUpdateRequest
from app.services.profile_service import ProfileService

router = APIRouter()

ProfileApiResponse = ApiResponse[ProfileResponse]


@router.get(
    "/profile",
    response_model=ProfileApiResponse,
    summary="Get profile summary",
    description="Return the user's profile and core progression state from Supabase.",
)
async def get_profile(
    user_id: str = Depends(get_current_user_id),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ProfileApiResponse:
    try:
        profile = profile_service.get_profile_summary(user_id)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=ErrorDetail(
                code="profile_not_found",
                message=str(error),
            ).model_dump(),
        ) from error
    return ProfileApiResponse(success=True, data=profile, error=None)


@router.patch(
    "/profile",
    response_model=ProfileApiResponse,
    summary="Update profile",
)
async def update_profile(
    payload: ProfileUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ProfileApiResponse:
    try:
        profile = profile_service.update_profile(
            user_id,
            user_name=payload.userName,
            user_role=payload.userRole,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=ErrorDetail(
                code="profile_not_found",
                message=str(error),
            ).model_dump(),
        ) from error
    return ProfileApiResponse(success=True, data=profile, error=None)
