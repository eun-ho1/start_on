from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies import get_ai_quest_service
from app.schemas.ai import OCRQuestCandidateRequest, OCRQuestCandidatesResponse
from app.schemas.common import ApiResponse, ErrorDetail
from app.services.ai_quest_service import AIQuestService

router = APIRouter()

OCRQuestCandidatesApiResponse = ApiResponse[OCRQuestCandidatesResponse]


@router.post(
    "/quests/from-ocr-text",
    response_model=OCRQuestCandidatesApiResponse,
    summary="Generate quest candidates from OCR text with Gemini",
    description=(
        "Uses Gemini to generate structured quest candidates from OCR text. "
        "If Gemini JSON parsing fails, the API falls back to the existing "
        "rule-based provider and logs the result."
    ),
)
async def generate_quests_from_ocr_text(
    payload: OCRQuestCandidateRequest,
    ai_quest_service: AIQuestService = Depends(get_ai_quest_service),
) -> OCRQuestCandidatesApiResponse:
    try:
        candidates = ai_quest_service.generate_from_ocr_text(payload)
    except Exception as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=ErrorDetail(
                code="ai_quest_generation_failed",
                message=str(error),
            ).model_dump(),
        ) from error

    return OCRQuestCandidatesApiResponse(
        success=True,
        data=OCRQuestCandidatesResponse(candidates=candidates),
        error=None,
    )
