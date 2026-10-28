from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, StrictFloat, StrictInt


class PredictionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    disease: Literal["breast_cancer", "heart_disease", "diabetes"] = "breast_cancer"
    model: Literal["auto", "logistic_regression", "random_forest", "svm", "xgboost"] = "auto"
    features: dict[str, StrictFloat | StrictInt | None] = Field(min_length=1, max_length=30)


class FeatureImportance(BaseModel):
    feature: str
    label: str
    importance: float


class PredictionResponse(BaseModel):
    disease: str
    disease_name: str
    label: str
    label_display: str
    positive_label: str
    negative_label: str
    positive_probability: float = Field(ge=0, le=1)
    negative_probability: float = Field(ge=0, le=1)
    malignant_probability: float | None = Field(default=None, ge=0, le=1)
    benign_probability: float | None = Field(default=None, ge=0, le=1)
    model: str
    model_name: str
    warnings: list[str]
    notice: str
    top_features: list[FeatureImportance]
    explanation: str
