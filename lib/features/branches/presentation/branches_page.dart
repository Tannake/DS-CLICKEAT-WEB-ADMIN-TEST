import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/branches/controllers/branches_controller.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_detail.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_schedule.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_summary.dart';

class BranchesPage extends ConsumerStatefulWidget {
  const BranchesPage({super.key});

  @override
  ConsumerState<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends ConsumerState<BranchesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(branchesControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(branchesControllerProvider);
    final total = state.branches.length;
    final available = state.availableCount;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== header =====
          const Text(
            'Sucursales',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0
                ? 'Administra las sucursales de tu negocio'
                : '$available de $total '
                    '${total == 1 ? 'sucursal activa' : 'sucursales activas'}',
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent(state)),
        ],
      ),
    );
  }

  Widget _buildContent(BranchesState state) {
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
    if (state.branches.isEmpty) {
      return const _EmptyState(
        icon: Icons.store_outlined,
        title: 'Sin sucursales',
        message: 'No hay sucursales asociadas a tu cuenta.',
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final branch in state.branches)
            _BranchCard(
              branch: branch,
              onTap: () => _openDetail(branch.premId),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _openDetail(int premId) async {
    final detail = await _withLoader(
      () => ref.read(branchesControllerProvider.notifier).fetchDetail(premId),
    );
    if (!mounted) return;
    if (detail == null) {
      _toast('No se pudo cargar la sucursal.');
      return;
    }

    final result = await showDialog<({BranchDetail detail, String password})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BranchEditor(detail: detail),
    );
    if (result == null || !mounted) return;

    final error = await ref
        .read(branchesControllerProvider.notifier)
        .save(result.detail, result.password);
    if (!mounted) return;
    _toast(error ?? 'Sucursal actualizada.');
  }

  /// Runs [task] behind a blocking spinner dialog.
  Future<T> _withLoader<T>(Future<T> Function() task) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ===========================================================================
// Branch card
// ===========================================================================

class _BranchCard extends StatelessWidget {
  final BranchSummary branch;
  final VoidCallback onTap;

  const _BranchCard({required this.branch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = branch.premAvailable;
    return SizedBox(
      width: 320,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        branch.premName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusPill(available: available),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.place_outlined,
                  text: branch.premAddress.isEmpty
                      ? 'Sin dirección'
                      : branch.premAddress,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                        icon: Icons.location_city_outlined,
                        text: branch.premCity.isEmpty
                            ? 'Sin ciudad'
                            : branch.premCity,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.table_restaurant_outlined,
                      size: 16,
                      color: AppColors.ink3,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${branch.premNumberTable} mesas',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.ink3),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool available;

  const _StatusPill({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? AppColors.green.withValues(alpha: 0.12)
            : AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        available ? 'Activa' : 'Inactiva',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: available ? AppColors.greenInk : AppColors.redInk,
        ),
      ),
    );
  }
}

// ===========================================================================
// Editor dialog
// ===========================================================================

class _BranchEditor extends StatefulWidget {
  final BranchDetail detail;

  const _BranchEditor({required this.detail});

  @override
  State<_BranchEditor> createState() => _BranchEditorState();
}

/// The sentinel placeholder pre-filled in the password fields. While both
/// fields still hold it, the password is treated as unchanged (sent as '').
const String _kPasswordSentinel = '********';

class _BranchEditorState extends State<_BranchEditor> {
  late final _name = TextEditingController(text: widget.detail.premName);
  late final _address = TextEditingController(text: widget.detail.premAddress);
  late final _city = TextEditingController(text: widget.detail.premCity);
  late final _stateCtl = TextEditingController(text: widget.detail.premState);
  late final _latitud = TextEditingController(text: widget.detail.premLatitud);
  late final _longitud =
      TextEditingController(text: widget.detail.premLongitud);
  late final _statement =
      TextEditingController(text: widget.detail.premStatementDescriptor);
  late final _numberTable = TextEditingController(
    text: widget.detail.premNumberTable.toString(),
  );
  late final _pickUpCost =
      TextEditingController(text: widget.detail.premPickUpCost);
  final _password = TextEditingController(text: _kPasswordSentinel);
  final _confirm = TextEditingController(text: _kPasswordSentinel);

  late bool _available = widget.detail.premAvailable;
  late bool _pickUp = widget.detail.premPickUp;
  late bool _pickUpMandatory = widget.detail.premPickUpMandatory;
  bool _obscure = true;

  /// Working copy of the weekly schedule, ordered Monday-first.
  late final List<BranchSchedule> _schedules = [...widget.detail.horarios]
    ..sort((a, b) => a.weekdayOrder.compareTo(b.weekdayOrder));

  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _stateCtl.dispose();
    _latitud.dispose();
    _longitud.dispose();
    _statement.dispose();
    _numberTable.dispose();
    _pickUpCost.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Returns the password to send, or throws a `_ValidationError` describing
  /// the problem. An untouched (sentinel) password yields ''.
  String _resolvePassword() {
    final pwd = _password.text;
    final confirm = _confirm.text;
    final untouched = pwd == _kPasswordSentinel && confirm == _kPasswordSentinel;
    if (untouched || (pwd.isEmpty && confirm.isEmpty)) return '';

    if (pwd != confirm) {
      throw const _ValidationError('Las contraseñas no coinciden.');
    }
    if (pwd.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(pwd) ||
        !RegExp(r'[a-z]').hasMatch(pwd) ||
        !RegExp(r'[0-9]').hasMatch(pwd)) {
      throw const _ValidationError(
        'La contraseña debe tener al menos 8 caracteres, '
        'mayúsculas, minúsculas y un número.',
      );
    }
    return pwd;
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    final tables = int.tryParse(_numberTable.text.trim());
    if (tables == null || tables < 0) {
      setState(() => _error = 'El número de mesas no es válido.');
      return;
    }
    final cost = _pickUpCost.text.trim().isEmpty
        ? '0.00'
        : _pickUpCost.text.trim();
    if (double.tryParse(cost) == null) {
      setState(() => _error = 'El costo de recolección no es válido.');
      return;
    }

    final String password;
    try {
      password = _resolvePassword();
    } on _ValidationError catch (e) {
      setState(() => _error = e.message);
      return;
    }

    final updated = widget.detail.copyWith(
      premName: name,
      premAddress: _address.text.trim(),
      premCity: _city.text.trim(),
      premState: _stateCtl.text.trim(),
      premLatitud: _latitud.text.trim(),
      premLongitud: _longitud.text.trim(),
      premStatementDescriptor: _statement.text.trim(),
      premNumberTable: tables,
      premPickUpCost: cost,
      premAvailable: _available,
      premPickUp: _pickUp,
      premPickUpMandatory: _pickUpMandatory,
      horarios: _schedules,
    );
    Navigator.of(context).pop((detail: updated, password: password));
  }

  /// Opens a time picker for one day's open/close time and writes the result
  /// back as the backend's 12-hour string (e.g. `"10:00 AM"`).
  Future<void> _editTime(int index, {required bool open}) async {
    final current = open
        ? _schedules[index].premHourOpen
        : _schedules[index].premHourClose;
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(current),
      builder: (ctx, child) {
        final base = Theme.of(ctx);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(primary: AppColors.navy),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surface,
              hourMinuteColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.navy.withValues(alpha: 0.10)
                    : AppColors.surface2,
              ),
              hourMinuteTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.navy
                    : AppColors.ink2,
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.navy
                    : AppColors.surface2,
              ),
              dayPeriodTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.ink2,
              ),
              dayPeriodBorderSide: const BorderSide(color: AppColors.line),
              dialBackgroundColor: AppColors.surface2,
              dialHandColor: AppColors.navy,
              dialTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.ink,
              ),
              entryModeIconColor: AppColors.ink3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
    if (picked == null) return;
    final formatted = _formatTime(picked);
    setState(() {
      _schedules[index] = open
          ? _schedules[index].copyWith(premHourOpen: formatted)
          : _schedules[index].copyWith(premHourClose: formatted);
    });
  }

  /// Parses `"10:00 AM"` into a [TimeOfDay], falling back to 9:00 AM.
  static TimeOfDay _parseTime(String s) {
    try {
      final parts = s.trim().split(RegExp(r'\s+'));
      final hm = parts[0].split(':');
      var hour = int.parse(hm[0]) % 12;
      final minute = int.parse(hm[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM') hour += 12;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  /// Formats a [TimeOfDay] as `"h:mm AM/PM"` to match the backend shape.
  static String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== header =====
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
              child: Row(
                children: [
                  _BranchLogo(url: d.premImageUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Editar sucursal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.premName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.ink3,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            // ===== body =====
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(label: 'Nombre', controller: _name),
                    _ReadonlyField(
                      label: 'Correo (no editable)',
                      value: d.userEmail,
                    ),
                    _Field(label: 'Dirección', controller: _address),
                    _TwoCol(
                      left: _Field(label: 'Ciudad', controller: _city),
                      right: _Field(label: 'Estado', controller: _stateCtl),
                    ),
                    _TwoCol(
                      left: _Field(
                        label: 'Latitud',
                        controller: _latitud,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                      right: _Field(
                        label: 'Longitud',
                        controller: _longitud,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    _TwoCol(
                      left: _Field(
                        label: 'Número de mesas',
                        controller: _numberTable,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      right: _Field(
                        label: 'Statement descriptor',
                        controller: _statement,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ToggleRow(
                      title: 'Disponible',
                      subtitle: _available
                          ? 'La sucursal está activa'
                          : 'La sucursal está inactiva',
                      value: _available,
                      onChanged: (v) => setState(() => _available = v),
                    ),
                    const _SectionLabel('Recolección (pick-up)'),
                    _ToggleRow(
                      title: 'Permitir recolección',
                      subtitle: _pickUp
                          ? 'Los clientes pueden recoger su pedido'
                          : 'Recolección deshabilitada',
                      value: _pickUp,
                      onChanged: (v) => setState(() => _pickUp = v),
                    ),
                    if (_pickUp) ...[
                      _ToggleRow(
                        title: 'Recolección obligatoria',
                        subtitle: _pickUpMandatory
                            ? 'Todos los pedidos son para recoger'
                            : 'La recolección es opcional',
                        value: _pickUpMandatory,
                        onChanged: (v) =>
                            setState(() => _pickUpMandatory = v),
                      ),
                      _Field(
                        label: 'Costo de recolección',
                        controller: _pickUpCost,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                    if (_schedules.isNotEmpty) ...[
                      const _SectionLabel('Horario'),
                      for (int i = 0; i < _schedules.length; i++)
                        _ScheduleRow(
                          schedule: _schedules[i],
                          onToggle: (v) => setState(
                            () => _schedules[i] =
                                _schedules[i].copyWith(premAvailableDays: v),
                          ),
                          onEditOpen: () => _editTime(i, open: true),
                          onEditClose: () => _editTime(i, open: false),
                        ),
                    ],
                    const _SectionLabel('Cambiar contraseña'),
                    const Text(
                      'Déjala como está para no modificarla. Mínimo 8 '
                      'caracteres, con mayúsculas, minúsculas y un número.',
                      style: TextStyle(fontSize: 12, color: AppColors.ink3),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'Nueva contraseña',
                      controller: _password,
                      obscure: _obscure,
                      trailing: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                          color: AppColors.ink3,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    _Field(
                      label: 'Confirmar contraseña',
                      controller: _confirm,
                      obscure: _obscure,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            // ===== actions =====
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal control-flow exception for password validation.
class _ValidationError implements Exception {
  final String message;
  const _ValidationError(this.message);
}

class _BranchLogo extends StatelessWidget {
  final String url;

  const _BranchLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: url.isEmpty
          ? const Icon(Icons.store_outlined, color: AppColors.ink3, size: 22)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const Icon(
                Icons.store_outlined,
                color: AppColors.ink3,
                size: 22,
              ),
            ),
    );
  }
}

// ===========================================================================
// Form building blocks
// ===========================================================================

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final Widget? trailing;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.obscure = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            obscureText: obscure,
            decoration: InputDecoration(
              isDense: true,
              suffixIcon: trailing,
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
          ),
        ],
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14, color: AppColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          _Toggle(on: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final BranchSchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditOpen;
  final VoidCallback onEditClose;

  const _ScheduleRow({
    required this.schedule,
    required this.onToggle,
    required this.onEditOpen,
    required this.onEditClose,
  });

  @override
  Widget build(BuildContext context) {
    final open = schedule.premAvailableDays;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              schedule.premDay,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: open ? AppColors.ink : AppColors.ink3,
              ),
            ),
          ),
          Expanded(
            child: open
                ? Row(
                    children: [
                      _TimeChip(
                        label: schedule.premHourOpen,
                        onTap: onEditOpen,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '—',
                          style: TextStyle(color: AppColors.ink3),
                        ),
                      ),
                      _TimeChip(
                        label: schedule.premHourClose,
                        onTap: onEditClose,
                      ),
                    ],
                  )
                : const Text(
                    'Cerrado',
                    style: TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
          ),
          const SizedBox(width: 8),
          _Toggle(on: open, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.ink3),
              const SizedBox(width: 6),
              Text(
                label.isEmpty ? '--:--' : label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
