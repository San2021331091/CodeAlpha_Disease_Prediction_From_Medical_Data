"""Download only the named public data files from their official UCI archives."""
import hashlib
import io
import json
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile

DATA = Path(__file__).resolve().parent / "data"
SOURCES = {
    "heart_disease": ("https://archive.ics.uci.edu/static/public/45/heart+disease.zip", "processed.cleveland.data"),
    "diabetes": ("https://archive.ics.uci.edu/static/public/529/early+stage+diabetes+risk+prediction+dataset.zip", "diabetes_data_upload.csv"),
}


def download():
    manifest_path = DATA / "sources.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for disease, (url, filename) in SOURCES.items():
        target = DATA / disease / filename
        expected = manifest.get(disease, {}).get("sha256")
        if not target.exists():
            with urlopen(Request(url, headers={"User-Agent": "CellScope-CodeAlpha/1.2"}), timeout=60) as response:
                archive = response.read(10 * 1024 * 1024)
            with ZipFile(io.BytesIO(archive)) as zip_file:
                entries = [n for n in zip_file.namelist() if n.split("/")[-1] == filename]
                if len(entries) != 1:
                    raise ValueError(f"Expected one {filename} in the official archive")
                raw = zip_file.read(entries[0])
            if expected and hashlib.sha256(raw).hexdigest() != expected:
                raise ValueError(f"UCI source changed for {disease}; review the new data before updating its fingerprint")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if expected and digest != expected:
            raise ValueError(f"Source integrity check failed: {target}")
        manifest[disease] = {"archive_url": url, "file": str(target.relative_to(DATA)).replace("\\", "/"), "sha256": digest, "license": "CC BY 4.0"}
        print(f"Verified {disease}: {target.stat().st_size} bytes, SHA256 {digest}")
    DATA.mkdir(exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    download()
