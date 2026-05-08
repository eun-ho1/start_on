from pydantic import BaseModel, Field, model_validator

from app.schemas.quest import QuestCategory, QuestDifficulty


class OCRQuestCandidateRequest(BaseModel):
    user_id: str = Field(..., min_length=1)
    ocr_text: str = Field(..., min_length=1)
    preferred_categories: list[QuestCategory] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_ocr_text(self) -> "OCRQuestCandidateRequest":
        if not self.ocr_text.strip():
            raise ValueError("ocr_text must not be empty.")
        return self


class OCRQuestCandidate(BaseModel):
    title: str
    difficulty: QuestDifficulty
    category: QuestCategory
    exp: int
    defaultDurationSeconds: int
    reason: str


class OCRQuestCandidatesResponse(BaseModel):
    candidates: list[OCRQuestCandidate]
