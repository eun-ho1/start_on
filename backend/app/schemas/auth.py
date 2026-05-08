from pydantic import BaseModel, EmailStr


class AuthEmailPasswordRequest(BaseModel):
    email: EmailStr
    password: str


class AuthUserResponse(BaseModel):
    id: str
    email: str | None = None


class AuthSessionResponse(BaseModel):
    accessToken: str
    refreshToken: str | None = None
    user: AuthUserResponse
