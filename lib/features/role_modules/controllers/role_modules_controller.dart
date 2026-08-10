import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/role_modules/data/role_modules_repository.dart';
import 'package:ds_clickeat_web_admin/features/role_modules/models/role_module.dart';

class RoleModulesState {
  final List<SystemModule> modules;
  /// `roleId` -> the set of `sysmId`s assigned to it. Built from the flat
  /// `premises/role-module/<premId>` rows on [load] so the matrix widget can
  /// do an O(1) lookup per cell instead of scanning the row list.
  final Map<int, Set<int>> assignments;
  final bool loading;
  final String? error;

  const RoleModulesState({
    this.modules = const [],
    this.assignments = const {},
    this.loading = false,
    this.error,
  });

  bool isAssigned(int roleId, int sysmId) => assignments[roleId]?.contains(sysmId) ?? false;

  RoleModulesState copyWith({
    List<SystemModule>? modules,
    Map<int, Set<int>>? assignments,
    bool? loading,
    String? error,
  }) => RoleModulesState(
        modules: modules ?? this.modules,
        assignments: assignments ?? this.assignments,
        loading: loading ?? this.loading,
        error: error,
      );
}

final roleModulesControllerProvider =
    StateNotifierProvider<RoleModulesController, RoleModulesState>((ref) {
  return RoleModulesController(ref);
});

class RoleModulesController extends StateNotifier<RoleModulesState> {
  RoleModulesController(this._ref) : super(const RoleModulesState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  RoleModulesRepository get _repo => _ref.read(roleModulesRepositoryProvider);

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getSystemModules(),
        _repo.getByPremise(premId),
      ]);
      if (token != _loadToken || premId != _activePremId) return;
      final modules = results[0] as List<SystemModule>;
      final rows = results[1] as List<RoleModuleAssignment>;
      final assignments = <int, Set<int>>{};
      for (final row in rows) {
        assignments.putIfAbsent(row.roleId, () => <int>{}).add(row.sysmId);
      }
      state = RoleModulesState(modules: modules, assignments: assignments, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Flips one matrix cell: assigns the module when [assigned] is true,
  /// unassigns it otherwise. Waits for the backend to confirm before
  /// patching local state (rather than optimistic-then-revert), matching
  /// the reload-on-success spirit of the other controllers' mutations while
  /// keeping this one cheap — a single boolean flip, no full reload.
  Future<String?> setAssigned(int premId, int roleId, int sysmId, bool assigned) async {
    try {
      if (assigned) {
        await _repo.assignModule(premId: premId, roleId: roleId, sysmId: sysmId);
      } else {
        await _repo.unassignModule(premId: premId, roleId: roleId, sysmId: sysmId);
      }
      if (premId == _activePremId) _patch(roleId, sysmId, assigned);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  void _patch(int roleId, int sysmId, bool assigned) {
    final assignments = {...state.assignments};
    final set = {...(assignments[roleId] ?? const <int>{})};
    if (assigned) {
      set.add(sysmId);
    } else {
      set.remove(sysmId);
    }
    assignments[roleId] = set;
    state = state.copyWith(assignments: assignments);
  }
}
