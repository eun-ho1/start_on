from pydantic import BaseModel


class ProfileUpdateRequest(BaseModel):
    userName: str | None = None
    userRole: str | None = None


class ProfileResponse(BaseModel):
    userName: str
    userRole: str
    level: int
    currentExp: int
    maxExp: int
    credits: int
    completedQuestCount: int
    earnedExp: int
