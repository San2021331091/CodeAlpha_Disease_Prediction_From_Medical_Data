import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../api.dart';
import '../core/config/app_config.dart';
import '../repositories/workspace_repository.dart';
import 'analysis_state.dart';
import 'analysis_view_model.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.load());
final apiProvider = Provider<CellScopeApi>((Ref ref) {
  final api = CellScopeApi(
    url: ref.watch(appConfigProvider).apiBaseUrl,
    timeout: ref.watch(appConfigProvider).timeout,
  );
  ref.onDispose(api.close);
  return api;
});
final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(ref.watch(apiProvider)),
);
final analysisViewModelProvider =
    StateNotifierProvider<AnalysisViewModel, AnalysisState>(
      (ref) => AnalysisViewModel(ref.watch(workspaceRepositoryProvider)),
    );
