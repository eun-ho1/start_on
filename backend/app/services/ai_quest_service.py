from datetime import datetime

from app.providers.gemini_ocr_quest_generation import GeminiOCRQuestGenerationProvider
from app.repositories.quest_generation_log_repository import QuestGenerationLogRepository
from app.schemas.ai import OCRQuestCandidate, OCRQuestCandidateRequest


class AIQuestService:
    def __init__(
        self,
        provider: GeminiOCRQuestGenerationProvider,
        log_repository: QuestGenerationLogRepository,
    ) -> None:
        self._provider = provider
        self._log_repository = log_repository

    def generate_from_ocr_text(
        self,
        request: OCRQuestCandidateRequest,
    ) -> list[OCRQuestCandidate]:
        now = datetime.utcnow()
        try:
            candidates, response_payload, status = self._provider.generate_candidates(
                ocr_text=request.ocr_text,
                preferred_categories=request.preferred_categories,
            )
            self._log_repository.create_log(
                user_id=request.user_id,
                provider="gemini",
                source_text=request.ocr_text,
                generated_count=len(candidates),
                accepted_count=len(candidates),
                request_payload=request.model_dump(mode="json"),
                response_payload=response_payload,
                status=status,
                created_at=now,
            )
            return candidates
        except Exception as error:
            candidates, fallback_payload, fallback_status = (
                self._provider.fallback_candidates(
                    ocr_text=request.ocr_text,
                )
            )
            self._log_repository.create_log(
                user_id=request.user_id,
                provider="rule_based_fallback",
                source_text=request.ocr_text,
                generated_count=len(candidates),
                accepted_count=len(candidates),
                request_payload=request.model_dump(mode="json"),
                response_payload=fallback_payload,
                status=fallback_status,
                error_message=str(error),
                created_at=now,
            )
            return candidates
