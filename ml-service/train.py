import json
from app.training import train_models
from app.config import Settings

if __name__ == "__main__":
    report = train_models(Settings.load().model_dir)
    print(json.dumps({disease: {"raw": r["raw_samples"], "unique": r["total_samples"], "selected_model": r["selected_model"], "models": [{k: m[k] for k in ["id", "accuracy", "f1", "roc_auc"]} for m in r["models"]]} for disease, r in report.items()}, indent=2))
