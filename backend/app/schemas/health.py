from pydantic import BaseModel, Field

from app.schemas.common import ApiResponse


class HealthResponse(BaseModel):
    status: str
    app_name: str
    environment: str
    version: str


HealthApiResponse = ApiResponse[HealthResponse]


class ReadinessCheckResponse(BaseModel):
    name: str
    status: str
    detail: str = Field(
        ...,
        description="Short human-readable description of the check result.",
    )


class HealthReadinessResponse(BaseModel):
    status: str
    app_name: str
    environment: str
    version: str
    checks: list[ReadinessCheckResponse]


HealthReadinessApiResponse = ApiResponse[HealthReadinessResponse]
