import '../api.dart';
import '../models/workspace.dart';

class WorkspaceRepository {
  final CellScopeApi api;
  const WorkspaceRepository(this.api);

  Future<WorkspaceData> loadWorkspace([String disease = 'breast_cancer']) async {
    final query = disease == 'breast_cancer' ? '' : '?disease=${Uri.encodeQueryComponent(disease)}';
    final responses = await Future.wait([
      api.request('/api/schema$query'),
      api.request('/api/metrics$query'),
      api.request('/api/samples$query'),
      api.request('/api/diseases'),
    ]);
    return WorkspaceData(
      schema: responses[0],
      metrics: responses[1],
      samples: responses[2]['samples'] as List,
      diseases: responses[3]['diseases'] as List,
    );
  }

  Future<PredictionRecord> predict(
    String model,
    Map<String, String> measurements,
    {String disease = 'breast_cancer'}
  ) async {
    final response = await api.request(
      '/api/predict',
      method: 'POST',
      body: {
        'model': model,
        'disease': disease,
        'features': {
          for (final e in measurements.entries) e.key: e.value.trim().isEmpty ? null : double.parse(e.value),
        },
      },
    );
    return PredictionRecord.fromJson(response);
  }

  Future<List<PredictionRecord>> history() async {
    final response = await api.request('/api/history?limit=200');
    return List.unmodifiable(
      (response['records'] as List).map(
        (r) => PredictionRecord.fromJson(Json.from(r as Map)),
      ),
    );
  }

  Future<void> clearHistory() async {
    await api.request('/api/history', method: 'DELETE');
  }
}
