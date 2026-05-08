from typing import Generic, TypeVar

from pydantic import BaseModel, Field


class ErrorDetail(BaseModel):
    code: str = Field(..., description="Machine-readable error code.")
    message: str = Field(..., description="Human-readable error message.")


class EmptyPayload(BaseModel):
    pass


PayloadT = TypeVar("PayloadT")


class ApiResponse(BaseModel, Generic[PayloadT]):
    success: bool = Field(..., description="Whether the request succeeded.")
    data: PayloadT | None = Field(
        default=None,
        description="Response payload for successful requests.",
    )
    error: ErrorDetail | None = Field(
        default=None,
        description="Error information for failed requests.",
    )
