import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/printers/controllers/printers_controller.dart';
import 'package:ds_clickeat_web_admin/features/printers/models/printer.dart';

const _connectionLabels = {
  'NETWORK': 'Red',
  'USB': 'USB',
  'WINDOWS': 'Windows',
};

const _connectionIcons = {
  'NETWORK': Icons.wifi,
  'USB': Icons.usb,
  'WINDOWS': Icons.desktop_windows_outlined,
};

String _connectionDetail(Printer p) {
  switch (p.prinConnectionType) {
    case 'NETWORK':
      final ip = p.prinIp ?? '';
      final port = p.prinPort;
      return port != null ? '$ip:$port' : ip;
    case 'WINDOWS':
      return p.prinWindowsName ?? '';
    default:
      return 'Conectada por USB';
  }
}

String _usageLabel(String usageType) =>
    usageType == 'RECEIPT' ? 'Recibo' : usageType;

/// M3's default `SegmentedButton` selected color comes from
/// `colorScheme.secondaryContainer`, which the navy seed derives as a
/// lavender tone rather than navy — override it so selection reads as navy
/// everywhere, matching the rest of the design system.
final _segmentedButtonStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.selected) ? AppColors.navy : AppColors.surface,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? Colors.white
        : AppColors.ink2,
  ),
  iconColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? Colors.white
        : AppColors.ink3,
  ),
  side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
  overlayColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.navy.withValues(alpha: 0.06),
  ),
);

class PrintersPage extends ConsumerStatefulWidget {
  const PrintersPage({super.key});

  @override
  ConsumerState<PrintersPage> createState() => _PrintersPageState();
}

class _PrintersPageState extends ConsumerState<PrintersPage> {
  int? _lastPremId;

  void _ensurePremiseLoaded(int? premId) {
    if (premId == null || premId == _lastPremId) return;
    _lastPremId = premId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPremise(premId);
    });
  }

  void _loadPremise(int premId) {
    ref.read(printersControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premState = ref.watch(premisesControllerProvider);
    final state = ref.watch(printersControllerProvider);
    final premId = premState.selectedPremId;
    _ensurePremiseLoaded(premId);

    final total = state.printers.length;
    final active = state.printers.where((p) => p.prinIsActive).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== header =====
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Impresoras',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$active de $total '
                      '${total == 1 ? 'impresora activa' : 'impresoras activas'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: premId == null ? null : () => _create(premId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Impresora'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.navy.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white70,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent(premId, state)),
        ],
      ),
    );
  }

  Widget _buildContent(int? premId, PrintersState state) {
    if (premId == null) return const SizedBox.shrink();
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
    if (state.printers.isEmpty) {
      return const _EmptyState(
        icon: Icons.print_outlined,
        title: 'Sin impresoras',
        message: 'Agrega una impresora para esta sucursal.',
      );
    }

    return _PrintersTable(
      printers: state.printers,
      onToggleActive: (p) => _toggleActive(premId, p),
      onSetDefault: (p) => _setDefault(premId, p),
      onEdit: (p) => _edit(premId, p),
      onDelete: (p) => _delete(premId, p),
      onTestPrint: (p) => _testPrint(premId, p),
    );
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _create(int premId) async {
    final result = await _showEditor(title: 'Nueva impresora');
    if (result == null) return;
    final error = await ref
        .read(printersControllerProvider.notifier)
        .createPrinter(
          premId,
          name: result.name,
          connectionType: result.connectionType,
          usageType: result.usageType,
          ip: result.ip,
          port: result.port,
          windowsName: result.windowsName,
          paperWidth: result.paperWidth,
          autoCut: result.autoCut,
          beep: result.beep,
          isDefault: result.isDefault,
          isActive: result.isActive,
        );
    if (error != null) _toast(error);
  }

  Future<void> _edit(int premId, Printer printer) async {
    final result = await _showEditor(title: 'Editar impresora', printer: printer);
    if (result == null) return;
    final error = await ref
        .read(printersControllerProvider.notifier)
        .updatePrinter(
          premId,
          printer.prinId,
          name: result.name,
          connectionType: result.connectionType,
          usageType: result.usageType,
          ip: result.ip,
          port: result.port,
          windowsName: result.windowsName,
          paperWidth: result.paperWidth,
          autoCut: result.autoCut,
          beep: result.beep,
          isDefault: result.isDefault,
          isActive: result.isActive,
        );
    if (error != null) _toast(error);
  }

  Future<void> _delete(int premId, Printer printer) async {
    final ok = await _confirmDelete(
      'Eliminar impresora',
      '¿Seguro que quieres eliminar "${printer.prinName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(printersControllerProvider.notifier)
        .deletePrinter(premId, printer.prinId);
    if (error != null) _toast(error);
  }

  Future<void> _toggleActive(int premId, Printer printer) async {
    final error = await ref
        .read(printersControllerProvider.notifier)
        .toggleActive(premId, printer);
    if (error != null) _toast(error);
  }

  Future<void> _setDefault(int premId, Printer printer) async {
    if (printer.prinIsDefault) return;
    final error = await ref
        .read(printersControllerProvider.notifier)
        .updatePrinter(
          premId,
          printer.prinId,
          name: printer.prinName,
          connectionType: printer.prinConnectionType,
          usageType: printer.prinUsageType,
          ip: printer.prinIp,
          port: printer.prinPort,
          windowsName: printer.prinWindowsName,
          paperWidth: printer.prinPaperWidth,
          autoCut: printer.prinAutoCut,
          beep: printer.prinBeep,
          isDefault: true,
          isActive: printer.prinIsActive,
        );
    if (error != null) _toast(error);
  }

  Future<String?> _testPrint(int premId, Printer printer) {
    return ref.read(printersControllerProvider.notifier).testPrint(premId, printer);
  }

  // ===== shared helpers =====================================================

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

  Future<_PrinterFormResult?> _showEditor({
    required String title,
    Printer? printer,
  }) {
    return showDialog<_PrinterFormResult>(
      context: context,
      builder: (ctx) => _PrinterEditor(title: title, printer: printer),
    );
  }
}

// ===========================================================================
// Printers table
// ===========================================================================

class _Col {
  final String label;
  final int flex;
  const _Col(this.label, this.flex);
}

const _kActionsColWidth = 96.0;
const _kTestPrintColWidth = 170.0;

class _PrintersTable extends StatelessWidget {
  final List<Printer> printers;
  final void Function(Printer) onToggleActive;
  final void Function(Printer) onSetDefault;
  final void Function(Printer) onEdit;
  final void Function(Printer) onDelete;
  final Future<String?> Function(Printer) onTestPrint;

  const _PrintersTable({
    required this.printers,
    required this.onToggleActive,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
    required this.onTestPrint,
  });

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
        minWidth: 900 + _kTestPrintColWidth,
        child: Column(
          children: [
            const _PrintersTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: printers.length,
                itemBuilder: (context, index) {
                  final printer = printers[index];
                  return _PrinterRow(
                    printer: printer,
                    last: index == printers.length - 1,
                    onToggleActive: () => onToggleActive(printer),
                    onSetDefault: () => onSetDefault(printer),
                    onEdit: () => onEdit(printer),
                    onDelete: () => onDelete(printer),
                    onTestPrint: () => onTestPrint(printer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
  color: AppColors.ink3,
);

class _PrintersTableHeader extends StatelessWidget {
  const _PrintersTableHeader();

  static const _columns = [
    _Col('NOMBRE', 22),
    _Col('CONEXIÓN', 28),
    _Col('USO', 16),
    _Col('PAPEL', 10),
    _Col('PREDETERMINADA', 16),
    _Col('ESTADO', 14),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          for (final c in _columns)
            Expanded(flex: c.flex, child: Text(c.label, style: _headerStyle)),
          SizedBox(
            width: _kActionsColWidth,
            child: const Text(
              'ACCIONES',
              style: _headerStyle,
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: _kTestPrintColWidth,
            child: const Text(
              'PRUEBA',
              style: _headerStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterRow extends StatelessWidget {
  final Printer printer;
  final bool last;
  final VoidCallback onToggleActive;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<String?> Function() onTestPrint;

  const _PrinterRow({
    required this.printer,
    required this.last,
    required this.onToggleActive,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
    required this.onTestPrint,
  });

  @override
  Widget build(BuildContext context) {
    final active = printer.prinIsActive;
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 22,
            child: Text(
              printer.prinName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Row(
              children: [
                Icon(
                  _connectionIcons[printer.prinConnectionType] ??
                      Icons.print_outlined,
                  size: 16,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _connectionLabels[printer.prinConnectionType] ??
                            printer.prinConnectionType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        _connectionDetail(printer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              _usageLabel(printer.prinUsageType),
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              '${printer.prinPaperWidth}mm',
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: 16,
            child: _DefaultBadge(
              isDefault: printer.prinIsDefault,
              onTap: printer.prinIsDefault ? null : onSetDefault,
            ),
          ),
          Expanded(
            flex: 14,
            child: Row(
              children: [
                _Toggle(on: active, onChanged: (_) => onToggleActive()),
                const SizedBox(width: 10),
                Text(
                  active ? 'Activa' : 'Inactiva',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.greenInk : AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _kActionsColWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _IconBtn(
                  icon: Icons.edit_outlined,
                  color: AppColors.ink3,
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                _IconBtn(
                  icon: Icons.delete_outline,
                  color: AppColors.red,
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          SizedBox(
            width: _kTestPrintColWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: _TestPrintButton(onPressed: onTestPrint),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestPrintButton extends StatefulWidget {
  final Future<String?> Function() onPressed;

  const _TestPrintButton({required this.onPressed});

  @override
  State<_TestPrintButton> createState() => _TestPrintButtonState();
}

class _TestPrintButtonState extends State<_TestPrintButton> {
  bool _sending = false;

  Future<void> _handleTap() async {
    if (_sending) return;
    setState(() => _sending = true);
    final error = await widget.onPressed();
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Prueba de impresión enviada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _sending ? null : _handleTap,
      icon: _sending
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined, size: 16),
      label: const Text('Imprimir prueba'),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  final bool isDefault;
  final VoidCallback? onTap;

  const _DefaultBadge({required this.isDefault, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isDefault ? AppColors.gold : AppColors.ink4;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDefault ? Icons.star : Icons.star_border,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              isDefault ? 'Predeterminada' : 'Marcar',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDefault ? AppColors.ink2 : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

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
// Editor dialog
// ===========================================================================

class _PrinterFormResult {
  final String name;
  final String connectionType;
  final String usageType;
  final String? ip;
  final int? port;
  final String? windowsName;
  final int paperWidth;
  final bool autoCut;
  final bool beep;
  final bool isDefault;
  final bool isActive;

  const _PrinterFormResult({
    required this.name,
    required this.connectionType,
    required this.usageType,
    this.ip,
    this.port,
    this.windowsName,
    required this.paperWidth,
    required this.autoCut,
    required this.beep,
    required this.isDefault,
    required this.isActive,
  });
}

class _PrinterEditor extends StatefulWidget {
  final String title;
  final Printer? printer;

  const _PrinterEditor({required this.title, this.printer});

  @override
  State<_PrinterEditor> createState() => _PrinterEditorState();
}

class _PrinterEditorState extends State<_PrinterEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.printer?.prinName ?? '',
  );
  late final TextEditingController _ip = TextEditingController(
    text: widget.printer?.prinIp ?? '',
  );
  late final TextEditingController _port = TextEditingController(
    text: '${widget.printer?.prinPort ?? 9100}',
  );
  late final TextEditingController _windowsName = TextEditingController(
    text: widget.printer?.prinWindowsName ?? '',
  );
  late final TextEditingController _customUsage = TextEditingController(
    text: (widget.printer != null && widget.printer!.prinUsageType != 'RECEIPT')
        ? widget.printer!.prinUsageType
        : '',
  );

  late String _connectionType =
      widget.printer?.prinConnectionType == 'WINDOWS'
          ? 'USB'
          : (widget.printer?.prinConnectionType ?? 'NETWORK');
  late bool _isCustomUsage =
      widget.printer != null && widget.printer!.prinUsageType != 'RECEIPT';
  late int _paperWidth = widget.printer?.prinPaperWidth ?? 80;
  late bool _autoCut = widget.printer?.prinAutoCut ?? true;
  late bool _beep = widget.printer?.prinBeep ?? true;
  late bool _isDefault = widget.printer?.prinIsDefault ?? false;
  late bool _isActive = widget.printer?.prinIsActive ?? true;

  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _ip.dispose();
    _port.dispose();
    _windowsName.dispose();
    _customUsage.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    if (_connectionType == 'NETWORK' && _ip.text.trim().isEmpty) {
      setState(() => _error = 'La IP es obligatoria para conexión de red.');
      return;
    }
    if (_connectionType == 'USB' && _windowsName.text.trim().isEmpty) {
      setState(
        () => _error = 'El nombre de impresora de Windows es obligatorio.',
      );
      return;
    }
    if (_isCustomUsage && _customUsage.text.trim().isEmpty) {
      setState(() => _error = 'Especifica el área de uso.');
      return;
    }

    Navigator.of(context).pop(
      _PrinterFormResult(
        name: name,
        connectionType: _connectionType,
        usageType: _isCustomUsage ? _customUsage.text.trim() : 'RECEIPT',
        ip: _connectionType == 'NETWORK' ? _ip.text.trim() : null,
        port: _connectionType == 'NETWORK'
            ? (int.tryParse(_port.text.trim()) ?? 9100)
            : null,
        windowsName: _connectionType == 'USB'
            ? _windowsName.text.trim()
            : null,
        paperWidth: _paperWidth,
        autoCut: _autoCut,
        beep: _beep,
        isDefault: _isDefault,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Nombre'),
              const SizedBox(height: 8),
              _TextInput(
                controller: _name,
                hint: 'Ej. Impresora Principal',
                autofocus: true,
                onChanged: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Tipo de conexión'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'NETWORK',
                    label: Text('Red'),
                    icon: Icon(Icons.wifi, size: 16),
                  ),
                  ButtonSegment(
                    value: 'USB',
                    label: Text('USB'),
                    icon: Icon(Icons.usb, size: 16),
                  ),
                ],
                selected: {_connectionType},
                onSelectionChanged: (s) =>
                    setState(() => _connectionType = s.first),
                style: _segmentedButtonStyle,
              ),
              if (_connectionType == 'NETWORK') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('IP'),
                          const SizedBox(height: 8),
                          _TextInput(controller: _ip, hint: '192.168.1.100'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Puerto'),
                          const SizedBox(height: 8),
                          _TextInput(
                            controller: _port,
                            hint: '9100',
                            numeric: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else if (_connectionType == 'USB') ...[
                const SizedBox(height: 14),
                const _FieldLabel('Nombre de impresora en Windows'),
                const SizedBox(height: 8),
                _TextInput(
                  controller: _windowsName,
                  hint: 'Ej. EPSON TM-T88 Receipt',
                ),
              ],
              const SizedBox(height: 18),
              const _FieldLabel('Tipo de uso'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Recibo')),
                  ButtonSegment(value: true, label: Text('Otra área')),
                ],
                selected: {_isCustomUsage},
                onSelectionChanged: (s) =>
                    setState(() => _isCustomUsage = s.first),
                style: _segmentedButtonStyle,
              ),
              if (_isCustomUsage) ...[
                const SizedBox(height: 10),
                _TextInput(
                  controller: _customUsage,
                  hint: 'Ej. Cocina, Barra, Comandas',
                ),
              ],
              const SizedBox(height: 18),
              const _FieldLabel('Ancho de papel'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 58, label: Text('58mm')),
                  ButtonSegment(value: 80, label: Text('80mm')),
                ],
                selected: {_paperWidth},
                onSelectionChanged: (s) =>
                    setState(() => _paperWidth = s.first),
                style: _segmentedButtonStyle,
              ),
              const SizedBox(height: 18),
              _ToggleRow(
                label: 'Corte automático',
                value: _autoCut,
                onChanged: (v) => setState(() => _autoCut = v),
              ),
              const SizedBox(height: 10),
              _ToggleRow(
                label: 'Sonido (beep)',
                value: _beep,
                onChanged: (v) => setState(() => _beep = v),
              ),
              const SizedBox(height: 10),
              _ToggleRow(
                label: 'Impresora predeterminada',
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 10),
              _ToggleRow(
                label: 'Activa',
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool numeric;
  final bool autofocus;
  final VoidCallback? onChanged;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.numeric = false,
    this.autofocus = false,
    this.onChanged,
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
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
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

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        _Toggle(on: value, onChanged: onChanged),
      ],
    );
  }
}

// ===========================================================================
// Empty state
// ===========================================================================

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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.ink4),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
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
