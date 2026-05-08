from abc import ABC, abstractmethod

from app.schemas.quest_generation import (
    OCRTextQuestExtractionRequest,
    OCRTextQuestExtractionResponse,
    QuestGenerationRequest,
    QuestGenerationResponse,
)


class QuestGenerationProvider(ABC):
    @abstractmethod
    def generate(self, request: QuestGenerationRequest) -> QuestGenerationResponse:
        """Generate quest candidates from prompt and/or source text."""

    @abstractmethod
    def extract_from_text(
        self,
        request: OCRTextQuestExtractionRequest,
    ) -> OCRTextQuestExtractionResponse:
        """Extract quest candidates directly from OCR-like raw text."""
