import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/printers/models/printer.dart';

final printersRepositoryProvider = Provider<PrintersRepository>((ref) {
  return PrintersRepository(ref.read(dioProvider));
});

class PrintersRepository {
  PrintersRepository(this._dio);
  final Dio _dio;

  /// GET `premises/printer/<premId>` — the printers configured for a premise.
  Future<List<Printer>> getByPremise(int premId) async {
    final res = await _dio.get('premises/printer/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => Printer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // ===== Printers CRUD (premises/printer-crud) ===============================
  // `prin_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createPrinter({
    required int premId,
    required String name,
    required String connectionType,
    required String usageType,
    String? ip,
    int? port,
    String? windowsName,
    required int paperWidth,
    required bool autoCut,
    required bool beep,
    required bool isDefault,
    required bool isActive,
  }) async {
    await _crud({
      'prem_id': premId,
      'prin_type': 'I',
      'prin_name': name,
      'prin_connection_type': connectionType,
      'prin_usage_type': usageType,
      'prin_ip': ip,
      'prin_port': port,
      'prin_windows_name': windowsName,
      'prin_paper_width': paperWidth,
      'prin_auto_cut': autoCut,
      'prin_beep': beep,
      'prin_is_default': isDefault,
      'prin_is_active': isActive,
    });
  }

  Future<void> updatePrinter({
    required int premId,
    required int prinId,
    required String name,
    required String connectionType,
    required String usageType,
    String? ip,
    int? port,
    String? windowsName,
    required int paperWidth,
    required bool autoCut,
    required bool beep,
    required bool isDefault,
    required bool isActive,
  }) async {
    await _crud({
      'prem_id': premId,
      'prin_type': 'U',
      'prin_id': prinId,
      'prin_name': name,
      'prin_connection_type': connectionType,
      'prin_usage_type': usageType,
      'prin_ip': ip,
      'prin_port': port,
      'prin_windows_name': windowsName,
      'prin_paper_width': paperWidth,
      'prin_auto_cut': autoCut,
      'prin_beep': beep,
      'prin_is_default': isDefault,
      'prin_is_active': isActive,
    });
  }

  Future<void> deletePrinter({
    required int premId,
    required int prinId,
  }) async {
    await _crud({
      'prem_id': premId,
      'prin_id': prinId,
      'prin_type': 'D',
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(Map<String, dynamic> body) async {
    final res = await _dio.post('premises/printer-crud', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }

  /// POST `premises/printer-test` — sends a test print to the printer's
  /// premise/room so the admin can confirm it's configured correctly.
  Future<void> testPrint({required int premId, required Printer printer}) async {
    final body = printer.toJson();
    body['prem_id'] = premId;
    final res = await _dio.post('premises/printer-test', data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'No se pudo enviar la prueba de impresión.');
  }
}
