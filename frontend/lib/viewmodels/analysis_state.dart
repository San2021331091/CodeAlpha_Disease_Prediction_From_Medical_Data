import '../models/workspace.dart';

class AnalysisState {
  final String disease;
  final WorkspaceData? data;
  final bool loading;
  final bool predicting;
  final bool historyLoading;
  final bool clearing;
  final String? error;
  final String? historyError;
  final PredictionRecord? prediction;
  final List<PredictionRecord> records;
  final String model;
  final BenchmarkSample? sample;
  final Map<String, String> measurements;
  final String featureGroup;

  const AnalysisState({
    this.disease = 'breast_cancer',
    this.data,
    this.loading = true,
    this.predicting = false,
    this.historyLoading = false,
    this.clearing = false,
    this.error,
    this.historyError,
    this.prediction,
    this.records = const [],
    this.model = 'auto',
    this.sample,
    this.measurements = const {},
    this.featureGroup = 'Mean',
  });

  AnalysisState copyWith({
    String? disease,
    WorkspaceData? data,
    bool? loading,
    bool? predicting,
    bool? historyLoading,
    bool? clearing,
    String? error,
    String? historyError,
    PredictionRecord? prediction,
    List<PredictionRecord>? records,
    String? model,
    BenchmarkSample? sample,
    Map<String, String>? measurements,
    String? featureGroup,
    bool clearData = false,
    bool clearError = false,
    bool clearHistoryError = false,
    bool clearPrediction = false,
    bool clearSample = false,
  }) => AnalysisState(
    disease: disease ?? this.disease,
    data: clearData ? null : data ?? this.data,
    loading: loading ?? this.loading,
    predicting: predicting ?? this.predicting,
    historyLoading: historyLoading ?? this.historyLoading,
    clearing: clearing ?? this.clearing,
    error: clearError ? null : error ?? this.error,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    prediction: clearPrediction ? null : prediction ?? this.prediction,
    records: records ?? this.records,
    model: model ?? this.model,
    sample: clearSample ? null : sample ?? this.sample,
    measurements: measurements ?? this.measurements,
    featureGroup: featureGroup ?? this.featureGroup,
  );
}
