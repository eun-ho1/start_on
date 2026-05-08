from app.repositories.base import ProfileRepository
from app.schemas.profile import ProfileResponse


class ProfileService:
    def __init__(self, profile_repository: ProfileRepository) -> None:
        self._profile_repository = profile_repository

    def get_profile_summary(self, user_id: str) -> ProfileResponse:
        return self._profile_repository.get_profile_summary(user_id)

    def update_profile(
        self,
        user_id: str,
        *,
        user_name: str | None = None,
        user_role: str | None = None,
    ) -> ProfileResponse:
        return self._profile_repository.update_profile(
            user_id,
            user_name=user_name,
            user_role=user_role,
        )
