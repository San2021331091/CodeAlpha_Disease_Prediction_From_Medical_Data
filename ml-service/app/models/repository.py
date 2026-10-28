from pathlib import Path
import joblib


class ModelUnavailable(Exception):
    pass


class ModelRepository:
    """Only reads the locally configured, trusted training artifact."""
    def __init__(self, model_dir: Path):
        self.model_dir = model_dir
        self._bundle = None

    def load(self):
        path = self.model_dir / "bundle.joblib"
        self._bundle = joblib.load(path) if path.exists() else None

    @property
    def ready(self):
        return self._bundle is not None

    @property
    def bundle(self):
        if self._bundle is None:
            raise ModelUnavailable("Model artifacts missing. Run python train.py and restart the service.")
        return self._bundle
