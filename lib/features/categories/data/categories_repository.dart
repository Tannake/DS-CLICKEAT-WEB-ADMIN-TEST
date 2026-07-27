import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/category.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/preparation_area.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/printer_option.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.read(dioProvider));
});

/// Combined payload returned by `products/category-preparation/<premId>`:
/// the menu categories, the preparation areas (each with a product count),
/// and the premise's registered printers (for the preparation area's
/// printer picker).
class CategoryPreparationData {
  final List<Category> categories;
  final List<PreparationArea> preparationAreas;
  final List<PrinterOption> printerOptions;

  const CategoryPreparationData({
    this.categories = const [],
    this.preparationAreas = const [],
    this.printerOptions = const [],
  });
}

class CategoriesRepository {
  CategoriesRepository(this._dio);
  final Dio _dio;

  /// Fetches the categories and preparation areas for [premId]. The auth token
  /// is injected by the Dio interceptor. Returns empty lists on a non-success
  /// envelope.
  Future<CategoryPreparationData> getByPremise(int premId) async {
    final res = await _dio.get('products/category-preparation/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      final result = Map<String, dynamic>.from(data['result'] as Map);
      final categories = (result['category'] as List? ?? const [])
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final prepAreas = (result['preparation_area'] as List? ?? const [])
          .map((e) =>
              PreparationArea.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final printerOptions = (result['printer'] as List? ?? const [])
          .map(
            (e) => PrinterOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      return CategoryPreparationData(
        categories: categories,
        preparationAreas: prepAreas,
        printerOptions: printerOptions,
      );
    }
    return const CategoryPreparationData();
  }

  // ===== Category CRUD (products/category-crud) =============================
  // `prodc_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createCategory({
    required int premId,
    required String name,
    required int order,
  }) async {
    await _crud('products/category-crud', {
      'prem_id': premId,
      'prodc_type': 'I',
      'prodc_name': name,
      'prodc_order': order,
    });
  }

  Future<void> updateCategory({
    required int premId,
    required int prodcId,
    required String name,
    required int order,
    required bool available,
  }) async {
    await _crud('products/category-crud', {
      'prem_id': premId,
      'prodc_type': 'U',
      'prodc_id': prodcId,
      'prodc_name': name,
      'prodc_order': order,
      'prodc_available': available,
    });
  }

  Future<void> deleteCategory({
    required int premId,
    required int prodcId,
  }) async {
    await _crud('products/category-crud', {
      'prem_id': premId,
      'prodc_type': 'D',
      'prodc_id': prodcId,
    });
  }

  // ===== Preparation area CRUD (products/preparation-area-crud) =============
  // `prep_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createPreparationArea({
    required int premId,
    required String name,
    required int? printerId,
    required bool printEnabled,
    required bool available,
  }) async {
    await _crud('products/preparation-area-crud', {
      'prem_id': premId,
      'prep_type': 'I',
      'prep_name': name,
      'prin_id': printerId,
      'prep_print_enabled': printEnabled,
      'prep_available': available,
    });
  }

  Future<void> updatePreparationArea({
    required int premId,
    required int prepId,
    required String name,
    required int? printerId,
    required bool printEnabled,
    required bool available,
  }) async {
    await _crud('products/preparation-area-crud', {
      'prem_id': premId,
      'prep_type': 'U',
      'prep_id': prepId,
      'prep_name': name,
      'prin_id': printerId,
      'prep_print_enabled': printEnabled,
      'prep_available': available,
    });
  }

  Future<void> deletePreparationArea({
    required int premId,
    required int prepId,
  }) async {
    await _crud('products/preparation-area-crud', {
      'prem_id': premId,
      'prep_type': 'D',
      'prep_id': prepId,
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
