import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_detail.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_summary.dart';

final branchesRepositoryProvider = Provider<BranchesRepository>((ref) {
  return BranchesRepository(ref.read(dioProvider));
});

class BranchesRepository {
  BranchesRepository(this._dio);
  final Dio _dio;

  /// GET `premises/<userId>` — the branch cards for the signed-in user.
  Future<List<BranchSummary>> getByUser(int userId) async {
    final res = await _dio.get('premises/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) =>
              BranchSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// GET `premises-detail/<userId>/<premId>` — the full editable branch shape.
  Future<BranchDetail> getDetail(int userId, int premId) async {
    final res = await _dio.get('premises-detail/$userId/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return BranchDetail.fromJson(
        Map<String, dynamic>.from(data['result'] as Map),
      );
    }
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'No se pudo cargar la sucursal.');
  }

  /// POST `premises-update` — there is no insert/delete, only update.
  /// `password` is empty when the user left it unchanged.
  Future<void> update({
    required int userId,
    required BranchDetail detail,
    required String password,
  }) async {
    final res = await _dio.post(
      'premises-update',
      data: detail.toUpdateJson(userId: userId, password: password),
    );
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
