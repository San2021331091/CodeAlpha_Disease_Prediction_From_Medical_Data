import 'package:cellscope/viewmodels/providers.dart';
import 'package:cellscope/viewmodels/analysis_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_api.dart';

Future<void> waitForLoad(ProviderContainer container) async {
  container.read(analysisViewModelProvider);
  for (var attempt = 0; attempt < 50; attempt++) {
    await Future<void>.delayed(Duration.zero);
    if (!container.read(analysisViewModelProvider).loading) return;
  }
  fail('ViewModel did not finish loading');
}

void main() {
  late FakeApi api;
  late ProviderContainer container;
  setUp(() {
    api = FakeApi();
    container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(api)],
    );
  });
  tearDown(() {
    container.dispose();
    api.close();
  });

  test(
    'ViewModel validates hidden groups before calling the repository',
    () async {
      await waitForLoad(container);
      final vm = container.read(analysisViewModelProvider.notifier);
      vm.fillSample(
        container.read(analysisViewModelProvider).data!.samples.first,
      );
      vm.updateMeasurement('Worst_9', 'NaN');
      expect(await vm.predict(), isNull);
      final state = container.read(analysisViewModelProvider);
      expect(state.featureGroup, 'Worst');
      expect(state.error, contains('Worst measurement 9'));
      expect(state.sample, isNull);
      expect(api.predictions, 0);
    },
  );

  test(
    'ViewModel owns prediction state, exact sample values, and reset',
    () async {
      await waitForLoad(container);
      final vm = container.read(analysisViewModelProvider.notifier);
      vm.fillSample(
        container.read(analysisViewModelProvider).data!.samples.first,
      );
      vm.selectModel('random_forest');
      final prediction = await vm.predict();
      expect(prediction!.result.label, 'benign');
      expect(
        container.read(analysisViewModelProvider).prediction,
        same(prediction),
      );
      expect(container.read(analysisViewModelProvider).predicting, false);
      expect(container.read(analysisViewModelProvider).model, 'random_forest');
      vm.clearMeasurements();
      expect(container.read(analysisViewModelProvider).prediction, isNull);
      expect(
        container.read(analysisViewModelProvider).measurements.values,
        everyElement(''),
      );
    },
  );

  test(
    'ViewModel recovers from history errors and clears saved results',
    () async {
      await waitForLoad(container);
      final vm = container.read(analysisViewModelProvider.notifier);
      api.unavailable = true;
      await vm.loadHistory();
      expect(container.read(analysisViewModelProvider).historyError, isNotNull);
      expect(container.read(analysisViewModelProvider).historyLoading, false);
      api.unavailable = false;
      await vm.loadHistory();
      expect(container.read(analysisViewModelProvider).records, hasLength(1));
      expect(container.read(analysisViewModelProvider).historyError, isNull);
      await vm.clearHistory();
      expect(container.read(analysisViewModelProvider).records, isEmpty);
      expect(api.deleted, true);
    },
  );

  test('XGBoost is available and sent unchanged to prediction API', () async {
    await waitForLoad(container);
    final data = container.read(analysisViewModelProvider).data!;
    expect(data.classifiers.map((m) => m['id']), contains('xgboost'));
    final vm = container.read(analysisViewModelProvider.notifier);
    vm.fillSample(data.samples.first);
    vm.selectModel('xgboost');
    expect(await vm.predict(), isNotNull);
    expect(api.lastPrediction!['model'], 'xgboost');
    expect(api.lastPrediction!['disease'], 'breast_cancer');
  });

  test('measurement validation rejects invalid and non-finite values', () {
    for (final value in ['', '-1', 'NaN', 'Infinity', '1e9', 'text']) {
      expect(AnalysisViewModel.validateMeasurement(value), isNotNull);
    }
    expect(AnalysisViewModel.validateMeasurement('1.23456789'), isNull);
  });
}
