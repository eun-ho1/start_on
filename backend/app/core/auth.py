from dataclasses import dataclass

from fastapi import Header, HTTPException, status

from app.core.supabase import get_supabase_admin_client
from app.schemas.common import ErrorDetail


@dataclass(frozen=True)
class AuthenticatedUser:
    id: str
    email: str | None


def get_current_user(
    authorization: str | None = Header(
        default=None,
        alias="Authorization",
        description="Supabase access token in the form `Bearer <token>`.",
    ),
) -> AuthenticatedUser:
    if not authorization:
        raise _auth_error("missing_authorization", "Authorization header is required.")

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise _auth_error(
            "invalid_authorization",
            "Authorization header must use the Bearer scheme.",
        )

    try:
        response = get_supabase_admin_client().auth.get_user(token.strip())
    except Exception as error:
        raise _auth_error("invalid_token", "Supabase access token validation failed.") from error

    user = getattr(response, "user", None)
    user_id = getattr(user, "id", None)
    if not user_id:
        raise _auth_error("invalid_token", "Supabase access token is invalid or expired.")

    return AuthenticatedUser(
        id=str(user_id),
        email=getattr(user, "email", None),
    )


def _auth_error(code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=ErrorDetail(code=code, message=message).model_dump(),
        headers={"WWW-Authenticate": "Bearer"},
    )
