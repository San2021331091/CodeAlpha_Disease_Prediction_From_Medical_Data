"""Configuration precedence: process environment > service .env > project .env."""
from dataclasses import dataclass
import os
from pathlib import Path
from dotenv import dotenv_values

SERVICE_ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Settings:
    model_dir: Path
    host: str
    port: int

    @classmethod
    def load(cls, service_root: Path = SERVICE_ROOT, environ=None):
        values = {**dotenv_values(service_root.parent / ".env"),
                  **dotenv_values(service_root / ".env"),
                  **(os.environ if environ is None else environ)}
        model_dir = Path(values.get("MODEL_DIR") or "saved_models")
        if not model_dir.is_absolute():
            model_dir = service_root / model_dir
        port = int(values.get("ML_PORT") or "8000")
        if not 1 <= port <= 65535:
            raise ValueError("ML_PORT must be between 1 and 65535")
        host = values.get("ML_HOST") or "127.0.0.1"
        return cls(model_dir.resolve(), host, port)
