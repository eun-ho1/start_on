from fastapi import APIRouter

from app.core.config import settings
from app.schemas.health import (
    HealthApiResponse,
    HealthReadinessApiResponse,
    HealthReadinessResponse,
    HealthResponse,
    ReadinessCheckResponse,
)

router = APIRouter()


@router.get("/health", response_model=HealthApiResponse)
async def health_check() -> HealthApiResponse:
    return HealthApiResponse(
        success=True,
        data=HealthResponse(
            status="ok",
            app_name=settings.app_name,
            environment=_get_environment(),
            version=settings.app_version,
        ),
        error=None,
    )


@router.get("/health/ready", response_model=HealthReadinessApiResponse)
async def readiness_check() -> HealthReadinessApiResponse:
    checks = _build_readiness_checks()
    overall_status = "ready" if all(check.status == "ok" for check in checks) else "not_ready"

    return HealthReadinessApiResponse(
        success=True,
        data=HealthReadinessResponse(
            status=overall_status,
            app_name=settings.app_name,
            environment=_get_environment(),
            version=settings.app_version,
            checks=checks,
        ),
        error=None,
    )


def _get_environment() -> str:
    return settings.environment


def _build_readiness_checks() -> list[ReadinessCheckResponse]:
    return [
        ReadinessCheckResponse(
            name="config",
            status="ok",
            detail="Application settings are available.",
        ),
        ReadinessCheckResponse(
            name="dependencies",
            status="ok",
            detail="No external dependencies are required for startup yet.",
        ),
    ]
