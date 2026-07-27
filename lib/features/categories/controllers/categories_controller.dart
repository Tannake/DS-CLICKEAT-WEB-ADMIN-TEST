import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/categories/data/categories_repository.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/category.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/preparation_area.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/printer_option.dart';

class CategoriesState {
  final List<Category> categories;
  final List<PreparationArea> preparationAreas;
  final List<PrinterOption> printerOptions;
  final bool loading;
  final String? error;

  const CategoriesState({
    this.categories = const [],
    this.preparationAreas = const [],
    this.printerOptions = const [],
    this.loading = false,
    this.error,
  });

  CategoriesState copyWith({
    List<Category>? categories,
    List<PreparationArea>? preparationAreas,
    List<PrinterOption>? printerOptions,
    bool? loading,
    String? error,
  }) => CategoriesState(
    categories: categories ?? this.categories,
    preparationAreas: preparationAreas ?? this.preparationAreas,
    printerOptions: printerOptions ?? this.printerOptions,
    loading: loading ?? this.loading,
    error: error,
  );
}

final categoriesControllerProvider =
    StateNotifierProvider<CategoriesController, CategoriesState>((ref) {
      return CategoriesController(ref);
    });

class CategoriesController extends StateNotifier<CategoriesState> {
  CategoriesController(this._ref) : super(const CategoriesState());
  final Ref _ref;

  int? _premId;
  int _loadToken = 0;

  CategoriesRepository get _repo => _ref.read(categoriesRepositoryProvider);

  Future<void> load(int premId) async {
    _premId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _repo.getByPremise(premId);
      if (token != _loadToken || premId != _premId) return;

      // Categories ordered by prodc_order, then name as a stable tiebreaker.
      final categories = [...data.categories]
        ..sort((a, b) {
          final byOrder = a.prodcOrder.compareTo(b.prodcOrder);
          return byOrder != 0 ? byOrder : a.prodcName.compareTo(b.prodcName);
        });
      // Preparation areas ordered by name.
      final prepAreas = [...data.preparationAreas]
        ..sort((a, b) => a.prepName.compareTo(b.prepName));

      state = CategoriesState(
        categories: categories,
        preparationAreas: prepAreas,
        printerOptions: data.printerOptions,
        loading: false,
      );
    } catch (e) {
      if (token != _loadToken || premId != _premId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  // ===== Category CRUD =====================================================
  // Each action returns `null` on success or an error message string. On
  // success the list is reloaded so counts/order stay in sync with the backend.

  Future<String?> createCategory(String name, int order) => _run(
    () => _repo.createCategory(premId: _premId!, name: name, order: order),
  );

  Future<String?> updateCategory(
    int prodcId,
    String name,
    int order,
    bool available,
  ) => _runLocal(
    () => _repo.updateCategory(
      premId: _premId!,
      prodcId: prodcId,
      name: name,
      order: order,
      available: available,
    ),
    () => _patchCategory(prodcId, name, order, available),
  );

  Future<String?> deleteCategory(int prodcId) => _runLocal(
    () => _repo.deleteCategory(premId: _premId!, prodcId: prodcId),
    () => state = state.copyWith(
      categories: [
        for (final category in state.categories)
          if (category.prodcId != prodcId) category,
      ],
    ),
  );

  // ===== Preparation area CRUD ============================================

  Future<String?> createPreparationArea(
    String name,
    int? printerId,
    bool printEnabled,
    bool available,
  ) => _run(
    () => _repo.createPreparationArea(
      premId: _premId!,
      name: name,
      printerId: printerId,
      printEnabled: printEnabled,
      available: available,
    ),
  );

  Future<String?> updatePreparationArea(
    int prepId,
    String name,
    int? printerId,
    bool printEnabled,
    bool available,
  ) => _runLocal(
    () => _repo.updatePreparationArea(
      premId: _premId!,
      prepId: prepId,
      name: name,
      printerId: printerId,
      printEnabled: printEnabled,
      available: available,
    ),
    () => _patchPreparationArea(
      prepId,
      name,
      printerId,
      printEnabled,
      available,
    ),
  );

  Future<String?> deletePreparationArea(int prepId) => _runLocal(
    () => _repo.deletePreparationArea(premId: _premId!, prepId: prepId),
    () => state = state.copyWith(
      preparationAreas: [
        for (final area in state.preparationAreas)
          if (area.prepId != prepId) area,
      ],
    ),
  );

  /// Flips a preparation area's print-enabled flag, persisting via update.
  Future<String?> togglePrintEnabled(int prepId) {
    final area = state.preparationAreas.firstWhere(
      (a) => a.prepId == prepId,
    );
    return updatePreparationArea(
      prepId,
      area.prepName,
      _printerIdForName(area.prinName),
      !area.prepPrintEnabled,
      area.prepAvailable,
    );
  }

  /// Flips a preparation area's active flag, persisting via update.
  Future<String?> toggleAvailable(int prepId) {
    final area = state.preparationAreas.firstWhere(
      (a) => a.prepId == prepId,
    );
    return updatePreparationArea(
      prepId,
      area.prepName,
      _printerIdForName(area.prinName),
      area.prepPrintEnabled,
      !area.prepAvailable,
    );
  }

  /// Resolves a preparation area's stored `prin_name` to the matching
  /// registered printer's id, or `null` (the "Predeterminada" sentinel) if it
  /// doesn't match any registered printer — e.g. the backend's own "Default"
  /// placeholder for an area with no printer assigned yet.
  int? _printerIdForName(String name) {
    for (final option in state.printerOptions) {
      if (option.prinName == name) return option.prinId;
    }
    return null;
  }

  Future<String?> _run(Future<void> Function() action) async {
    if (_premId == null) return 'No hay sucursal seleccionada.';
    try {
      await action();
      await load(_premId!);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _runLocal(
    Future<void> Function() action,
    void Function() applyLocal,
  ) async {
    if (_premId == null) return 'No hay sucursal seleccionada.';
    final premId = _premId;
    try {
      await action();
      if (premId == _premId) applyLocal();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  void _patchCategory(int prodcId, String name, int order, bool available) {
    final categories =
        [
          for (final category in state.categories)
            if (category.prodcId == prodcId)
              Category(
                prodcId: category.prodcId,
                prodcName: name,
                prodcOrder: order,
                prodcAvailable: available,
                prodCount: category.prodCount,
              )
            else
              category,
        ]..sort((a, b) {
          final byOrder = a.prodcOrder.compareTo(b.prodcOrder);
          return byOrder != 0 ? byOrder : a.prodcName.compareTo(b.prodcName);
        });
    state = state.copyWith(categories: categories);
  }

  void _patchPreparationArea(
    int prepId,
    String name,
    int? printerId,
    bool printEnabled,
    bool available,
  ) {
    final printerName = _printerNameForId(printerId);
    final areas = [
      for (final area in state.preparationAreas)
        if (area.prepId == prepId)
          PreparationArea(
            prepId: area.prepId,
            prepName: name,
            prodCount: area.prodCount,
            prinName: printerName,
            prepPrintEnabled: printEnabled,
            prepAvailable: available,
          )
        else
          area,
    ]..sort((a, b) => a.prepName.compareTo(b.prepName));
    state = state.copyWith(preparationAreas: areas);
  }

  /// The inverse of [_printerIdForName]: resolves a printer id back to its
  /// display name, falling back to the backend's own "Default" sentinel for
  /// `null` (no printer assigned) or an id that no longer matches a
  /// registered printer.
  String _printerNameForId(int? printerId) {
    if (printerId == null) return 'Default';
    for (final option in state.printerOptions) {
      if (option.prinId == printerId) return option.prinName;
    }
    return 'Default';
  }
}
