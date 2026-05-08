import os
from functools import lru_cache
from typing import Any

from app.core.config import settings


_PROXY_ENV_KEYS = (
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "GIT_HTTP_PROXY",
    "GIT_HTTPS_PROXY",
)

def _disable_proxy_env() -> None:
    for key in _PROXY_ENV_KEYS:
        os.environ.pop(key, None)


def create_supabase_client() -> Any:
    try:
        from supabase import create_client
    except ModuleNotFoundError as error:
        raise RuntimeError(
            "Supabase client dependency is not installed. "
            "Run `pip install -r requirements.txt` in the backend directory.",
        ) from error

    # Local development environments sometimes inject a dead local proxy.
    # Supabase/httpx inherits those env vars and then fails before reaching the API.
    # We remove them for this backend process because local API calls should go direct.
    _disable_proxy_env()
    return create_client(
        settings.supabase_url,
        settings.supabase_service_role_key,
    )


@lru_cache
def get_supabase_client() -> Any:
    return create_supabase_client()


@lru_cache
def get_supabase_admin_client() -> Any:
    return create_supabase_client()
