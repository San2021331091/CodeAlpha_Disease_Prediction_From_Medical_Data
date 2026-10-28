typedef Json = Map<String, dynamic>;

class FeatureDefinition {
  final String id;
  final String label;
  final String group;
  final double min;
  final double max;
  final String kind;
  final bool nullable;
  final String unit;
  final List<Json> options;
  final double allowedMin;
  final double allowedMax;
  FeatureDefinition.fromJson(Json json)
    : id = json['id'] as String,
      label = json['label'] as String,
      group = json['group'] as String,
      min = (json['min'] as num).toDouble(),
      max = (json['max'] as num).toDouble(),
      kind = json['kind'] as String? ?? 'number',
      nullable = json['nullable'] as bool? ?? false,
      unit = json['unit'] as String? ?? '',
      options = List.unmodifiable(
        (json['options'] as List? ?? []).map((o) => Json.from(o as Map)),
      ),
      allowedMin = (json['allowed_min'] as num? ?? 0).toDouble(),
      allowedMax = (json['allowed_max'] as num? ?? 1e8).toDouble();
  Json toJson() => {
    'id': id,
    'label': label,
    'group': group,
    'min': min,
    'max': max,
    'kind': kind,
    'nullable': nullable,
    'unit': unit,
    'options': options,
    'allowed_min': allowedMin,
    'allowed_max': allowedMax,
  };
}

class BenchmarkSample {
  final String id;
  final String name;
  final String expectedLabel;
  final Map<String, num?> features;
  final String expectedDisplay;
  BenchmarkSample.fromJson(Json json)
    : id = json['id'] as String,
      name = json['name'] as String,
      expectedLabel = json['expected_label'] as String,
      expectedDisplay =
          json['expected_display'] as String? ??
          json['expected_label'] as String,
      features = Map<String, num?>.unmodifiable(
        Map<String, num?>.from(json['features'] as Map),
      );
  Json toJson() => {
    'id': id,
    'name': name,
    'expected_label': expectedLabel,
    'expected_display': expectedDisplay,
    'features': features,
  };
}

class PredictionResult {
  final Json _json;
  PredictionResult.fromJson(Json json) : _json = Map.unmodifiable(json) {
    if (json['label'] is! String ||
        (json['positive_probability'] ?? json['malignant_probability'])
            is! num) {
      throw const FormatException('Invalid prediction response');
    }
  }
  String get label => _json['label'] as String;
  Json toJson() => _json;
}

class PredictionRecord {
  final String id;
  final DateTime createdAt;
  final PredictionResult result;
  PredictionRecord.fromJson(Json json)
    : id = json['id'] as String,
      createdAt = DateTime.parse(json['created_at'] as String),
      result = PredictionResult.fromJson(Json.from(json['result'] as Map));
  Json toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'result': result.toJson(),
  };
}

class WorkspaceData {
  final String disease;
  final String diseaseName;
  final String description;
  final String positiveLabel;
  final String negativeLabel;
  final List<Json> diseases;
  final List<FeatureDefinition> features;
  final List<Json> classifiers;
  final Json metrics;
  final List<BenchmarkSample> samples;
  WorkspaceData({
    required Json schema,
    required this.metrics,
    required List<dynamic> samples,
    List<dynamic> diseases = const [],
  }) : disease = schema['disease'] as String? ?? 'breast_cancer',
       diseaseName = schema['disease_name'] as String? ?? 'Breast Cancer',
       description =
           schema['description'] as String? ??
           'Digitized cell-nucleus measurements from the UCI public dataset.',
       positiveLabel = schema['positive_label'] as String? ?? 'Malignant',
       negativeLabel = schema['negative_label'] as String? ?? 'Benign',
       diseases = List.unmodifiable(diseases.map((d) => Json.from(d as Map))),
       features = List.unmodifiable(
         (schema['features'] as List).map(
           (f) => FeatureDefinition.fromJson(Json.from(f as Map)),
         ),
       ),
       classifiers = List.unmodifiable(
         (schema['models'] as List).map((m) => Json.from(m as Map)),
       ),
       samples = List.unmodifiable(
         samples.map((s) => BenchmarkSample.fromJson(Json.from(s as Map))),
       );
  Json get schema => {
    'disease': disease,
    'disease_name': diseaseName,
    'description': description,
    'positive_label': positiveLabel,
    'negative_label': negativeLabel,
    'features': features.map((f) => f.toJson()).toList(),
    'models': classifiers,
  };
}
