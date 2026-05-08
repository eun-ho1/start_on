from pydantic import BaseModel


class DungeonStatusResponse(BaseModel):
    dungeonId: str
    cleared: bool
    creditReward: int
    clearedAt: str | None = None


class DungeonListResponse(BaseModel):
    dungeons: list[DungeonStatusResponse]


class DungeonClearResponse(BaseModel):
    dungeonId: str
    cleared: bool
    credits: int
    clearedAt: str
