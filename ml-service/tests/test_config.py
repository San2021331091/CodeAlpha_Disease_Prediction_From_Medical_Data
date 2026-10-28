from pathlib import Path
from fastapi.testclient import TestClient
from app.config import Settings
from app.main import create_app


def test_dotenv_precedence_and_model_path(tmp_path):
    service = tmp_path / "ml"
    service.mkdir()
    (tmp_path / ".env").write_text("ML_PORT=8004\nML_HOST=127.0.0.1\n")
    (service / ".env").write_text("ML_PORT=8005\nMODEL_DIR=custom_models\n")
    settings = Settings.load(service, environ={"ML_PORT": "8006"})
    assert settings.port == 8006
    assert settings.model_dir == service / "custom_models"
    assert Settings.load(service, environ={}).port == 8005
    assert settings.host == "127.0.0.1"


def test_app_factory_reports_missing_artifacts(tmp_path):
    app = create_app(Settings(model_dir=Path(tmp_path), host="127.0.0.1", port=8000))
    with TestClient(app) as client:
        assert client.get("/health").status_code == 503
        assert client.get("/api/schema").status_code == 503
        assert "Model artifacts missing" in client.get("/api/metrics").json()["detail"]
