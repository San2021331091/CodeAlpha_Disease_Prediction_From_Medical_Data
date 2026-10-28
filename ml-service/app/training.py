"""Twelve classifiers across three independent UCI datasets; no test-set model selection."""
from pathlib import Path
import json
import tempfile
import joblib
import numpy as np
import sklearn
import xgboost
from xgboost import XGBClassifier
from sklearn.calibration import CalibratedClassifierCV
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score, confusion_matrix
from sklearn.model_selection import StratifiedKFold, cross_validate
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.svm import SVC
from .datasets import ROOT, SEED, NOTICE, DEFINITIONS, load_dataset, feature_id

ARTIFACTS = ROOT / "saved_models"


def preprocessing(dataset):
    numeric = [i for i, f in enumerate(dataset.features) if f["kind"] == "number"]
    categorical = [i for i, f in enumerate(dataset.features) if f["kind"] == "categorical"]
    return ColumnTransformer([
        ("numeric", make_pipeline(SimpleImputer(strategy="median"), StandardScaler()), numeric),
        ("categorical", make_pipeline(SimpleImputer(strategy="most_frequent"), OneHotEncoder(handle_unknown="ignore", sparse_output=False)), categorical),
    ])


def train_disease(disease):
    dataset = load_dataset(disease)
    train, test = dataset.split()
    x_train, x_test = dataset.x[train], dataset.x[test]
    y_train, y_test = dataset.y[train], dataset.y[test]
    candidates = {
        "logistic_regression": make_pipeline(preprocessing(dataset), LogisticRegression(max_iter=3000, random_state=SEED)),
        "random_forest": make_pipeline(preprocessing(dataset), RandomForestClassifier(n_estimators=250, min_samples_leaf=2, class_weight="balanced", random_state=SEED, n_jobs=1)),
        "svm": CalibratedClassifierCV(make_pipeline(preprocessing(dataset), SVC(kernel="rbf", C=1.0, random_state=SEED)), cv=3),
        "xgboost": make_pipeline(preprocessing(dataset), XGBClassifier(n_estimators=200, max_depth=3, learning_rate=0.05, objective="binary:logistic", eval_metric="logloss", tree_method="hist", random_state=SEED, n_jobs=1)),
    }
    names = {"logistic_regression": "Logistic Regression", "random_forest": "Random Forest", "svm": "Support Vector Machine", "xgboost": "XGBoost"}
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
    selection = {}
    for key, model in candidates.items():
        scores = cross_validate(model, x_train, y_train, cv=cv, scoring={"f1": "f1", "roc_auc": "roc_auc"})
        selection[key] = {"cv_f1": float(scores["test_f1"].mean()), "cv_f1_std": float(scores["test_f1"].std()), "cv_roc_auc": float(scores["test_roc_auc"].mean())}
    best = max(selection, key=lambda key: (selection[key]["cv_f1"], selection[key]["cv_roc_auc"]))
    models = []
    for key, model in candidates.items():
        model.fit(x_train, y_train)
        prediction = model.predict(x_test)
        probabilities = model.predict_proba(x_test)[:, list(model.classes_).index(1)]
        influence = permutation_importance(model, x_train, y_train, scoring="roc_auc", n_repeats=5, random_state=SEED)
        top = np.argsort(influence.importances_mean)[::-1][:8]
        models.append({"id": key, "name": names[key], **selection[key],
            "accuracy": float(accuracy_score(y_test, prediction)), "precision": float(precision_score(y_test, prediction, zero_division=0)),
            "recall": float(recall_score(y_test, prediction, zero_division=0)), "f1": float(f1_score(y_test, prediction, zero_division=0)),
            "roc_auc": float(roc_auc_score(y_test, probabilities)), "confusion_matrix": confusion_matrix(y_test, prediction, labels=[0, 1]).tolist(),
            "feature_importance": [{"feature": dataset.features[i]["id"], "label": dataset.features[i]["label"], "importance": max(0.0, float(influence.importances_mean[i]))} for i in top]})
    features = [{**f, "min": float(np.nanmin(x_train[:, i])), "max": float(np.nanmax(x_train[:, i])), "default": float(np.nanmedian(x_train[:, i]))} for i, f in enumerate(dataset.features)]
    definition = DEFINITIONS[disease]
    report = {**definition, "disease": disease, "license": "CC BY 4.0", "source_sha256": dataset.source_sha256,
        "raw_samples": dataset.raw_count, "total_samples": len(dataset.y), "duplicate_rows_removed": dataset.duplicate_rows_removed,
        "conflicting_rows_removed": dataset.conflicting_rows_removed, "source_missing_values": dataset.missing_values,
        "train_samples": len(train), "test_samples": len(test), "feature_count": len(features), "seed": SEED,
        "class_counts": {definition["negative_class"]: int((dataset.y == 0).sum()), definition["positive_class"]: int((dataset.y == 1).sum())},
        "selection": "Highest mean positive-class F1 in 5-fold stratified cross-validation on training data only; ROC-AUC tie-breaker. Stratified 20% held-out test split for reporting. Duplicate feature rows removed before splitting; conflicting duplicate groups excluded.",
        "preprocessing": "Numeric median imputation and standardization; categorical most-frequent imputation and one-hot encoding. Every preprocessing step is fitted within training folds, including SVM calibration folds.",
        "confusion_matrix_labels": [definition["negative_label"], definition["positive_label"]], "confusion_matrix_axes": "rows=actual, columns=predicted",
        "selected_model": best, "sklearn_version": sklearn.__version__, "xgboost_version": xgboost.__version__, "notice": NOTICE, "models": models,
        "train_row_ids": [dataset.row_ids[i] for i in train], "test_row_ids": [dataset.row_ids[i] for i in test]}
    samples = []
    for label, name in [(0, definition["negative_label"]), (1, definition["positive_label"])]:
        for n, index in enumerate([i for i in test if dataset.y[i] == label][:2], start=1):
            samples.append({"id": f"{disease}-{dataset.row_ids[index]}", "name": f"{name} example {n}", "expected_label": definition["positive_class"] if label else definition["negative_class"], "expected_display": name, "partition": "held-out test", "features": {f["id"]: None if np.isnan(value) else float(value) for f, value in zip(features, dataset.x[index], strict=True)}})
    return {"models": candidates, "report": report, "features": features, "samples": samples}


def train_models(output_dir=ARTIFACTS):
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    diseases = {}
    for disease in DEFINITIONS:
        print(f"Training {disease}...", flush=True)
        diseases[disease] = train_disease(disease)
    bundle = {"format_version": 2, "diseases": diseases}
    with tempfile.NamedTemporaryFile(dir=output_dir, suffix=".tmp", delete=False) as handle:
        temporary = Path(handle.name)
    try:
        joblib.dump(bundle, temporary)
        temporary.replace(output_dir / "bundle.joblib")
    finally:
        temporary.unlink(missing_ok=True)
    reports = {key: value["report"] for key, value in diseases.items()}
    (output_dir / "metrics.json").write_text(json.dumps(reports["breast_cancer"], indent=2), encoding="utf-8")
    (output_dir / "all_metrics.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
    return reports
