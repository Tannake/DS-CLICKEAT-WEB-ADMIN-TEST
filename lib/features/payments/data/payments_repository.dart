import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/payments/models/payment_method.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.read(dioProvider));
});

class PaymentsRepository {
  PaymentsRepository(this._dio);
  final Dio _dio;

  /// GET `payments/<premId>` — the payment methods configured for a premise.
  /// The auth token is injected by the interceptor.
  Future<List<PaymentMethod>> getByPremise(int premId) async {
    final res = await _dio.get('payments/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) =>
              PaymentMethod.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // ===== Payment CRUD (payments/crud) =======================================
  // `paym_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createPayment({
    required int premId,
    required String name,
    required bool available,
  }) async {
    await _crud({
      'prem_id': premId,
      'paym_name': name,
      'paym_available': available,
      'paym_type': 'I',
    });
  }

  Future<void> updatePayment({
    required int premId,
    required int paymId,
    required String name,
    required bool available,
  }) async {
    await _crud({
      'prem_id': premId,
      'paym_id': paymId,
      'paym_name': name,
      'paym_available': available,
      'paym_type': 'U',
    });
  }

  Future<void> deletePayment({
    required int premId,
    required int paymId,
  }) async {
    await _crud({
      'prem_id': premId,
      'paym_id': paymId,
      'paym_type': 'D',
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('payments/crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
