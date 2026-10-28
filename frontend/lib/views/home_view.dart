import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../viewmodels/analysis_state.dart';
import '../viewmodels/analysis_view_model.dart';
import '../viewmodels/providers.dart';
import 'widgets/design_system.dart';
import 'widgets/responsive_layout.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});
  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int tab = 0;
  final controllers = <String, TextEditingController>{};
  final formKey = GlobalKey<FormState>();
  WorkspaceData? _controllerData;
  AnalysisViewModel get vm => ref.read(analysisViewModelProvider.notifier);
  AnalysisState get state => ref.read(analysisViewModelProvider);
  bool get loading => state.loading;
  bool get predicting => state.predicting;
  bool get historyLoading => state.historyLoading;
  bool get clearing => state.clearing;
  String? get error => state.error;
  String? get historyError => state.historyError;
  Map<String, dynamic>? get schema => state.data?.schema;
  Map<String, dynamic>? get metrics => state.data?.metrics;
  Map<String, dynamic>? get result => state.prediction?.result.toJson();
  List<dynamic> get samples =>
      state.data?.samples.map((s) => s.toJson()).toList() ?? [];
  List<dynamic> get records => state.records.map((r) => r.toJson()).toList();
  String get model => state.model;
  String get featureGroup => state.featureGroup;
  String? get sampleName => state.sample?.name;
  String? get expectedLabel => state.sample?.expectedDisplay;
  String get diseaseName => state.data?.diseaseName ?? 'Breast Cancer';
  String get positiveLabel => state.data?.positiveLabel ?? 'Malignant';
  String get negativeLabel => state.data?.negativeLabel ?? 'Benign';
  int get featureCount => state.data?.features.length ?? 30;
  List<String> get groups => state.data?.features.map((f) => f.group).toSet().toList() ?? ['Mean'];

  Widget diseaseSelector() => DropdownButtonFormField<String>(
    key: ValueKey('disease-${state.disease}'), initialValue: state.disease,
    isExpanded: true, dropdownColor: const Color(0xFF03261C),
    style: const TextStyle(fontSize: 14, color: textPrimary),
    decoration: const InputDecoration(labelText: 'Disease dataset', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
    items: const [
      DropdownMenuItem(value: 'breast_cancer', child: Text('Breast Cancer')),
      DropdownMenuItem(value: 'heart_disease', child: Text('Heart Disease')),
      DropdownMenuItem(value: 'diabetes', child: Text('Diabetes')),
    ],
    onChanged: loading || predicting || historyLoading || clearing ? null : (value) => vm.selectDisease(value!),
  );

  Widget measurementField(Map<String, dynamic> feature) {
    final definition = state.data!.features.firstWhere((f) => f.id == feature['id']);
    if (definition.kind == 'categorical') {
      return DropdownButtonFormField<String>(
        key: ValueKey('${state.disease}-${definition.id}-${state.measurements[definition.id]}'),
        initialValue: state.measurements[definition.id]?.isEmpty == false ? state.measurements[definition.id] : null,
        isExpanded: true, dropdownColor: const Color(0xFF03261C),
        decoration: InputDecoration(labelText: definition.label, helperText: definition.nullable ? 'Optional: missing values use training-only imputation' : 'Use the original dataset category', helperMaxLines: 2),
        items: [if (definition.nullable) const DropdownMenuItem(value: '', child: Text('Unknown / not measured')),
          for (final option in definition.options) DropdownMenuItem(value: (option['value'] as num).toDouble().toString(), child: Text(option['label'] as String, overflow: TextOverflow.ellipsis))],
        onChanged: predicting ? null : (value) => vm.updateMeasurement(definition.id, value ?? ''),
        validator: (value) => vm.validateFeature(definition, value),
      );
    }
    return TextFormField(key: ValueKey(definition.id), controller: controllers[definition.id], enabled: !predicting,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      validator: (value) => vm.validateFeature(definition, value),
      decoration: InputDecoration(labelText: definition.label,
        helperText: 'Training: ${number(definition.min)} – ${number(definition.max)} ${definition.unit}', helperMaxLines: 2),
      onChanged: (value) => vm.updateMeasurement(definition.id, value));
  }

  void syncControllers(AnalysisState state) {
    if (!identical(_controllerData, state.data)) {
      final retired = controllers.values.toList();
      // Let the previous form unmount before releasing its controllers.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in retired) {
          controller.dispose();
        }
      });
      controllers.clear();
      _controllerData = state.data;
      for (final f in state.data?.features ?? <FeatureDefinition>[]) {
        controllers[f.id] = TextEditingController(
          text: state.measurements[f.id] ?? '',
        );
      }
    }
    for (final e in controllers.entries) {
      final text = state.measurements[e.key] ?? '';
      if (e.value.text != text) e.value.text = text;
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() => vm.load();
  Future<void> loadHistory() => vm.loadHistory();
  String? validate(String? value) =>
      AnalysisViewModel.validateMeasurement(value);
  void fillSample(Map<String, dynamic> sample) =>
      vm.fillSample(BenchmarkSample.fromJson(sample));
  Future<void> predict() async {
    FocusScope.of(context).unfocus();
    final prediction = await vm.predict();
    if (!mounted) return;
    if (prediction != null) {
      showResult(prediction.result.toJson(), expected: expectedLabel);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => formKey.currentState?.validate(),
      );
    }
  }

  void showResult(Map<String, dynamic> value, {String? expected}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF021B14),
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        minChildSize: .4,
        builder: (context, scroll) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF042B1F), Color(0xFF021B14)],
            ),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            children: [
              Text('ANALYSIS COMPLETE', style: eyebrow()),
              const SizedBox(height: 14),
              Text(
                '${value['label_display'] ?? title(value['label'])} classification',
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x3310B981),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x4034D399)),
                  ),
                  child: Text(
                    '${value['disease_name'] ?? 'Breast Cancer'} · ${value['model_name']}',
                    style: const TextStyle(
                      color: emeraldBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model probability scores',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    probability(
                      value['negative_label'] ?? 'Benign',
                      ((value['negative_probability'] ?? value['benign_probability']) as num).toDouble(),
                      emeraldBright,
                    ),
                    const SizedBox(height: 20),
                    probability(
                      value['positive_label'] ?? 'Malignant',
                      ((value['positive_probability'] ?? value['malignant_probability']) as num).toDouble(),
                      const Color(0xFFFB7185),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Scores describe this model’s output, not a person’s clinical risk.',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (expected != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2610B981),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x6634D399)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: emeraldBright,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Public record label: ${title(expected)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const NoticeCard(),
              if ((value['warnings'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Outside training range', style: heading()),
                const SizedBox(height: 8),
                ...[
                  for (final warning in value['warnings'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• $warning',
                        style: const TextStyle(
                          color: Color(0xFFFDBA74),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 24),
              Text('What the model uses', style: heading()),
              const SizedBox(height: 8),
              Text(
                value['explanation'],
                style: const TextStyle(
                  color: emeraldLight,
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 16),
              ...[
                for (final f in (value['top_features'] as List).take(5))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x26000000),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1F34D399)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.scatter_plot_outlined,
                          color: emeraldBright,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title(f['label']),
                            style: const TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x3310B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (f['importance'] as num).toStringAsFixed(3),
                            style: const TextStyle(
                              color: emeraldBright,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(analysisViewModelProvider);
    syncControllers(current);
    return Scaffold(
      backgroundColor: emeraldDarkest,
      appBar: AppBar(
        bottom: PreferredSize(preferredSize: const Size.fromHeight(80), child: Padding(padding: const EdgeInsets.fromLTRB(22, 4, 22, 12), child: diseaseSelector())),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [emeraldMid, emeraldBright],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4034D399),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bubble_chart_rounded,
                color: Color(0xFF012015),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'cellscope',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5,
                      color: textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: emeraldBright,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Flexible(
                        child: Text(
                          'CLINICAL RESEARCH AI',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: emeraldMint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF021B14),
              Color(0xFF043324),
              Color(0xFF064733),
              Color(0xFF021B14),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: emeraldBright),
                )
              : schema == null || metrics == null
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xCC052B1E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x3334D399)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: emeraldMid.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cloud_off_outlined,
                                size: 48,
                                color: emeraldBright,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Let’s connect your workspace',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              error ?? 'Server unavailable',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: load,
                              child: const Text('Retry connection'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : IndexedStack(
                  index: tab,
                  children: [overview(), assessment(), modelLab(), history()],
                ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFA021A13),
          border: Border(
            top: BorderSide(
              color: emeraldBright.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF065F46),
          elevation: 0,
          onDestinationSelected: (index) {
            setState(() => tab = index);
            if (index == 3) loadHistory();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined, color: textMuted),
              selectedIcon: Icon(Icons.grid_view_rounded, color: emeraldBright),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.biotech_outlined, color: textMuted),
              selectedIcon: Icon(Icons.biotech_rounded, color: emeraldBright),
              label: 'Analyze',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined, color: textMuted),
              selectedIcon: Icon(Icons.insights_rounded, color: emeraldBright),
              label: 'Model lab',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded, color: textMuted),
              selectedIcon: Icon(
                Icons.history_toggle_off,
                color: emeraldBright,
              ),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }

  Widget overview() {
    final selected = (metrics!['models'] as List).firstWhere(
      (m) => m['id'] == metrics!['selected_model'],
    );
    return PageBody(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'RESEARCH WORKSPACE',
                style: eyebrow(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x2610B981),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x6634D399)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: emeraldBright),
                  SizedBox(width: 6),
                  Text(
                    'Connected',
                    style: TextStyle(
                      color: emeraldBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Small details.\nDeeper understanding.',
          style: TextStyle(
            fontSize: 34,
            height: 1.15,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Explore $diseaseName records with machine learning. Trace every result back to the data.',
          style: TextStyle(color: emeraldLight, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x40A7F3D0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40022C22),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.biotech_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Text(
                      'UCI BENCHMARK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Three datasets.\nOne research workspace.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$featureCount fields · ${state.data?.classifiers.length ?? 0} classifiers\n$diseaseName dataset',
                style: TextStyle(
                  color: Color(0xFFD1FAE5),
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF022C22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                ),
                onPressed: () => setState(() => tab = 1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'Start an analysis',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        AdaptivePair(
          first: stat(
            '${metrics!['total_samples']}',
            'Public records',
            Icons.dataset_outlined,
          ),
          second: stat(
            percent(selected['f1']),
            'Test F1 · positive class',
            Icons.auto_graph_rounded,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(child: Text('Try a benchmark record', style: heading())),
            const SizedBox(width: 8),
            const Icon(
              Icons.south_east_rounded,
              size: 18,
              color: emeraldBright,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Real held-out examples, ready to explore.',
          style: TextStyle(color: emeraldLight, fontSize: 13.5),
        ),
        const SizedBox(height: 14),
        ...[
          for (final sample in samples.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x3310B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      color: emeraldBright,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    sample['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${sample['id']} · $featureCount fields',
                      style: const TextStyle(color: emeraldMint, fontSize: 12),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_rounded,
                    color: emeraldBright,
                    size: 20,
                  ),
                  onTap: () {
                    fillSample(Map<String, dynamic>.from(sample));
                    setState(() => tab = 1);
                  },
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        const NoticeCard(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0x1F000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1A34D399)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.biotech, size: 14, color: emeraldBright),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'HEART DISEASE · DIABETES · BREAST CANCER / UCI RESEARCH SUITE',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: emeraldMint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Logistic Regression · Support Vector Machine · Random Forest • On-Premise Evaluation',
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 8.5,
                  color: textMuted.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget assessment() => PageBody(
    padding: const EdgeInsets.all(22),
    children: [
      Text('PATIENT DATA', style: eyebrow()),
      const SizedBox(height: 12),
      const Text(
        'Explore a record',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
          color: textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        state.data!.description,
        style: TextStyle(color: emeraldLight, height: 1.5, fontSize: 14),
      ),
      const SizedBox(height: 20),
      panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start with a public sample',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sample in samples)
                  ActionChip(
                    backgroundColor: const Color(0xFF043828),
                    side: const BorderSide(color: Color(0x5534D399)),
                    label: Text(
                      sample['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    avatar: const Icon(
                      Icons.science_outlined,
                      size: 17,
                      color: emeraldBright,
                    ),
                    onPressed: predicting
                        ? null
                        : () => fillSample(Map<String, dynamic>.from(sample)),
                  ),
              ],
            ),
            if (sampleName != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2610B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x6634D399)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 15,
                      color: emeraldBright,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$sampleName loaded · public label: $expectedLabel',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: emeraldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        initialValue: model,
        isExpanded: true,
        dropdownColor: const Color(0xFF03261C),
        style: const TextStyle(color: textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          labelText: 'Classifier',
          prefixIcon: Icon(Icons.psychology_outlined, color: emeraldBright),
        ),
        items: [
          const DropdownMenuItem(
            value: 'auto',
            child: Text(
              'Auto · cross-validation',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final m in schema!['models'])
            DropdownMenuItem(
              value: m['id'],
              child: Text(m['name'], overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: predicting ? null : (value) => vm.selectModel(value!),
      ),
      const SizedBox(height: 20),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final group in groups)
        ChoiceChip(label: Text(group), selected: featureGroup == group,
          onSelected: predicting ? null : (_) => vm.selectGroup(group))]),
      const SizedBox(height: 12),
      const Text(
        'Ranges describe training data, not clinical reference intervals. Categorical choices use the source dataset’s original meaning. Unknown optional values are imputed from training data.',
        style: TextStyle(color: emeraldMint, height: 1.5, fontSize: 12),
      ),
      const SizedBox(height: 16),
      Form(
        key: formKey,
        child: Column(
          children: [
            for (final f in (schema!['features'] as List).where(
              (f) => f['group'] == featureGroup,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: measurementField(Map<String, dynamic>.from(f)),
              ),
          ],
        ),
      ),
      if (error != null) ...[errorBox(error!), const SizedBox(height: 16)],
      FilledButton.icon(
        onPressed: predicting ? null : predict,
        icon: predicting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF012417),
                ),
              )
            : const Icon(Icons.auto_awesome_outlined, color: Color(0xFF012417)),
        label: Text(
          predicting ? 'Analyzing record…' : 'Analyze measurements',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      if (result != null)
        TextButton(
          onPressed: () => showResult(result!, expected: expectedLabel),
          child: const Text('View latest result'),
        ),
      TextButton(
        onPressed: predicting
            ? null
            : () {
                for (final c in controllers.values) {
                  c.clear();
                }
                vm.clearMeasurements();
                formKey.currentState?.reset();
              },
        child: const Text('Clear measurements'),
      ),
      const SizedBox(height: 14),
      const NoticeCard(),
    ],
  );

  Widget modelLab() => PageBody(
    padding: const EdgeInsets.all(22),
    children: [
      Text('BEHIND THE PREDICTION', style: eyebrow()),
      const SizedBox(height: 12),
      const Text(
        'The model lab',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        metrics!['selection'],
        style: const TextStyle(color: emeraldLight, height: 1.6, fontSize: 14),
      ),
      const SizedBox(height: 20),
      AdaptivePair(
        first: stat(
          '${metrics!['train_samples']}',
          'Training records',
          Icons.school_outlined,
        ),
        second: stat(
          '${metrics!['test_samples']}',
          'Held-out records',
          Icons.fact_check_outlined,
        ),
      ),
      const SizedBox(height: 20),
      ...[
        for (final m in metrics!['models'])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(m['name'], style: heading())),
                      if (m['id'] == metrics!['selected_model'])
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x3310B981),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x6634D399)),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: emeraldBright,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cross-validation F1: ${percent(m['cv_f1'])} ± ${percent(m['cv_f1_std'])}',
                    style: const TextStyle(
                      color: emeraldBright,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    children: [
                      for (final entry in {
                        'Accuracy': 'accuracy',
                        'Precision': 'precision',
                        'Recall': 'recall',
                        'F1 score': 'f1',
                        'ROC-AUC': 'roc_auc',
                      }.entries)
                        SizedBox(
                          width: 82,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                percent(m[entry.value]),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  color: emeraldMint,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(color: Color(0x2E34D399)),
                  const SizedBox(height: 8),
                  const Text(
                    'Confusion matrix · held-out test',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    columnWidths: const {0: FlexColumnWidth(1.3)},
                    children: [
                      TableRow(
                        children: [
                          Text(
                            'Actual ↓ / Pred. →',
                            style: TextStyle(
                              fontSize: 14,
                              color: emeraldMint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            negativeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            positiveLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      for (int i = 0; i < 2; i++)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                i == 0 ? negativeLabel : positiveLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: emeraldLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (int j = 0; j < 2; j++)
                              Container(
                                margin: const EdgeInsets.all(3),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: i == j
                                      ? const Color(0x3310B981)
                                      : const Color(0x22000000),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: i == j
                                        ? const Color(0x6634D399)
                                        : const Color(0x1F34D399),
                                  ),
                                ),
                                child: Text(
                                  '${m['confusion_matrix'][i][j]}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: i == j ? emeraldBright : textMuted,
                                    fontWeight: i == j
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height: 8),
      Text('Know the dataset', style: heading()),
      const SizedBox(height: 12),
      Text(
        '${metrics!['raw_samples'] ?? metrics!['total_samples']} source records; ${metrics!['total_samples']} unique usable records; $featureCount features. $positiveLabel is the positive class. Duplicate rows removed: ${metrics!['duplicate_rows_removed'] ?? 0}. Conflicting rows excluded: ${metrics!['conflicting_rows_removed'] ?? 0}. Preprocessing is fitted inside training folds. These results do not establish clinical performance.',
        style: TextStyle(color: emeraldLight, height: 1.6, fontSize: 13.5),
      ),
      const SizedBox(height: 16),
      SelectableText(
        'Source: ${metrics!['dataset']}\n${metrics!['citation'] ?? ''}\n${metrics!['source_url'] ?? ''}\n${metrics!['doi'] ?? ''}\nCC BY 4.0',
        style: TextStyle(color: emeraldMint, fontSize: 12, height: 1.7),
      ),
      const SizedBox(height: 18),
      const NoticeCard(),
    ],
  );

  Future<void> clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear analysis history?'),
        scrollable: true,
        content: const Text(
          'This removes all saved results on this demo server, including results from other connected devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep history'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await vm.clearHistory();
  }

  Widget history() => RefreshIndicator(
    color: emeraldBright,
    backgroundColor: const Color(0xFF04261B),
    onRefresh: loadHistory,
    child: PageBody(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(22),
      children: [
        Text('YOUR EXPLORATIONS', style: eyebrow()),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Analysis history',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh history',
              onPressed: historyLoading || clearing ? null : loadHistory,
              icon: const Icon(Icons.refresh, color: emeraldBright),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'The latest 200 results on this demo server. Names and raw measurements are not stored. History is shared across connected devices.',
          style: TextStyle(color: emeraldLight, height: 1.5, fontSize: 13.5),
        ),
        const SizedBox(height: 22),
        if (historyLoading)
          const Center(child: CircularProgressIndicator(color: emeraldBright)),
        if (historyError != null) ...[
          errorBox(historyError!),
          const SizedBox(height: 8),
          TextButton(onPressed: loadHistory, child: const Text('Retry')),
        ],
        if (!historyLoading && historyError == null && records.isEmpty)
          panel(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.history_rounded, size: 44, color: emeraldBright),
                  SizedBox(height: 18),
                  Text(
                    'A fresh start',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your next analysis will appear here.',
                    style: TextStyle(color: textMuted),
                  ),
                ],
              ),
            ),
          ),
        ...[
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x3310B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      record['result']['label'] == 'benign'
                          ? Icons.bubble_chart_outlined
                          : Icons.scatter_plot_outlined,
                      color: emeraldBright,
                    ),
                  ),
                  title: Text(
                    '${record['result']['label_display'] ?? title(record['result']['label'])} classification',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${record['result']['disease_name'] ?? 'Breast Cancer'} · ${record['result']['model_name']}\n${date(record['created_at'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: emeraldMint,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: emeraldBright,
                  ),
                  onTap: () =>
                      showResult(Map<String, dynamic>.from(record['result'])),
                ),
              ),
            ),
        ],
        if (records.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: clearing || historyLoading ? null : clearHistory,
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFFCA5A5),
                size: 18,
              ),
              label: Text(
                clearing ? 'Clearing…' : 'Clear server history',
                style: const TextStyle(color: Color(0xFFFCA5A5)),
              ),
            ),
          ),
      ],
    ),
  );
}
