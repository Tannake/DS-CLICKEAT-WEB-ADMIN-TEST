import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/reasons/models/cancel_reason.dart';

final reasonsRepositoryProvider = Provider<ReasonsRepository>((ref) {
  return ReasonsRepository(ref.read(dioProvider));
});

class ReasonsRepository {
  ReasonsRepository(this._dio);
  final Dio _dio;

  /// GET `orders/reason-cancel/<premId>` — the cancellation reasons configured
  /// for a premise. The auth token is injected by the interceptor.
  Future<List<CancelReason>> getByPremise(int premId) async {
    final res = await _dio.get('orders/reason-cancel/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) =>
              CancelReason.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // ===== Reasons CRUD (orders/reason-cancel-crud) ===========================
  // `reas_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createReason({
    required int premId,
    required String name,
  }) async {
    await _crud({
      'prem_id': premId,
      'reas_name': name,
      'reas_type': 'I',
    });
  }

  Future<void> updateReason({
    required int premId,
    required int reasId,
    required String name,
    required bool available,
  }) async {
    await _crud({
      'prem_id': premId,
      'reas_id': reasId,
      'reas_name': name,
      'reas_available': available,
      'reas_type': 'U',
    });
  }

  Future<void> deleteReason({
    required int premId,
    required int reasId,
  }) async {
    await _crud({
      'prem_id': premId,
      'reas_id': reasId,
      'reas_type': 'D',
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('orders/reason-cancel-crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
