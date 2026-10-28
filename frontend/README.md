# CellScope Android

Flutter Android frontend for CodeAlpha Task 4. See the [project README](../README.md) for the dataset, model evaluation, backend setup, device connection, and build instructions.

## Screenshots

Direct links to application UI captures in [`../screenshots/`](../screenshots/):
- [**Overview Screen**](../screenshots/overview.png) — Disease selection and models
- [**Measurement Form / Analyze**](../screenshots/analyze.png) — Parameter form & 4 UCI sample loaders
- [**Inference Result**](../screenshots/result.png) — Prediction, probability breakdown & warnings
- [**Model Lab**](../screenshots/model-lab.png) — Confusion matrices and benchmark metrics
- [**Audit History**](../screenshots/history.png) — Server-side persistent history

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

The API address loads from `.env`; copy `.env.example` to `.env` on a fresh clone. A build's `--dart-define=API_BASE_URL=...` overrides that URL. Rebuild after changing `.env`. The app does not expose server configuration controls.

The frontend uses Riverpod with MVVM: `models/` defines typed data, `repositories/` handles API access, `viewmodels/` owns state and validation, and `views/` renders the dark emerald UI. `core/config/` loads public configuration and `core/network/` contains the HTTP client. ViewModels are tested separately from widgets. Responsive widget tests scroll all screens at phone, landscape, enlarged-text, and tablet sizes.
