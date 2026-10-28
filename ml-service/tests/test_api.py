import pytest
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture()
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_metadata_and_real_inference(client):
    assert client.get("/health").status_code == 200
    schema = client.get("/api/schema").json()
    assert len(schema["features"]) == 30
    metrics = client.get("/api/metrics").json()
    assert metrics["train_samples"] + metrics["test_samples"] == 569
    assert len(metrics["models"]) == 4
    for sample in client.get("/api/samples").json()["samples"]:
        for model in ["auto", "logistic_regression", "random_forest", "svm", "xgboost"]:
            response = client.post("/api/predict", json={"model": model, "features": sample["features"]})
            assert response.status_code == 200
            result = response.json()
            assert result["label"] in ["benign", "malignant"]
            assert 0 <= result["malignant_probability"] <= 1
            assert result["benign_probability"] + result["malignant_probability"] == pytest.approx(1)


def test_invalid_measurements(client):
    sample = client.get("/api/samples").json()["samples"][0]["features"]
    assert client.post("/api/predict", json={"features": {}}).status_code == 422
    for value in [-1, 1e9, "bad", True]:
        assert client.post("/api/predict", json={"features": {**sample, "mean_radius": value}}).status_code == 422
    renamed = {**sample, "unknown": sample["mean_radius"]}
    del renamed["mean_radius"]
    assert client.post("/api/predict", json={"features": renamed}).status_code == 422
    assert client.post("/api/predict", json={"features": sample, "model": "fake"}).status_code == 422


def test_extrapolation_is_visible(client):
    sample = client.get("/api/samples").json()["samples"][0]["features"]
    response = client.post("/api/predict", json={"features": {**sample, "mean_radius": 9999}})
    assert response.status_code == 200
    assert response.json()["warnings"]
