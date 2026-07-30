import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/categories/controllers/categories_controller.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/category.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/preparation_area.dart';
import 'package:ds_clickeat_web_admin/features/categories/models/printer_option.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  int? _lastPremId;

  // A single row across both tables can be in edit/create mode at a time.
  // Keys: 'cat-<id>', 'cat-new', 'prep-<id>', 'prep-new'. null = none.
  String? _editKey;
  bool _saving = false;

  void _ensurePremiseLoaded(int? premId) {
    if (premId == null || premId == _lastPremId) return;
    _lastPremId = premId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPremise(premId);
    });
  }

  void _loadPremise(int premId) {
    _editKey = null;
    if (mounted) setState(() {});
    ref.read(categoriesControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premId = ref.watch(
      premisesControllerProvider.select((state) => state.selectedPremId),
    );
    final catState = ref.watch(categoriesControllerProvider);
    _ensurePremiseLoaded(premId);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== header =====
          const Text(
            'Categorías y Área de preparación',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Organiza las categorias del menú y las áreas de preparación',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent(catState)),
        ],
      ),
    );
  }

  Widget _buildContent(CategoriesState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(
          state.error!,
          style: const TextStyle(color: AppColors.red, fontSize: 14),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoriesSection(state.categories),
          const SizedBox(height: 28),
          _buildPreparationSection(state.preparationAreas, state.printerOptions),
        ],
      ),
    );
  }

  // ===========================================================================
  // Categories section
  // ===========================================================================

  Widget _buildCategoriesSection(List<Category> categories) {
    final creating = _editKey == 'cat-new';
    return _Section(
      title: 'Categorías',
      addLabel: 'Agregar categoría',
      onAdd: _editKey == null
          ? () => setState(() => _editKey = 'cat-new')
          : null,
      child: (categories.isEmpty && !creating)
          ? const _EmptyState(
              icon: Icons.category_outlined,
              title: 'Sin categorías',
              message: 'Esta sucursal aún no tiene categorías registradas.',
            )
          : _Card(
              minWidth: 700,
              children: [
                const _TableHeader(
                  columns: [
                    _Col('ORDEN', 14),
                    _Col('NOMBRE', 38),
                    _Col('PRODUCTOS', 20),
                    _Col('ESTADO', 18),
                    _Col('', 10),
                  ],
                ),
                for (final c in categories)
                  if (_editKey == 'cat-${c.prodcId}')
                    _CategoryEditRow(
                      key: ValueKey('cat-edit-${c.prodcId}'),
                      initialName: c.prodcName,
                      initialOrder: c.prodcOrder,
                      initialAvailable: c.prodcAvailable,
                      isNew: false,
                      saving: _saving,
                      onCancel: _cancelEdit,
                      onSave: (name, order, available) =>
                          _saveCategory(c.prodcId, name, order, available),
                    )
                  else
                    _CategoryRow(
                      category: c,
                      enabled: _editKey == null,
                      onEdit: () =>
                          setState(() => _editKey = 'cat-${c.prodcId}'),
                      onDelete: () => _deleteCategory(c),
                    ),
                if (creating)
                  _CategoryEditRow(
                    key: const ValueKey('cat-new'),
                    initialName: '',
                    initialOrder: _nextOrder(categories),
                    initialAvailable: true,
                    isNew: true,
                    saving: _saving,
                    onCancel: _cancelEdit,
                    onSave: (name, order, available) =>
                        _saveCategory(null, name, order, available),
                  ),
              ],
            ),
    );
  }

  int _nextOrder(List<Category> categories) {
    if (categories.isEmpty) return 1;
    return categories.map((c) => c.prodcOrder).reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<void> _saveCategory(
    int? id,
    String name,
    int order,
    bool available,
  ) async {
    if (name.trim().isEmpty) {
      _toast('El nombre es obligatorio.');
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(categoriesControllerProvider.notifier);
    final error = id == null
        ? await notifier.createCategory(name.trim(), order)
        : await notifier.updateCategory(id, name.trim(), order, available);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) _editKey = null;
    });
    if (error != null) _toast(error);
  }

  Future<void> _deleteCategory(Category c) async {
    if (c.prodCount > 0) {
      _toast(
        'Primero desvincula los productos ligados a "${c.prodcName}" '
        'antes de eliminar la categoría.',
      );
      return;
    }
    final ok = await _confirmDelete(
      'Eliminar categoría',
      '¿Seguro que quieres eliminar la categoría "${c.prodcName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(categoriesControllerProvider.notifier)
        .deleteCategory(c.prodcId);
    if (error != null) _toast(error);
  }

  // ===========================================================================
  // Preparation area section
  // ===========================================================================

  Widget _buildPreparationSection(
    List<PreparationArea> areas,
    List<PrinterOption> printerOptions,
  ) {
    final creating = _editKey == 'prep-new';
    return _Section(
      title: 'Área de preparación',
      addLabel: 'Agregar área',
      onAdd: _editKey == null
          ? () => setState(() => _editKey = 'prep-new')
          : null,
      child: (areas.isEmpty && !creating)
          ? const _EmptyState(
              icon: Icons.soup_kitchen_outlined,
              title: 'Sin áreas de preparación',
              message:
                  'Esta sucursal aún no tiene áreas de preparación registradas.',
            )
          : _Card(
              minWidth: 860,
              children: [
                const _TableHeader(
                  columns: [
                    _Col('NOMBRE', 20),
                    _Col('PRODUCTOS', 14),
                    _Col('IMPRESORA', 20),
                    _Col('IMPRESIÓN', 18),
                    _Col('ESTADO', 16),
                    _Col('', 12),
                  ],
                ),
                for (final a in areas)
                  if (_editKey == 'prep-${a.prepId}')
                    _PreparationEditRow(
                      key: ValueKey('prep-edit-${a.prepId}'),
                      initialName: a.prepName,
                      initialPrinterName: a.prinName,
                      initialPrintEnabled: a.prepPrintEnabled,
                      initialAvailable: a.prepAvailable,
                      printerOptions: printerOptions,
                      saving: _saving,
                      onCancel: _cancelEdit,
                      onSave: (name, printerId, printEnabled, available) =>
                          _savePreparation(
                        a.prepId,
                        name,
                        printerId,
                        printEnabled,
                        available,
                      ),
                    )
                  else
                    _PreparationRow(
                      area: a,
                      enabled: _editKey == null,
                      onEdit: () =>
                          setState(() => _editKey = 'prep-${a.prepId}'),
                      onDelete: () => _deletePreparation(a),
                      onTogglePrint: () => _togglePrint(a),
                      onToggleAvailable: () => _toggleAvailable(a),
                    ),
                if (creating)
                  _PreparationEditRow(
                    key: const ValueKey('prep-new'),
                    initialName: '',
                    initialPrinterName: '',
                    initialPrintEnabled: false,
                    initialAvailable: true,
                    printerOptions: printerOptions,
                    saving: _saving,
                    onCancel: _cancelEdit,
                    onSave: (name, printerId, printEnabled, available) =>
                        _savePreparation(
                      null,
                      name,
                      printerId,
                      printEnabled,
                      available,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _savePreparation(
    int? id,
    String name,
    int? printerId,
    bool printEnabled,
    bool available,
  ) async {
    if (name.trim().isEmpty) {
      _toast('El nombre es obligatorio.');
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(categoriesControllerProvider.notifier);
    final error = id == null
        ? await notifier.createPreparationArea(
            name.trim(),
            printerId,
            printEnabled,
            available,
          )
        : await notifier.updatePreparationArea(
            id,
            name.trim(),
            printerId,
            printEnabled,
            available,
          );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) _editKey = null;
    });
    if (error != null) _toast(error);
  }

  Future<void> _togglePrint(PreparationArea a) async {
    final error = await ref
        .read(categoriesControllerProvider.notifier)
        .togglePrintEnabled(a.prepId);
    if (error != null) _toast(error);
  }

  Future<void> _toggleAvailable(PreparationArea a) async {
    final error = await ref
        .read(categoriesControllerProvider.notifier)
        .toggleAvailable(a.prepId);
    if (error != null) _toast(error);
  }

  Future<void> _deletePreparation(PreparationArea a) async {
    if (a.prodCount > 0) {
      _toast(
        'Primero desvincula los productos ligados a "${a.prepName}" '
        'antes de eliminar el área de preparación.',
      );
      return;
    }
    final ok = await _confirmDelete(
      'Eliminar área de preparación',
      '¿Seguro que quieres eliminar el área "${a.prepName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(categoriesControllerProvider.notifier)
        .deletePreparationArea(a.prepId);
    if (error != null) _toast(error);
  }

  // ===== shared helpers =====================================================

  void _cancelEdit() => setState(() => _editKey = null);

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmDelete(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Section wrapper (title + "add" action + child)
// ===========================================================================

class _Section extends StatelessWidget {
  final String title;
  final String addLabel;
  final VoidCallback? onAdd;
  final Widget child;

  const _Section({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final double minWidth;
  final List<Widget> children;
  const _Card({required this.minWidth, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ScrollableTable(
        minWidth: minWidth,
        child: Column(children: children),
      ),
    );
  }
}

// ===========================================================================
// Table header
// ===========================================================================

class _Col {
  final String label;
  final int flex;
  const _Col(this.label, this.flex);
}

class _TableHeader extends StatelessWidget {
  final List<_Col> columns;
  const _TableHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: AppColors.ink3,
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: Text(c.label, style: style),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Category rows
// ===========================================================================

class _CategoryRow extends StatelessWidget {
  final Category category;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.category,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${category.prodcOrder}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 38,
            child: Text(
              category.prodcName,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              '${category.prodCount} '
              '${category.prodCount == 1 ? 'producto' : 'productos'}',
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AvailabilityChip(available: category.prodcAvailable),
            ),
          ),
          Expanded(
            flex: 10,
            child: _RowActions(
              enabled: enabled,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryEditRow extends StatefulWidget {
  final String initialName;
  final int initialOrder;
  final bool initialAvailable;
  final bool isNew;
  final bool saving;
  final VoidCallback onCancel;
  final void Function(String name, int order, bool available) onSave;

  const _CategoryEditRow({
    super.key,
    required this.initialName,
    required this.initialOrder,
    required this.initialAvailable,
    required this.isNew,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_CategoryEditRow> createState() => _CategoryEditRowState();
}

class _CategoryEditRowState extends State<_CategoryEditRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _order = TextEditingController(
    text: '${widget.initialOrder}',
  );
  late bool _available = widget.initialAvailable;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  void _submit() => widget.onSave(
    _name.text,
    int.tryParse(_order.text.trim()) ?? 0,
    _available,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 14,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CellField(
                controller: _order,
                hint: 'Orden',
                numeric: true,
              ),
            ),
          ),
          Expanded(
            flex: 38,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CellField(
                controller: _name,
                hint: 'Nombre',
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const Expanded(flex: 20, child: SizedBox.shrink()),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.isNew
                  ? const SizedBox.shrink()
                  : _StatusToggle(
                      available: _available,
                      onChanged: (v) => setState(() => _available = v),
                    ),
            ),
          ),
          Expanded(
            flex: 10,
            child: _EditActions(
              saving: widget.saving,
              onSave: _submit,
              onCancel: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Preparation area rows
// ===========================================================================

class _PreparationRow extends StatelessWidget {
  final PreparationArea area;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePrint;
  final VoidCallback onToggleAvailable;

  const _PreparationRow({
    required this.area,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePrint,
    required this.onToggleAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final printEnabled = area.prepPrintEnabled;
    final available = area.prepAvailable;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 20,
            child: Text(
              area.prepName,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(
              '${area.prodCount} '
              '${area.prodCount == 1 ? 'producto' : 'productos'}',
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: 20,
            child: Row(
              children: [
                const Icon(
                  Icons.print_outlined,
                  size: 15,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    area.prinName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 18,
            child: Row(
              children: [
                _Toggle(on: printEnabled, onChanged: (_) => onTogglePrint()),
                const SizedBox(width: 10),
                Text(
                  printEnabled ? 'Habilitada' : 'Deshabilitada',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: printEnabled ? AppColors.greenInk : AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 16,
            child: Row(
              children: [
                _Toggle(on: available, onChanged: (_) => onToggleAvailable()),
                const SizedBox(width: 10),
                Text(
                  available ? 'Activa' : 'Inactiva',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: available ? AppColors.greenInk : AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: _RowActions(
              enabled: enabled,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationEditRow extends StatefulWidget {
  final String initialName;
  final String initialPrinterName;
  final bool initialPrintEnabled;
  final bool initialAvailable;
  final List<PrinterOption> printerOptions;
  final bool saving;
  final VoidCallback onCancel;
  final void Function(
    String name,
    int? printerId,
    bool printEnabled,
    bool available,
  )
  onSave;

  const _PreparationEditRow({
    super.key,
    required this.initialName,
    required this.initialPrinterName,
    required this.initialPrintEnabled,
    required this.initialAvailable,
    required this.printerOptions,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_PreparationEditRow> createState() => _PreparationEditRowState();
}

class _PreparationEditRowState extends State<_PreparationEditRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late int? _printerId = _resolveInitialPrinterId();
  late bool _printEnabled = widget.initialPrintEnabled;
  late bool _available = widget.initialAvailable;

  /// Matches the area's stored `prin_name` against the registered printer
  /// list to find its id. No match (e.g. an empty/unassigned `prin_name`)
  /// resolves to `null` — no printer selected.
  int? _resolveInitialPrinterId() {
    for (final option in widget.printerOptions) {
      if (option.prinName == widget.initialPrinterName) return option.prinId;
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() =>
      widget.onSave(_name.text, _printerId, _printEnabled, _available);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 20,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CellField(
                controller: _name,
                hint: 'Nombre',
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const Expanded(flex: 14, child: SizedBox.shrink()),
          Expanded(
            flex: 20,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _PrinterPicker(
                value: _printerId,
                options: widget.printerOptions,
                onChanged: (v) => setState(() => _printerId = v),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Toggle(
                on: _printEnabled,
                onChanged: (v) => setState(() => _printEnabled = v),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Toggle(
                on: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: _EditActions(
              saving: widget.saving,
              onSave: _submit,
              onCancel: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Printer picker (preparation area printer assignment)
// ===========================================================================

class _PrinterPicker extends StatelessWidget {
  /// Selected printer id, or `null` when it doesn't match any of the
  /// registered printers returned by the service.
  final int? value;
  final List<PrinterOption> options;
  final ValueChanged<int?> onChanged;

  const _PrinterPicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  String get _valueLabel {
    for (final option in options) {
      if (option.prinId == value) return option.prinName;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return PopupMenuButton<int?>(
          onSelected: onChanged,
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.line),
          ),
          constraints: BoxConstraints(minWidth: width, maxWidth: width),
          itemBuilder: (context) => [
            for (final option in options)
              _printerMenuItem(id: option.prinId, name: option.prinName),
          ],
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _valueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, size: 18, color: AppColors.ink3),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<int?> _printerMenuItem({required int? id, required String name}) {
    return PopupMenuItem<int?>(
      value: id,
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 13.5)),
          ),
          if (id == value)
            const Icon(Icons.check, size: 16, color: AppColors.greenInk),
        ],
      ),
    );
  }
}

// ===========================================================================
// Toggle (matches the design's green pill switch)
// ===========================================================================

class _Toggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: on ? AppColors.green : const Color(0xFFD4DAE3),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared small widgets
// ===========================================================================

class _CellField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool numeric;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const _CellField({
    required this.controller,
    required this.hint,
    this.numeric = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RowActions({
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconBtn(
          icon: Icons.edit_outlined,
          color: AppColors.ink3,
          tooltip: 'Editar',
          onPressed: enabled ? onEdit : null,
        ),
        _IconBtn(
          icon: Icons.delete_outline,
          color: AppColors.red,
          tooltip: 'Eliminar',
          onPressed: enabled ? onDelete : null,
        ),
      ],
    );
  }
}

class _EditActions extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditActions({
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconBtn(
          icon: Icons.check,
          color: AppColors.green,
          tooltip: 'Guardar',
          onPressed: onSave,
        ),
        _IconBtn(
          icon: Icons.close,
          color: AppColors.ink3,
          tooltip: 'Cancelar',
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 19),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;
  const _AvailabilityChip({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? AppColors.available.withValues(alpha: 0.12)
            : AppColors.unavailable.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        available ? 'Activa' : 'Inactiva',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: available ? AppColors.available : AppColors.unavailable,
        ),
      ),
    );
  }
}

/// Tappable variant of [_AvailabilityChip] used while editing a category.
/// Toggles between the two possible `prodc_available` values (true/false).
class _StatusToggle extends StatelessWidget {
  final bool available;
  final ValueChanged<bool> onChanged;

  const _StatusToggle({required this.available, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.available : AppColors.unavailable;
    return InkWell(
      onTap: () => onChanged(!available),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              available ? 'Activa' : 'Inactiva',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.ink4),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
