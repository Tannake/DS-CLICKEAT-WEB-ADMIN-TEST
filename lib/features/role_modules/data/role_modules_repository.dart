import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/role_modules/models/role_module.dart';

final roleModulesRepositoryProvider = Provider<RoleModulesRepository>((ref) {
  return RoleModulesRepository(ref.read(dioProvider));
});

class RoleModulesRepository {
  RoleModulesRepository(this._dio);
  final Dio _dio;

  /// GET `premises/system-module` — the catalog of screens that can be
  /// assigned to a role (the matrix's columns). Not premise-scoped.
  Future<List<SystemModule>> getSystemModules() async {
    final res = await _dio.get('premises/system-module');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => SystemModule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// GET `premises/role-module/<premId>` — the role<->module assignments
  /// for a premise (one flat row per assigned combination).
  Future<List<RoleModuleAssignment>> getByPremise(int premId) async {
    final res = await _dio.get('premises/role-module/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => RoleModuleAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // ===== Role<->module CRUD (premises/role-module-crud) =======================
  // `rmod_type` flags the operation: only I (assign) and D (unassign) — no
  // update, since "editing" an assignment doesn't mean anything.

  Future<void> assignModule({
    required int premId,
    required int roleId,
    required int sysmId,
  }) async {
    await _crud({
      'prem_id': premId,
      'role_id': roleId,
      'sysm_id': sysmId,
      'rmod_type': 'I',
    });
  }

  Future<void> unassignModule({
    required int premId,
    required int roleId,
    required int sysmId,
  }) async {
    await _crud({
      'prem_id': premId,
      'role_id': roleId,
      'sysm_id': sysmId,
      'rmod_type': 'D',
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('premises/role-module-crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
