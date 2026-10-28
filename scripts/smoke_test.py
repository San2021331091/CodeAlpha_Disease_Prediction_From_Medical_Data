"""Launch both real services with isolated storage, exercise the API, then stop them."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def request(base, path, payload=None, method="GET"):
    data = None if payload is None else json.dumps(payload).encode()
    req = Request(base + path, data=data, method=method, headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=15) as response:
        return json.load(response)


def wait_ready(base, process):
    for _ in range(120):
        if process.poll() is not None:
            raise RuntimeError("Service exited before becoming ready")
        try:
            if request(base, "/health")["status"] == "ok":
                return
        except (URLError, TimeoutError):
            time.sleep(.25)
    raise RuntimeError("Service startup timed out")


def stop_process(process):
    if process.poll() is not None:
        return
    if os.name == "nt":
        # Windows venv python.exe can spawn the base interpreter; stop its tree.
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    else:
        process.terminate()
    process.wait(timeout=10)


def main():
    ml_port, gin_port = free_port(), free_port()
    while ml_port == gin_port:
        gin_port = free_port()
    binary = ROOT / "backend-gateway" / ("gateway.exe" if os.name == "nt" else "gateway")
    if not binary.exists():
        subprocess.run(["go", "build", "-o", str(binary), "."], cwd=ROOT / "backend-gateway", check=True)
    processes = []
    try:
        with tempfile.TemporaryDirectory(prefix="cellscope-test-") as temp:
            env = {**os.environ, "ML_SERVICE_URL": f"http://127.0.0.1:{ml_port}", "GATEWAY_ADDR": f"127.0.0.1:{gin_port}", "HISTORY_PATH": str(Path(temp) / "history.json")}
            with (Path(temp) / "services.log").open("w+") as log:
                flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
                ml = subprocess.Popen([sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(ml_port)], cwd=ROOT / "ml-service", env=env, stdout=log, stderr=log, creationflags=flags)
                processes.append(ml)
                gin = subprocess.Popen([str(binary)], cwd=ROOT / "backend-gateway", env=env, stdout=log, stderr=log, creationflags=flags)
                processes.append(gin)
                try:
                    base = f"http://127.0.0.1:{gin_port}"
                    wait_ready(f"http://127.0.0.1:{ml_port}", ml)
                    wait_ready(base, gin)
                    catalog = request(base, "/api/diseases")["diseases"]
                    assert {d["id"] for d in catalog} == {"breast_cancer", "heart_disease", "diabetes"}
                    count = 0
                    for disease in catalog:
                        disease_id = disease["id"]
                        report = request(base, f"/api/metrics?disease={disease_id}")
                        assert {m["id"] for m in report["models"]} == {"logistic_regression", "random_forest", "svm", "xgboost"}
                        samples = request(base, f"/api/samples?disease={disease_id}")["samples"]
                        for model in ["auto", "logistic_regression", "random_forest", "svm", "xgboost"]:
                            for sample in samples:
                                result = request(base, "/api/predict", {"disease": disease_id, "model": model, "features": sample["features"]}, "POST")
                                assert result["id"] and result["created_at"]
                                prediction = result["result"]
                                assert prediction["disease"] == disease_id
                                assert prediction["label"] in [report["negative_class"], report["positive_class"]]
                                assert prediction["model"] == (report["selected_model"] if model == "auto" else model)
                                count += 1
                    assert count == 60
                    assert request(base, "/api/history")["total"] == count
                    # Real process restart verifies durable history.
                    stop_process(gin)
                    gin = subprocess.Popen([str(binary)], cwd=ROOT / "backend-gateway", env=env, stdout=log, stderr=log, creationflags=flags)
                    processes.append(gin)
                    wait_ready(base, gin)
                    assert request(base, "/api/history")["total"] == count
                    try:
                        request(base, "/api/predict", {"features": {}}, "POST")
                        raise AssertionError("invalid features accepted")
                    except HTTPError as error:
                        assert error.code == 422
                    assert request(base, "/api/history")["total"] == count
                    assert request(base, "/api/history", method="DELETE")["deleted"]
                    assert request(base, "/api/history")["total"] == 0
                    print("PASS: Gin -> FastAPI, 60 predictions across three diseases and four classifiers, validation, history persistence across restart, and deletion.")
                except Exception:
                    log.flush()
                    log.seek(0)
                    print(log.read())
                    raise
                finally:
                    for process in reversed(processes):
                        stop_process(process)
    finally:
        for process in reversed(processes):
            stop_process(process)


if __name__ == "__main__":
    main()
