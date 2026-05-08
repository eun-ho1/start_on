from app.repositories.base import StatsRepository
from app.schemas.stats import StatsSummaryResponse


class StatsService:
    def __init__(self, stats_repository: StatsRepository) -> None:
        self._stats_repository = stats_repository

    def get_stats_summary(self, user_id: str) -> StatsSummaryResponse:
        return self._stats_repository.calculate_stats_summary(user_id)
