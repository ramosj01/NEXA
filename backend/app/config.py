"""Runtime configuration, read from environment variables."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    # PostgreSQL in production, e.g. postgresql+psycopg://user:pass@host/nexa
    database_url: str = os.getenv("NEXA_DATABASE_URL", "sqlite:///./nexa-dev.db")
    # "firebase" verifies Firebase ID tokens; "dev" accepts "dev:<uid>" tokens.
    auth_mode: str = os.getenv("NEXA_AUTH_MODE", "dev")
    # Model behind the NEXA Assistant; the key comes from ANTHROPIC_API_KEY.
    assistant_model: str = os.getenv("NEXA_ASSISTANT_MODEL", "claude-opus-5-5")
    cors_origins: tuple[str, ...] = tuple(
        o for o in os.getenv("NEXA_CORS_ORIGINS", "*").split(",") if o
    )


settings = Settings()
