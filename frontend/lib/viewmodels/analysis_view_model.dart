import 'package:state_notifier/state_notifier.dart';
import '../models/workspace.dart';
import '../repositories/workspace_repository.dart';
import 'analysis_state.dart';

class AnalysisViewModel extends StateNotifier<AnalysisState> {
  final WorkspaceRepository _repository;
  int _generation = 0;

  AnalysisViewModel(this._repository) : super(const AnalysisState()) {
    final generation = ++_generation;
    Future.microtask(() {
      if (mounted && generation == _generation) load();
    });
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      loading: true,
      clearData: true,
      clearError: true,
      clearPrediction: true,
      clearSample: true,
      records: const [],
      measurements: const {},
    );
    try {
      final data = await _repository.loadWorkspace(state.disease);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        data: data,
        loading: false,
        featureGroup: data.features.first.group,
        measurements: Map.unmodifiable({
          for (final f in data.features) f.id: '',
        }),
      );
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(loading: false, error: error.toString());
      }
    }
  }

  void fillSample(BenchmarkSample sample) {
    state = state.copyWith(
      sample: sample,
      measurements: Map.unmodifiable({
        for (final e in sample.features.entries)
          e.key: e.value?.toString() ?? '',
      }),
      clearPrediction: true,
      clearError: true,
    );
  }

  void updateMeasurement(String id, String value) {
    state = state.copyWith(
      measurements: Map.unmodifiable({...state.measurements, id: value}),
      clearSample: true,
      clearPrediction: true,
      clearError: true,
    );
  }

  void selectModel(String model) =>
      state = state.copyWith(model: model, clearPrediction: true);
  void selectGroup(String group) => state = state.copyWith(featureGroup: group);
  Future<void> selectDisease(String disease) async {
    if (state.loading || state.predicting || disease == state.disease) return;
    state = AnalysisState(disease: disease);
    await load();
  }

  void clearMeasurements() => state = state.copyWith(
    measurements: Map.unmodifiable({
      for (final id in state.measurements.keys) id: '',
    }),
    clearSample: true,
    clearPrediction: true,
    clearError: true,
  );

  static String? validateMeasurement(String? text) {
    final value = double.tryParse(text ?? '');
    return value == null || !value.isFinite || value < 0 || value > 1e8
        ? 'Enter a number from 0 to 100000000'
        : null;
  }

  String? validateFeature(FeatureDefinition feature, String? text) {
    if ((text ?? '').trim().isEmpty && feature.nullable) return null;
    final error = validateMeasurement(text);
    if (error != null) return error;
    final value = double.parse(text!);
    if (value < feature.allowedMin || value > feature.allowedMax) {
      return 'Enter ${feature.allowedMin} to ${feature.allowedMax}';
    }
    if (feature.options.isNotEmpty &&
        !feature.options.any((o) => o['value'] == value)) {
      return 'Choose one of the listed values';
    }
    return null;
  }

  Future<PredictionRecord?> predict() async {
    if (state.predicting || state.data == null) return null;
    for (final feature in state.data!.features) {
      if (validateFeature(feature, state.measurements[feature.id]) != null) {
        state = state.copyWith(
          featureGroup: feature.group,
          error:
              'Complete all ${state.data!.features.length} fields. ${feature.label} needs a valid value.',
        );
        return null;
      }
    }
    final generation = _generation;
    state = state.copyWith(
      predicting: true,
      clearError: true,
      clearPrediction: true,
    );
    try {
      final record = await _repository.predict(
        state.model,
        state.measurements,
        disease: state.disease,
      );
      if (!mounted || generation != _generation) return null;
      state = state.copyWith(predicting: false, prediction: record);
      return record;
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(predicting: false, error: error.toString());
      }
      return null;
    }
  }

  Future<void> loadHistory() async {
    if (state.historyLoading || state.clearing) return;
    final generation = _generation;
    state = state.copyWith(historyLoading: true, clearHistoryError: true);
    try {
      final records = await _repository.history();
      if (mounted && generation == _generation) {
        state = state.copyWith(records: records, historyLoading: false);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(
          historyLoading: false,
          historyError: error.toString(),
        );
      }
    }
  }

  Future<void> clearHistory() async {
    if (state.clearing || state.historyLoading) return;
    final generation = _generation;
    state = state.copyWith(clearing: true, clearHistoryError: true);
    try {
      await _repository.clearHistory();
      if (mounted && generation == _generation) {
        state = state.copyWith(records: const [], clearing: false);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(clearing: false, historyError: error.toString());
      }
    }
  }
}
