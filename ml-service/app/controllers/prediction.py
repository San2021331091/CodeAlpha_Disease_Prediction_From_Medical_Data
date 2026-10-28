from typing import Annotated
from fastapi import APIRouter, Depends, Request
from ..models.prediction import PredictionRequest, PredictionResponse
from ..models.repository import ModelUnavailable
from ..services.prediction import PredictionService

router = APIRouter()


def get_service(request: Request) -> PredictionService:
    return request.app.state.prediction_service


Service = Annotated[PredictionService, Depends(get_service)]


@router.get("/health")
def health(service: Service):
    if not service.repository.ready:
        raise ModelUnavailable("Model artifacts missing")
    return {"status": "ok", "service": "cellscope-ml", "model_ready": True}


@router.get("/api/schema")
def schema(service: Service, disease: str = "breast_cancer"):
    return service.schema(disease)


@router.get("/api/metrics")
def metrics(service: Service, disease: str = "breast_cancer"):
    return service.metrics(disease)


@router.get("/api/samples")
def samples(service: Service, disease: str = "breast_cancer"):
    return service.samples(disease)


@router.get("/api/diseases")
def diseases(service: Service):
    return service.catalog()


@router.post("/api/predict", response_model=PredictionResponse)
def predict(body: PredictionRequest, service: Service):
    return service.predict(body)
