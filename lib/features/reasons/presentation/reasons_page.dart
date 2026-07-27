import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/reasons/controllers/reasons_controller.dart';
import 'package:ds_clickeat_web_admin/features/reasons/models/cancel_reason.dart';

class ReasonsPage extends ConsumerStatefulWidget {
  const ReasonsPage({super.key});

  @override
  ConsumerState<ReasonsPage> createState() => _ReasonsPageState();
}

class _ReasonsPageState extends ConsumerState<ReasonsPage> {
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
    ref.read(reasonsControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premState = ref.watch(premisesControllerProvider);
    final state = ref.watch(reasonsControllerProvider);
    final premId = premState.selectedPremId;
    _ensurePremiseLoaded(premId);

    final total = state.reasons.length;
    final available = state.availableCount;

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
                      'Razones de cancelación',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$available de $total '
                      '${total == 1 ? 'razón activa' : 'razones activas'}',
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
                label: const Text('Razón'),
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

  Widget _buildContent(int? premId, ReasonsState state) {
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
    if (state.reasons.isEmpty) {
      return const _EmptyState(
        icon: Icons.block_outlined,
        title: 'Sin razones de cancelación',
        message: 'Agrega una razón de cancelación para esta sucursal.',
      );
    }

    return _ReasonsTable(
      reasons: state.reasons,
      onToggle: (r) => _toggle(premId, r),
      onEdit: (r) => _edit(premId, r),
      onDelete: (r) => _delete(premId, r),
    );
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _create(int premId) async {
    final result = await _showEditor(title: 'Nueva razón de cancelación');
    if (result == null) return;
    final error = await ref
        .read(reasonsControllerProvider.notifier)
        .createReason(premId, result.name);
    if (error != null) _toast(error);
  }

  Future<void> _edit(int premId, CancelReason reason) async {
    final result = await _showEditor(
      title: 'Editar razón de cancelación',
      initialName: reason.reasName,
      initialAvailable: reason.reasAvailable,
      showAvailability: true,
    );
    if (result == null) return;
    final error = await ref
        .read(reasonsControllerProvider.notifier)
        .updateReason(premId, reason.reasId, result.name, result.available);
    if (error != null) _toast(error);
  }

  Future<void> _delete(int premId, CancelReason reason) async {
    final ok = await _confirmDelete(
      'Eliminar razón de cancelación',
      '¿Seguro que quieres eliminar "${reason.reasName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(reasonsControllerProvider.notifier)
        .deleteReason(premId, reason.reasId);
    if (error != null) _toast(error);
  }

  Future<void> _toggle(int premId, CancelReason reason) async {
    final error = await ref
        .read(reasonsControllerProvider.notifier)
        .toggleAvailable(premId, reason);
    if (error != null) _toast(error);
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
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
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

  Future<({String name, bool available})?> _showEditor({
    required String title,
    String initialName = '',
    bool initialAvailable = true,
    bool showAvailability = false,
  }) {
    return showDialog<({String name, bool available})>(
      context: context,
      builder: (ctx) => _ReasonEditor(
        title: title,
        initialName: initialName,
        initialAvailable: initialAvailable,
        showAvailability: showAvailability,
      ),
    );
  }
}

// ===========================================================================
// Reasons table
// ===========================================================================

/// Fixed widths for the non-flexible columns; the name column flexes.
const double _kStatusColWidth = 150;
const double _kActionsColWidth = 96;

class _ReasonsTable extends StatelessWidget {
  final List<CancelReason> reasons;
  final void Function(CancelReason) onToggle;
  final void Function(CancelReason) onEdit;
  final void Function(CancelReason) onDelete;

  const _ReasonsTable({
    required this.reasons,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
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
        minWidth: 560,
        child: Column(
          children: [
            const _ReasonsTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: reasons.length,
                itemBuilder: (context, index) {
                  final reason = reasons[index];
                  return _ReasonRow(
                    reason: reason,
                    last: index == reasons.length - 1,
                    onToggle: () => onToggle(reason),
                    onEdit: () => onEdit(reason),
                    onDelete: () => onDelete(reason),
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

class _ReasonsTableHeader extends StatelessWidget {
  const _ReasonsTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Row(
        children: [
          Expanded(child: Text('RAZÓN', style: _headerStyle)),
          SizedBox(
            width: _kStatusColWidth,
            child: Text('ESTADO', style: _headerStyle),
          ),
          SizedBox(
            width: _kActionsColWidth,
            child: Text(
              'ACCIONES',
              style: _headerStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
  color: AppColors.ink3,
);

class _ReasonRow extends StatelessWidget {
  final CancelReason reason;
  final bool last;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReasonRow({
    required this.reason,
    required this.last,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final available = reason.reasAvailable;
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
            child: Text(
              reason.reasName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          SizedBox(
            width: _kStatusColWidth,
            child: Row(
              children: [
                _Toggle(on: available, onChanged: (_) => onToggle()),
                const SizedBox(width: 10),
                Text(
                  available ? 'Disponible' : 'No disponible',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: available ? AppColors.greenInk : AppColors.ink3,
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
        ],
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
// Editor dialog (name + optional availability)
// ===========================================================================

class _ReasonEditor extends StatefulWidget {
  final String title;
  final String initialName;
  final bool initialAvailable;
  final bool showAvailability;

  const _ReasonEditor({
    required this.title,
    required this.initialName,
    required this.initialAvailable,
    required this.showAvailability,
  });

  @override
  State<_ReasonEditor> createState() => _ReasonEditorState();
}

class _ReasonEditorState extends State<_ReasonEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late bool _available = widget.initialAvailable;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    Navigator.of(context).pop((name: name, available: _available));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nombre',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Ej. Sin stock suficiente',
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
                borderSide: BorderSide(
                  color: _error != null ? AppColors.red : AppColors.line,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _error != null ? AppColors.red : AppColors.navy,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.red),
            ),
          ],
          if (widget.showAvailability) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disponible',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _available
                            ? 'Visible al cancelar'
                            : 'Oculto al cancelar',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                _Toggle(
                  on: _available,
                  onChanged: (v) => setState(() => _available = v),
                ),
              ],
            ),
          ],
        ],
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
