import numpy as np
from ..models.prediction import PredictionRequest
from ..models.repository import ModelRepository, ModelUnavailable
from ..views.responses import prediction_view, samples_view, schema_view


class InvalidMeasurements(Exception):
    pass


class PredictionService:
    def __init__(self, repository: ModelRepository):
        self.repository = repository

    def disease_bundle(self, disease):
        datasets = self.repository.bundle.get("diseases")
        if datasets is None:
            raise ModelUnavailable("Run python train.py to create the three-disease model bundle, then restart FastAPI.")
        if disease not in datasets:
            raise InvalidMeasurements("Unknown disease. Choose breast_cancer, heart_disease, or diabetes.")
        return datasets[disease]

    def catalog(self):
        return {"diseases": [{k: b["report"][k] for k in ["id", "name", "dataset", "description", "raw_samples", "total_samples", "feature_count", "positive_label", "negative_label"]} for b in self.repository.bundle["diseases"].values()]}

    def schema(self, disease="breast_cancer"):
        return schema_view(self.disease_bundle(disease))

    def metrics(self, disease="breast_cancer"):
        return self.disease_bundle(disease)["report"]

    def samples(self, disease="breast_cancer"):
        return samples_view(self.disease_bundle(disease)["samples"])

    def predict(self, request: PredictionRequest):
        data = self.disease_bundle(request.disease)
        expected = [f["id"] for f in data["features"]]
        if set(request.features) != set(expected):
            raise InvalidMeasurements(f"Features must exactly match /api/schema?disease={request.disease}; missing or unknown feature names.")
        values, warnings = [], []
        for feature in data["features"]:
            value = request.features[feature["id"]]
            if value is None:
                if not feature["nullable"]:
                    raise InvalidMeasurements(f"{feature['label']} is required.")
                values.append(np.nan)
                warnings.append(f"{feature['label']} was missing and imputed using training data only.")
                continue
            if not np.isfinite(value) or value < feature["allowed_min"] or value > feature["allowed_max"]:
                raise InvalidMeasurements(f"{feature['label']} must be a finite value from {feature['allowed_min']} to {feature['allowed_max']}.")
            options = [option["value"] for option in feature["options"]]
            if options and value not in options:
                raise InvalidMeasurements(f"{feature['label']} must use one of the schema's categorical values.")
            values.append(float(value))
            if value < feature["min"] or value > feature["max"]:
                warnings.append(f"{feature['label']} is outside the training range.")
        key = data["report"]["selected_model"] if request.model == "auto" else request.model
        model = data["models"][key]
        row = np.array(values).reshape(1, -1)
        positive = int(model.predict(row)[0]) == 1
        probability = float(model.predict_proba(row)[0, list(model.classes_).index(1)])
        report = next(m for m in data["report"]["models"] if m["id"] == key)
        return prediction_view(positive=positive, probability=probability, model_id=key, model_report=report, warnings=warnings, definition=data["report"])
