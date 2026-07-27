import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/tips/models/tip.dart';

final tipsRepositoryProvider = Provider<TipsRepository>((ref) {
  return TipsRepository(ref.read(dioProvider));
});

class TipsRepository {
  TipsRepository(this._dio);
  final Dio _dio;

  /// GET `orders/tips/<premId>` — the tip presets configured for a premise.
  /// The auth token is injected by the interceptor.
  Future<List<Tip>> getByPremise(int premId) async {
    final res = await _dio.get('orders/tips/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => Tip.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // ===== Tips CRUD (orders/tips-crud) =======================================
  // `tips_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createTip({
    required int premId,
    required int percentage,
  }) async {
    await _crud({
      'prem_id': premId,
      'tips_percentage': percentage,
      'tips_type': 'I',
    });
  }

  Future<void> updateTip({
    required int premId,
    required int tipsId,
    required int percentage,
    required bool available,
  }) async {
    await _crud({
      'prem_id': premId,
      'tips_id': tipsId,
      'tips_percentage': percentage,
      'tips_available': available,
      'tips_type': 'U',
    });
  }

  Future<void> deleteTip({
    required int premId,
    required int tipsId,
  }) async {
    await _crud({
      'prem_id': premId,
      'tips_id': tipsId,
      'tips_type': 'D',
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('orders/tips-crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
