import logging

from fastapi import APIRouter, HTTPException, status

from app.core.config import settings
from app.core.supabase import get_supabase_client


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/debug")


@router.get("/supabase")
async def debug_supabase() -> dict[str, object]:
    _ensure_development_environment()

    try:
        client = get_supabase_client()
        _run_connection_check(client)
    except Exception as exc:
        logger.warning("Supabase debug connection check failed: %s", exc)
        return {
            "ok": False,
            "message": _safe_error_message(exc),
        }

    return {
        "ok": True,
        "message": "Supabase connected",
    }


def _ensure_development_environment() -> None:
    if settings.environment.lower() != "development":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not found.",
        )


def _run_connection_check(client: object) -> None:
    errors: list[Exception] = []

    for table_name in ("users_profile", "quests"):
        try:
            (
                client.table(table_name)
                .select("*")
                .limit(1)
                .execute()
            )
            return
        except Exception as exc:
            errors.append(exc)

    raise errors[-1]


def _safe_error_message(exc: Exception) -> str:
    message = str(exc).strip()
    lowered = message.lower()

    if isinstance(exc, RuntimeError):
        return message
    if "apikey" in lowered or "authorization" in lowered or "jwt" in lowered:
        return "Supabase connection check failed due to authentication settings."
    if "url" in lowered or "dns" in lowered or "network" in lowered:
        return "Supabase connection check failed due to network or project URL settings."
    if "relation" in lowered or "table" in lowered:
        return "Supabase connected, but the debug tables could not be queried."

    return "Supabase connection check failed."
