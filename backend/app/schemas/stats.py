from pydantic import BaseModel, Field


class StatsSummaryResponse(BaseModel):
    dailyRewardCount: int
    dailyRewardTarget: int
    weeklyRewardCount: int
    weeklyRewardTarget: int
    monthlyRewardCount: int
    monthlyRewardTarget: int
    weeklyCompletedCount: int
    weeklyCompletionRate: int = Field(
        ...,
        description="Weekly completion rate as an integer percentage.",
    )
    weeklyRateDelta: int
    diligenceStat: int
    orderStat: int
    intelligenceStat: int
    healthStat: int
