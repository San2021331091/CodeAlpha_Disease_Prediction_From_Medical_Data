"""Explicit UCI source mappings, feature types, and reproducible row preparation."""
import csv
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import numpy as np
from sklearn.datasets import load_breast_cancer
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parents[1]
SEED = 42
NOTICE = "Educational public-dataset demonstration only. Not a diagnosis or a validated clinical risk estimate."
DEFINITIONS = {
    "breast_cancer": {"id": "breast_cancer", "name": "Breast Cancer", "dataset": "UCI Wisconsin Diagnostic Breast Cancer", "source_url": "https://archive.ics.uci.edu/dataset/17/breast+cancer+wisconsin+diagnostic", "doi": "https://doi.org/10.24432/C5DW2B", "negative_class": "benign", "positive_class": "malignant", "negative_label": "Benign", "positive_label": "Malignant", "description": "Digitized fine-needle aspirate cell-nucleus measurements: mean, standard error, and worst values. These are laboratory image features, not symptoms.", "citation": "Wolberg, Mangasarian, Street & Street (1993). Breast Cancer Wisconsin (Diagnostic). UCI."},
    "heart_disease": {"id": "heart_disease", "name": "Heart Disease", "dataset": "UCI Heart Disease — Cleveland", "source_url": "https://archive.ics.uci.edu/dataset/45/heart+disease", "doi": "https://doi.org/10.24432/C52P4X", "negative_class": "heart_disease_absent", "positive_class": "heart_disease_present", "negative_label": "Disease absent", "positive_label": "Disease present", "description": "Cleveland clinical measurements, exercise-test results, and original categorical codes. Target 0 means absent; original targets 1–4 are grouped as present.", "citation": "Janosi, Steinbrunn, Pfisterer & Detrano (1988). Heart Disease. UCI."},
    "diabetes": {"id": "diabetes", "name": "Diabetes", "dataset": "UCI Early Stage Diabetes Risk Prediction", "source_url": "https://archive.ics.uci.edu/dataset/529/early+stage+diabetes+risk+prediction+dataset", "doi": "https://doi.org/10.24432/C5VG8H", "negative_class": "diabetes_negative", "positive_class": "diabetes_positive", "negative_label": "Diabetes negative", "positive_label": "Diabetes positive", "description": "Age, sex, and questionnaire signs/symptoms from Sylhet Diabetes Hospital, Bangladesh. The model predicts the dataset's recorded diabetes class, not future incidence.", "citation": "Islam, Ferdousi, Rahman & Bushra (2020). Early Stage Diabetes Risk Prediction. UCI."},
}


def feature_id(name):
    return str(name).lower().replace(" ", "_")


def feature(key, label, group, *, unit="", options=None, nullable=False, lower=0, upper=1e8):
    return {"id": key, "label": label, "group": group, "unit": unit,
            "kind": "categorical" if options else "number", "nullable": nullable,
            "allowed_min": lower, "allowed_max": upper,
            "options": [{"value": value, "label": text} for value, text in (options or [])]}


YES_NO = [(0, "No"), (1, "Yes")]
SEX = [(0, "Female"), (1, "Male")]


@dataclass
class Dataset:
    id: str
    x: np.ndarray
    y: np.ndarray
    features: list[dict]
    row_ids: list[int]
    raw_count: int
    duplicate_rows_removed: int
    conflicting_rows_removed: int
    missing_values: int
    source_sha256: str

    def split(self):
        return train_test_split(np.arange(len(self.y)), test_size=.2, stratify=self.y, random_state=SEED)


def _source(disease, filename):
    path = ROOT / "data" / disease / filename
    if not path.exists():
        raise FileNotFoundError("UCI files missing. Run python download_datasets.py before training.")
    manifest = json.loads((ROOT / "data/sources.json").read_text())
    if hashlib.sha256(path.read_bytes()).hexdigest() != manifest[disease]["sha256"]:
        raise ValueError(f"Source fingerprint mismatch: {disease}")
    return path


def load_dataset(disease="breast_cancer"):
    if disease not in DEFINITIONS:
        raise ValueError("Unknown disease")
    if disease == "breast_cancer":
        source = load_breast_cancer()
        x, y = source.data.copy(), (source.target == 0).astype(int)
        features = [feature(feature_id(n), str(n).title(), "Mean" if n.startswith("mean ") else "Standard error" if n.endswith(" error") else "Worst") for n in source.feature_names]
        digest = hashlib.sha256(x.tobytes() + y.tobytes()).hexdigest()
    elif disease == "heart_disease":
        path = _source(disease, "processed.cleveland.data")
        rows = list(csv.reader(path.read_text().splitlines()))
        matrix = np.array([[np.nan if value == "?" else float(value) for value in row] for row in rows])
        x, y = matrix[:, :13], (matrix[:, 13] > 0).astype(int)
        features = [
            feature("age", "Age", "Demographics", unit="years", lower=1, upper=120),
            feature("sex", "Sex (source coding)", "Demographics", options=SEX),
            feature("cp", "Chest pain type", "Clinical", options=[(1,"Typical angina"),(2,"Atypical angina"),(3,"Non-anginal pain"),(4,"Asymptomatic")]),
            feature("trestbps", "Resting blood pressure", "Clinical", unit="mm Hg", lower=1, upper=300),
            feature("chol", "Serum cholesterol", "Clinical", unit="mg/dL", lower=1, upper=1000),
            feature("fbs", "Fasting blood sugar above 120 mg/dL", "Clinical", options=YES_NO),
            feature("restecg", "Resting ECG", "Clinical", options=[(0,"Normal"),(1,"ST–T abnormality"),(2,"Left ventricular hypertrophy")]),
            feature("thalach", "Maximum heart rate", "Exercise", unit="bpm", lower=1, upper=260),
            feature("exang", "Exercise-induced angina", "Exercise", options=YES_NO),
            feature("oldpeak", "Exercise ST depression", "Exercise", upper=20),
            feature("slope", "Peak exercise ST slope", "Exercise", options=[(1,"Upsloping"),(2,"Flat"),(3,"Downsloping")]),
            feature("ca", "Major vessels colored by fluoroscopy", "Clinical", options=[(0,"0"),(1,"1"),(2,"2"),(3,"3")], nullable=True),
            feature("thal", "Thallium stress-test result", "Clinical", options=[(3,"Normal"),(6,"Fixed defect"),(7,"Reversible defect")], nullable=True),
        ]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    else:
        path = _source(disease, "diabetes_data_upload.csv")
        rows = list(csv.DictReader(path.read_text().splitlines()))
        keys = list(rows[0])[:-1]
        x = np.array([[float(row[key]) if key == "Age" else (1.0 if row[key] in ("Yes", "Male") else 0.0) for key in keys] for row in rows])
        y = np.array([int(row["class"] == "Positive") for row in rows])
        features = [feature("age", "Age", "Demographics", unit="years", lower=1, upper=120), feature("gender", "Sex (source coding)", "Demographics", options=SEX)]
        features += [feature(feature_id(key), key.replace("_", " ").title(), "Symptoms", options=YES_NO) for key in keys[2:]]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    # Identical measurements must never leak across training, CV, or held-out evaluation.
    groups = {}
    for i, row in enumerate(x):
        signature = tuple(None if np.isnan(value) else float(value) for value in row)
        groups.setdefault(signature, []).append(i)
    retained, conflicting = [], 0
    for indices in groups.values():
        if len(set(y[indices])) > 1:
            conflicting += len(indices)
        else:
            retained.append(indices[0])
    retained.sort()
    raw_count = len(y)
    duplicates = raw_count - conflicting - len(retained)
    return Dataset(disease, x[retained], y[retained], features, retained, raw_count, duplicates, conflicting, int(np.isnan(x).sum()), digest)
