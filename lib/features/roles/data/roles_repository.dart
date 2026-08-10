import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/roles/models/role.dart';

final rolesRepositoryProvider = Provider<RolesRepository>((ref) {
  return RolesRepository(ref.read(dioProvider));
});

class RolesRepository {
  RolesRepository(this._dio);
  final Dio _dio;

  /// GET `premises/role/<premId>` — the roles configured for a premise.
  Future<List<Role>> getByPremise(int premId) async {
    final res = await _dio.get('premises/role/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => Role.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // ===== Roles CRUD (premises/role-crud) ======================================
  // `role_type` flags the operation: only I (insert) and U (update) — the SP
  // (`fun_admin_role_crud`) has no delete branch.

  /// `fun_admin_role_crud`'s insert branch only sets `prem_id`/`role_name` —
  /// `role_available` isn't part of the INSERT and is left at the table's
  /// default, so it isn't sent here (matches how the backend doc flags this
  /// as SP behavior to confirm, not something the client can override).
  Future<void> createRole({required int premId, required String name}) async {
    await _crud({
      'prem_id': premId,
      'role_type': 'I',
      'role_name': name,
    });
  }

  Future<void> updateRole({
    required int premId,
    required int roleId,
    required String name,
    required bool available,
  }) async {
    await _crud({
      'prem_id': premId,
      'role_type': 'U',
      'role_id': roleId,
      'role_name': name,
      'role_available': available,
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('premises/role-crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
