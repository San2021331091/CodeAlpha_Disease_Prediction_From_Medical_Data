import 'dart:convert';
import 'dart:io';
import 'package:cellscope/api.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends CellScopeApi {
  FakeApi() : super(url: 'http://localhost:8000');

  bool unavailable = false;
  int predictions = 0;
  Map<String, dynamic>? lastPrediction;
  bool deleted = false;
  final Map<String, dynamic> metrics = jsonDecode(
    File('../ml-service/saved_models/metrics.json').readAsStringSync(),
  );

  List<Map<String, dynamic>> get fields => [
    for (final group in ['Mean', 'Standard error', 'Worst'])
      for (int i = 0; i < 10; i++)
        {
          'id': '${group}_$i',
          'label': '$group measurement $i',
          'group': group,
          'min': 0.01,
          'max': 10.0,
          'default': 1.0,
        },
  ];

  Map<String, dynamic> get result => {
    'label': 'benign',
    'model': 'logistic_regression',
    'model_name': 'Logistic Regression',
    'benign_probability': .9,
    'malignant_probability': .1,
    'warnings': <String>[],
    'explanation': 'Global importance, not an individual explanation.',
    'top_features': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (unavailable) throw ApiException('Test server unavailable');
    if (path == '/api/diseases') {
      return {'diseases': [
      {'id': 'breast_cancer', 'name': 'Breast Cancer'},
      {'id': 'heart_disease', 'name': 'Heart Disease'},
      {'id': 'diabetes', 'name': 'Diabetes'},
    ]};
    }
    switch (path) {
      case '/api/schema':
        return {'features': fields, 'models': metrics['models']};
      case '/api/metrics':
        return metrics;
      case '/api/samples':
        return {
          'samples': [
            {
              'id': 'wdbc-test',
              'name': 'Benign example 1',
              'expected_label': 'benign',
              'features': {for (final f in fields) f['id']: 1.23456789},
            },
          ],
        };
      case '/api/predict':
        predictions++;
        lastPrediction = body;
        expect((body!['features'] as Map).length, 30);
        expect((body['features'] as Map).values.first, 1.23456789);
        return {
          'id': 'record-1',
          'created_at': '2026-10-23T09:00:00Z',
          'result': result,
        };
      case '/api/history?limit=200':
        return {
          'records': deleted
              ? []
              : [
                  {
                    'id': 'record-1',
                    'created_at': '2026-10-23T09:00:00Z',
                    'result': result,
                  },
                ],
        };
      case '/api/history':
        expect(method, 'DELETE');
        deleted = true;
        return {'deleted': true};
      default:
        throw StateError('Unexpected request $path');
    }
  }
}
