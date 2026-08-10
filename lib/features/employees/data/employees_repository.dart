import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/employees/models/employee.dart';

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return EmployeesRepository(ref.read(dioProvider));
});

class EmployeesRepository {
  EmployeesRepository(this._dio);
  final Dio _dio;

  /// GET `premises/employee/<premId>` — the staff configured for a premise.
  /// `fun_get_admin_employee` always appends a synthetic `empl_id: 0` /
  /// "Admin" row via `UNION ALL` that isn't a real `EMPLOYEE` record —
  /// dropped here so it never shows up as an editable row in the Personal
  /// table.
  Future<List<Employee>> getByPremise(int premId) async {
    final res = await _dio.get('premises/employee/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((employee) => employee.emplId != 0)
          .toList();
    }
    return [];
  }

  /// GET `premises/employee-validate-email?empl_email=<email>` — true when
  /// [email] is already registered to some employee. Query-string on
  /// purpose (per the backend doc): dodges `@`/`.` URL-encoding issues and
  /// avoids colliding with the `premises/employee/<premId>` path route.
  Future<bool> emailExists(String email) async {
    final res = await _dio.get(
      'premises/employee-validate-email',
      queryParameters: {'empl_email': email},
    );
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return (data['result'] as Map)['empl_email_exists'] == true;
    }
    return false;
  }

  // ===== Employees CRUD (premises/employee-crud) ==============================
  // `empl_type` flags the operation: only I (insert) and U (update) — the SP
  // (`fun_admin_employee_crud`) has no delete branch.

  /// `fun_admin_employee_crud`'s insert branch sets `prem_id`/`empl_name`/
  /// `empl_email`/`role_id`/`empl_password` (hashed server-side, same as
  /// update) — `empl_available` still isn't part of the INSERT and is left
  /// at the table default.
  Future<void> createEmployee({
    required int premId,
    required String name,
    required String email,
    required int roleId,
    required String password,
  }) async {
    await _crud({
      'prem_id': premId,
      'empl_type': 'I',
      'empl_name': name,
      'empl_email': email,
      'role_id': roleId,
      'empl_password': password,
    });
  }

  /// [password] is omitted from the request entirely when null/blank —
  /// `fun_admin_employee_crud`'s update branch does an unconditional
  /// `SET empl_password = var_empl_password` with no "keep existing value"
  /// guard, so sending an empty/absent password on every routine edit (e.g.
  /// toggling `empl_available`) would silently wipe the stored hash unless
  /// the SP is changed to skip the assignment when null. Confirm with
  /// backend before this ships.
  Future<void> updateEmployee({
    required int premId,
    required int emplId,
    required String name,
    required String email,
    required bool available,
    required int roleId,
    String? password,
  }) async {
    await _crud({
      'prem_id': premId,
      'empl_type': 'U',
      'empl_id': emplId,
      'empl_name': name,
      'empl_email': email,
      'empl_available': available,
      'role_id': roleId,
      if (password != null && password.isNotEmpty) 'empl_password': password,
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('premises/employee-crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
