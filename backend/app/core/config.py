from pathlib import Path

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(Path(__file__).resolve().parents[2] / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = Field(default="Start On API", alias="APP_NAME")
    app_version: str = Field(default="0.1.0", alias="APP_VERSION")
    environment: str = Field(default="development", alias="APP_ENV")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    api_host: str = Field(default="0.0.0.0", alias="API_HOST")
    api_port: int = Field(default=8000, alias="API_PORT")
    api_reload: bool = Field(default=False, alias="API_RELOAD")
    api_v1_prefix: str = Field(default="/api/v1", alias="API_V1_PREFIX")
    app_description: str = Field(
        default=(
            "FastAPI backend for Start On. "
            "Provides health checks, quest generation, OCR text extraction, "
            "Notion sync, and placeholder profile/stat endpoints."
        ),
        alias="APP_DESCRIPTION",
    )
    supabase_url: str | None = Field(default=None, alias="SUPABASE_URL")
    supabase_service_role_key: str | None = Field(
        default=None,
        alias="SUPABASE_SERVICE_ROLE_KEY",
    )
    supabase_anon_key: str | None = Field(default=None, alias="SUPABASE_ANON_KEY")
    gemini_api_key: str | None = Field(default=None, alias="GEMINI_API_KEY")
    notion_token_encryption_key: str | None = Field(
        default=None,
        alias="NOTION_TOKEN_ENCRYPTION_KEY",
    )

    @model_validator(mode="after")
    def validate_required_external_service_settings(self) -> "Settings":
        missing_fields: list[str] = []
        if not self.supabase_url:
            missing_fields.append("SUPABASE_URL")
        if not self.supabase_service_role_key:
            missing_fields.append("SUPABASE_SERVICE_ROLE_KEY")

        if missing_fields:
            missing_values = ", ".join(missing_fields)
            raise ValueError(
                "Missing required environment variables: "
                f"{missing_values}. Check backend/.env or your deployment secrets.",
            )

        return self


settings = Settings()
