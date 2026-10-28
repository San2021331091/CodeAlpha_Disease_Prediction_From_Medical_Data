import numpy as np
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.datasets import load_dataset


@pytest.fixture()
def client():
    with TestClient(app) as value:
        yield value


@pytest.mark.parametrize("disease,raw_count,feature_count", [("breast_cancer",569,30),("heart_disease",303,13),("diabetes",520,16)])
def test_all_diseases_use_real_independent_models(client, disease, raw_count, feature_count):
    schema = client.get(f"/api/schema?disease={disease}").json()
    assert schema["disease"] == disease
    assert len(schema["features"]) == feature_count
    report = client.get(f"/api/metrics?disease={disease}").json()
    assert {m["id"] for m in report["models"]} == {"logistic_regression", "random_forest", "svm", "xgboost"}
    assert report["raw_samples"] == raw_count
    assert report["train_samples"] + report["test_samples"] == report["total_samples"]
    assert report["total_samples"] + report["duplicate_rows_removed"] + report["conflicting_rows_removed"] == raw_count
    assert not set(report["train_row_ids"]) & set(report["test_row_ids"])
    for sample in client.get(f"/api/samples?disease={disease}").json()["samples"]:
        for model in ["auto","logistic_regression","random_forest","svm","xgboost"]:
            response = client.post("/api/predict", json={"disease": disease, "model": model, "features": sample["features"]})
            assert response.status_code == 200, response.text
            result = response.json()
            assert result["disease"] == disease
            assert result["label"] in [report["negative_class"], report["positive_class"]]
            assert result["negative_probability"] + result["positive_probability"] == pytest.approx(1)
            assert result["malignant_probability"] is None if disease != "breast_cancer" else result["malignant_probability"] is not None


def test_catalog_and_cross_disease_rejection(client):
    assert len(client.get("/api/diseases").json()["diseases"]) == 3
    assert client.get("/api/schema?disease=unknown").status_code == 422
    breast = client.get("/api/samples").json()["samples"][0]["features"]
    assert client.post("/api/predict", json={"disease":"heart_disease", "features":breast}).status_code == 422
    assert client.post("/api/predict", json={"disease":"unknown", "features":breast}).status_code == 422


def test_categorical_values_and_optional_imputation(client):
    features = client.get("/api/samples?disease=heart_disease").json()["samples"][0]["features"]
    for field, value in [("cp",9),("sex",True),("age",None),("age",999)]:
        assert client.post("/api/predict", json={"disease":"heart_disease", "features":{**features,field:value}}).status_code == 422
    response = client.post("/api/predict", json={"disease":"heart_disease", "features":{**features,"ca":None,"thal":None}})
    assert response.status_code == 200
    assert sum("imputed" in warning for warning in response.json()["warnings"]) == 2


@pytest.mark.parametrize("disease", ["breast_cancer","heart_disease","diabetes"])
def test_identical_features_cannot_leak_across_splits(disease):
    dataset = load_dataset(disease)
    train, test = dataset.split()
    signatures = lambda indices: {tuple(None if np.isnan(v) else v for v in dataset.x[i]) for i in indices}
    assert not signatures(train) & signatures(test)
    assert len(signatures(range(len(dataset.y)))) == len(dataset.y)
