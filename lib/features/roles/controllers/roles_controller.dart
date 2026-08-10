import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/roles/data/roles_repository.dart';
import 'package:ds_clickeat_web_admin/features/roles/models/role.dart';

class RolesState {
  final List<Role> roles;
  final bool loading;
  final String? error;

  const RolesState({
    this.roles = const [],
    this.loading = false,
    this.error,
  });

  RolesState copyWith({
    List<Role>? roles,
    bool? loading,
    String? error,
  }) => RolesState(
        roles: roles ?? this.roles,
        loading: loading ?? this.loading,
        error: error,
      );
}

final rolesControllerProvider =
    StateNotifierProvider<RolesController, RolesState>((ref) {
  return RolesController(ref);
});

class RolesController extends StateNotifier<RolesState> {
  RolesController(this._ref) : super(const RolesState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  RolesRepository get _repo => _ref.read(rolesRepositoryProvider);

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _repo.getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort((a, b) => a.roleName.toLowerCase().compareTo(b.roleName.toLowerCase()));
      state = RolesState(roles: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Reload-on-success — used for create, since the new row's server-
  /// assigned `role_id` isn't known locally.
  Future<String?> _mutate(int premId, Future<void> Function() action) async {
    try {
      await action();
      await load(premId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _mutateLocal(
    int premId,
    Future<void> Function() action,
    void Function() applyLocal,
  ) async {
    try {
      await action();
      if (premId == _activePremId) applyLocal();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> createRole(int premId, {required String name}) => _mutate(
        premId,
        () => _repo.createRole(premId: premId, name: name),
      );

  Future<String?> updateRole(
    int premId,
    int roleId, {
    required String name,
    required bool available,
  }) => _mutateLocal(
        premId,
        () => _repo.updateRole(
          premId: premId,
          roleId: roleId,
          name: name,
          available: available,
        ),
        () => _patchRole(roleId, name: name, available: available),
      );

  /// Flips a role's available flag, persisting the change via update.
  Future<String?> toggleAvailable(int premId, Role role) => updateRole(
        premId,
        role.roleId,
        name: role.roleName,
        available: !role.roleAvailable,
      );

  void _patchRole(int roleId, {required String name, required bool available}) {
    state = state.copyWith(
      roles: [
        for (final role in state.roles)
          if (role.roleId == roleId)
            role.copyWith(roleName: name, roleAvailable: available)
          else
            role,
      ],
    );
  }
}
