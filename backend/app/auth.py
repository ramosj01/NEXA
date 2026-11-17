"""Authentication.

Production uses Firebase Authentication: clients send a Firebase ID token as
``Authorization: Bearer <token>`` (or ``?token=`` on the WebSocket). In dev
mode, a token of the form ``dev:<uid>`` or ``dev:<uid>:<Display Name>`` is
accepted so the API can be exercised without Firebase.
"""

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import User


class AuthError(Exception):
    pass


def _verify_token(token: str) -> tuple[str, str]:
    """Return (uid, display_name) for a valid token, else raise AuthError."""
    if settings.auth_mode == "dev":
        parts = token.split(":", 2)
        if len(parts) < 2 or parts[0] != "dev" or not parts[1]:
            raise AuthError("expected a dev:<uid> token")
        return parts[1], (parts[2] if len(parts) == 3 else parts[1])

    try:
        import firebase_admin
        from firebase_admin import auth as fb_auth
    except ImportError as exc:  # pragma: no cover
        raise AuthError("firebase-admin is not installed") from exc
    if not firebase_admin._apps:  # pragma: no cover
        firebase_admin.initialize_app()
    try:
        claims = fb_auth.verify_id_token(token)
    except Exception as exc:  # pragma: no cover
        raise AuthError("invalid Firebase ID token") from exc
    return claims["uid"], claims.get("name") or claims.get("email") or claims["uid"]


def user_from_token(token: str, db: Session) -> User:
    uid, name = _verify_token(token)
    user = db.get(User, uid)
    if user is None:
        user = User(id=uid, display_name=name)
        db.add(user)
        db.commit()
    return user


def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")
    try:
        return user_from_token(authorization[7:].strip(), db)
    except AuthError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc)) from exc
