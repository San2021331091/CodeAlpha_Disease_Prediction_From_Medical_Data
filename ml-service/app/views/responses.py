"""JSON view representations for three independent disease datasets."""
from ..models.prediction import PredictionResponse
from ..datasets import NOTICE


def schema_view(data):
    report = data["report"]
    return {"disease": report["disease"], "disease_name": report["name"], "description": report["description"],
            "positive_label": report["positive_label"], "negative_label": report["negative_label"],
            "features": data["features"], "selected_model": report["selected_model"],
            "models": [{"id": m["id"], "name": m["name"]} for m in report["models"]], "notice": NOTICE}


def samples_view(examples):
    return {"samples": examples, "notice": "Public benchmark records. Labels are for comparison, not inputs to the classifier."}


def prediction_view(*, positive, probability, model_id, model_report, warnings, definition):
    disease = definition["disease"]
    return PredictionResponse(
        disease=disease, disease_name=definition["name"],
        label=definition["positive_class"] if positive else definition["negative_class"],
        label_display=definition["positive_label"] if positive else definition["negative_label"],
        positive_label=definition["positive_label"], negative_label=definition["negative_label"],
        positive_probability=probability, negative_probability=1-probability,
        malignant_probability=probability if disease == "breast_cancer" else None,
        benign_probability=1-probability if disease == "breast_cancer" else None,
        model=model_id, model_name=model_report["name"], warnings=warnings, notice=NOTICE,
        top_features=model_report["feature_importance"],
        explanation="Global permutation importance on training data; not a patient-specific explanation. Model scores are not validated clinical risk estimates.",
    )
