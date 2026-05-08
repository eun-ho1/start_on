from datetime import datetime, timedelta

from typing import Any

from app.repositories.base import StatsRepository, StatsState
from app.schemas.stats import StatsSummaryResponse


class SupabaseStatsRepository(StatsRepository):
    def __init__(self, client: Any) -> None:
        self._client = client

    def get_stats_summary(self, user_id: str) -> StatsSummaryResponse:
        row = self._fetch_stats_row(user_id)
        return StatsSummaryResponse(
            dailyRewardCount=row["daily_reward_count"],
            dailyRewardTarget=row["daily_reward_target"],
            weeklyRewardCount=row["weekly_reward_count"],
            weeklyRewardTarget=row["weekly_reward_target"],
            monthlyRewardCount=row["monthly_reward_count"],
            monthlyRewardTarget=row["monthly_reward_target"],
            weeklyCompletedCount=row["weekly_completed_count"],
            weeklyCompletionRate=row["weekly_completion_rate"],
            weeklyRateDelta=row["weekly_rate_delta"],
            diligenceStat=row["diligence_stat"],
            orderStat=row["order_stat"],
            intelligenceStat=row["intelligence_stat"],
            healthStat=row["health_stat"],
        )

    def get_stats_state(self, user_id: str) -> StatsState:
        row = self._fetch_stats_row(user_id)
        return StatsState(
            stats_id=row["id"],
            completed_quest_count=row["completed_quest_count"],
            earned_exp=row["earned_exp"],
            daily_reward_count=row["daily_reward_count"],
            daily_reward_target=row["daily_reward_target"],
            weekly_reward_count=row["weekly_reward_count"],
            weekly_reward_target=row["weekly_reward_target"],
            monthly_reward_count=row["monthly_reward_count"],
            monthly_reward_target=row["monthly_reward_target"],
            weekly_completed_count=row["weekly_completed_count"],
            weekly_completion_rate=row["weekly_completion_rate"],
            previous_weekly_completion_rate=row["previous_weekly_completion_rate"],
            weekly_rate_delta=row["weekly_rate_delta"],
            diligence_stat=row["diligence_stat"],
            order_stat=row["order_stat"],
            intelligence_stat=row["intelligence_stat"],
            health_stat=row["health_stat"],
            weekly_activity_counts=row["weekly_activity_counts"] or [0] * 7,
            weekly_activity_bars=row["weekly_activity_bars"] or [0.0] * 7,
        )

    def update_stats_after_completion(
        self,
        user_id: str,
        *,
        completed_quest_count: int,
        earned_exp: int,
        daily_reward_count: int,
        weekly_reward_count: int,
        monthly_reward_count: int,
        weekly_completed_count: int,
        weekly_completion_rate: int,
        previous_weekly_completion_rate: int,
        weekly_rate_delta: int,
        diligence_stat: int,
        order_stat: int,
        intelligence_stat: int,
        health_stat: int,
        weekly_activity_counts: list[int],
        weekly_activity_bars: list[float],
    ) -> None:
        payload = {
            "completed_quest_count": completed_quest_count,
            "earned_exp": earned_exp,
            "daily_reward_count": daily_reward_count,
            "weekly_reward_count": weekly_reward_count,
            "monthly_reward_count": monthly_reward_count,
            "weekly_completed_count": weekly_completed_count,
            "weekly_completion_rate": weekly_completion_rate,
            "previous_weekly_completion_rate": previous_weekly_completion_rate,
            "weekly_rate_delta": weekly_rate_delta,
            "diligence_stat": diligence_stat,
            "order_stat": order_stat,
            "intelligence_stat": intelligence_stat,
            "health_stat": health_stat,
            "weekly_activity_counts": weekly_activity_counts,
            "weekly_activity_bars": weekly_activity_bars,
        }
        (
            self._client.table("user_stats")
            .update(payload)
            .eq("user_id", user_id)
            .execute()
        )

    def _fetch_stats_row(self, user_id: str) -> dict[str, Any]:
        response = (
            self._client.table("user_stats")
            .select(
                "id, previous_weekly_completion_rate, weekly_activity_counts, "
                "weekly_activity_bars, completed_quest_count, earned_exp, "
                "daily_reward_count, daily_reward_target, weekly_reward_count, "
                "weekly_reward_target, monthly_reward_count, monthly_reward_target, "
                "weekly_completed_count, weekly_completion_rate, weekly_rate_delta, "
                "diligence_stat, order_stat, intelligence_stat, health_stat",
            )
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return _single_row(response)

    def calculate_stats_summary(self, user_id: str) -> StatsSummaryResponse:
        stats = self.get_stats_state(user_id)
        now = datetime.now()
        today_start = datetime(now.year, now.month, now.day)
        week_start = today_start - timedelta(days=today_start.weekday())
        month_start = datetime(now.year, now.month, 1)

        completed_response = (
            self._client.table("completed_quests")
            .select("completed_at")
            .eq("user_id", user_id)
            .gte("completed_at", month_start.isoformat())
            .execute()
        )
        rows = completed_response.data or []
        daily_count = 0
        weekly_count = 0
        monthly_count = len(rows)
        for row in rows:
            completed_at = datetime.fromisoformat(
                str(row["completed_at"]).replace("Z", "+00:00"),
            )
            if completed_at.replace(tzinfo=None) >= today_start:
                daily_count += 1
            if completed_at.replace(tzinfo=None) >= week_start:
                weekly_count += 1

        weekly_completion_rate = 0
        if stats.weekly_reward_target > 0:
            weekly_completion_rate = min(
                100,
                round((weekly_count / stats.weekly_reward_target) * 100),
            )

        return StatsSummaryResponse(
            dailyRewardCount=min(stats.daily_reward_target, daily_count),
            dailyRewardTarget=stats.daily_reward_target,
            weeklyRewardCount=min(stats.weekly_reward_target, weekly_count),
            weeklyRewardTarget=stats.weekly_reward_target,
            monthlyRewardCount=min(stats.monthly_reward_target, monthly_count),
            monthlyRewardTarget=stats.monthly_reward_target,
            weeklyCompletedCount=weekly_count,
            weeklyCompletionRate=weekly_completion_rate,
            weeklyRateDelta=weekly_completion_rate - stats.previous_weekly_completion_rate,
            diligenceStat=stats.diligence_stat,
            orderStat=stats.order_stat,
            intelligenceStat=stats.intelligence_stat,
            healthStat=stats.health_stat,
        )


def _single_row(response: Any) -> dict[str, Any]:
    rows = response.data or []
    if not rows:
        raise ValueError("Stats were not found for the given user_id.")
    return rows[0]
