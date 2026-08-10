import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/employees/data/employees_repository.dart';
import 'package:ds_clickeat_web_admin/features/employees/models/employee.dart';

class EmployeesState {
  final List<Employee> employees;
  final bool loading;
  final String? error;

  const EmployeesState({
    this.employees = const [],
    this.loading = false,
    this.error,
  });

  EmployeesState copyWith({
    List<Employee>? employees,
    bool? loading,
    String? error,
  }) => EmployeesState(
        employees: employees ?? this.employees,
        loading: loading ?? this.loading,
        error: error,
      );
}

final employeesControllerProvider =
    StateNotifierProvider<EmployeesController, EmployeesState>((ref) {
  return EmployeesController(ref);
});

class EmployeesController extends StateNotifier<EmployeesState> {
  EmployeesController(this._ref) : super(const EmployeesState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  EmployeesRepository get _repo => _ref.read(employeesRepositoryProvider);

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _repo.getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort((a, b) => a.emplName.toLowerCase().compareTo(b.emplName.toLowerCase()));
      state = EmployeesState(employees: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Reload-on-success — used for create, since the new row's server-
  /// assigned `empl_id` isn't known locally.
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

  Future<String?> createEmployee(
    int premId, {
    required String name,
    required String email,
    required int roleId,
    required String password,
  }) => _mutate(
        premId,
        () => _repo.createEmployee(
          premId: premId,
          name: name,
          email: email,
          roleId: roleId,
          password: password,
        ),
      );

  Future<String?> updateEmployee(
    int premId,
    int emplId, {
    required String name,
    required String email,
    required bool available,
    required int roleId,
    required String roleName,
    String? password,
  }) => _mutateLocal(
        premId,
        () => _repo.updateEmployee(
          premId: premId,
          emplId: emplId,
          name: name,
          email: email,
          available: available,
          roleId: roleId,
          password: password,
        ),
        () => _patchEmployee(
          emplId,
          name: name,
          email: email,
          available: available,
          roleId: roleId,
          roleName: roleName,
        ),
      );

  /// Flips an employee's available flag, persisting the change via update.
  Future<String?> toggleAvailable(int premId, Employee employee) => updateEmployee(
        premId,
        employee.emplId,
        name: employee.emplName,
        email: employee.emplEmail,
        available: !employee.emplAvailable,
        roleId: employee.roleId,
        roleName: employee.roleName,
      );

  void _patchEmployee(
    int emplId, {
    required String name,
    required String email,
    required bool available,
    required int roleId,
    required String roleName,
  }) {
    state = state.copyWith(
      employees: [
        for (final employee in state.employees)
          if (employee.emplId == emplId)
            employee.copyWith(
              emplName: name,
              emplEmail: email,
              emplAvailable: available,
              roleId: roleId,
              roleName: roleName,
            )
          else
            employee,
      ],
    );
  }
}
