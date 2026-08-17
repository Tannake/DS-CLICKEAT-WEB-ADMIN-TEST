import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/employees/controllers/employees_controller.dart';
import 'package:ds_clickeat_web_admin/features/employees/data/employees_repository.dart';
import 'package:ds_clickeat_web_admin/features/employees/models/employee.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/role_modules/controllers/role_modules_controller.dart';
import 'package:ds_clickeat_web_admin/features/role_modules/models/role_module.dart';
import 'package:ds_clickeat_web_admin/features/roles/controllers/roles_controller.dart';
import 'package:ds_clickeat_web_admin/features/roles/models/role.dart';

/// "Personal y Accesos" groups everything about who works at a premise and
/// what they're allowed to do: roles (`premises/role/<premId>`), staff
/// (`premises/employee/<premId>`), and which screens each role can access
/// (`premises/role-module/<premId>` against the `premises/system-module`
/// catalog), each shown as its own table — mirrors `cobros_page.dart`'s
/// pattern of composing independent features on one screen. There is no
/// `staff` model/data/controller: this page watches the `roles`,
/// `employees` and `role_modules` controllers directly.
class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
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
    ref.read(rolesControllerProvider.notifier).load(premId);
    ref.read(employeesControllerProvider.notifier).load(premId);
    ref.read(roleModulesControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premState = ref.watch(premisesControllerProvider);
    final rolesState = ref.watch(rolesControllerProvider);
    final employeesState = ref.watch(employeesControllerProvider);
    final roleModulesState = ref.watch(roleModulesControllerProvider);
    final premId = premState.selectedPremId;
    _ensurePremiseLoaded(premId);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal y Accesos',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Roles y personal con acceso a esta sucursal.',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rolesSection(premId, rolesState),
                  const SizedBox(height: 28),
                  _employeesSection(premId, employeesState, rolesState.roles),
                  const SizedBox(height: 28),
                  _permissionsSection(premId, rolesState.roles, roleModulesState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Roles section
  // ===========================================================================

  Widget _rolesSection(int? premId, RolesState state) {
    final total = state.roles.length;
    final available = state.roles.where((r) => r.roleAvailable).length;
    return _Section(
      title: 'Roles',
      subtitle: '$available de $total ${total == 1 ? 'rol disponible' : 'roles disponibles'}',
      addLabel: 'Rol',
      onAdd: premId == null ? null : () => _createRole(premId),
      child: _rolesContent(premId, state),
    );
  }

  Widget _rolesContent(int? premId, RolesState state) {
    if (premId == null) return const SizedBox.shrink();
    if (state.loading) return const _SectionLoading();
    if (state.error != null) return _SectionError(state.error!);
    if (state.roles.isEmpty) {
      return const _EmptyState(
        icon: Icons.badge_outlined,
        title: 'Sin roles',
        message: 'Agrega un rol para asignarlo al personal.',
      );
    }
    return _RolesTable(
      roles: state.roles,
      onToggleAvailable: (r) => _toggleRoleAvailable(premId, r),
      onEdit: (r) => _editRole(premId, r),
    );
  }

  Future<void> _createRole(int premId) async {
    final result = await _showRoleEditor(title: 'Nuevo rol');
    if (result == null) return;
    final error = await ref
        .read(rolesControllerProvider.notifier)
        .createRole(premId, name: result.name);
    if (error != null) {
      _toast(error);
      return;
    }
    // The backend seeds `role_module` rows for a newly created role, but
    // `createRole` only reloads the `roles` controller — without this, the
    // new role shows up with every screen toggled off (stale/missing local
    // state, not the real backend state) until the next full page load,
    // and activating one hits a duplicate-key error since the row already
    // exists server-side.
    ref.read(roleModulesControllerProvider.notifier).load(premId);
  }

  Future<void> _editRole(int premId, Role role) async {
    final result = await _showRoleEditor(title: 'Editar rol', role: role);
    if (result == null) return;
    final error = await ref
        .read(rolesControllerProvider.notifier)
        .updateRole(premId, role.roleId, name: result.name, available: result.available);
    if (error != null) _toast(error);
  }

  Future<void> _toggleRoleAvailable(int premId, Role role) async {
    final error =
        await ref.read(rolesControllerProvider.notifier).toggleAvailable(premId, role);
    if (error != null) _toast(error);
  }

  Future<_RoleFormResult?> _showRoleEditor({required String title, Role? role}) {
    return showDialog<_RoleFormResult>(
      context: context,
      builder: (ctx) => _RoleEditor(title: title, role: role),
    );
  }

  // ===========================================================================
  // Employees ("Personal") section
  // ===========================================================================

  Widget _employeesSection(int? premId, EmployeesState state, List<Role> roles) {
    final total = state.employees.length;
    final available = state.employees.where((e) => e.emplAvailable).length;
    return _Section(
      title: 'Personal',
      subtitle: '$available de $total ${total == 1 ? 'persona activa' : 'personas activas'}',
      addLabel: 'Persona',
      onAdd: (premId == null || roles.isEmpty) ? null : () => _createEmployee(premId, roles),
      child: _employeesContent(premId, state, roles),
    );
  }

  Widget _employeesContent(int? premId, EmployeesState state, List<Role> roles) {
    if (premId == null) return const SizedBox.shrink();
    if (state.loading) return const _SectionLoading();
    if (state.error != null) return _SectionError(state.error!);
    if (state.employees.isEmpty) {
      return _EmptyState(
        icon: Icons.people_outline,
        title: 'Sin personal',
        message: roles.isEmpty
            ? 'Agrega primero un rol para poder dar de alta personal.'
            : 'Agrega una persona para esta sucursal.',
      );
    }
    return _EmployeesTable(
      employees: state.employees,
      onToggleAvailable: (e) => _toggleEmployeeAvailable(premId, e),
      onEdit: (e) => _editEmployee(premId, e, roles),
    );
  }

  Future<void> _createEmployee(int premId, List<Role> roles) async {
    final result = await _showEmployeeEditor(title: 'Nueva persona', roles: roles);
    if (result == null) return;
    final error = await ref.read(employeesControllerProvider.notifier).createEmployee(
          premId,
          name: result.name,
          email: result.email,
          roleId: result.roleId,
          // Validated non-empty in `_EmployeeEditorState._submit` when
          // `widget.employee == null` (create mode).
          password: result.password!,
        );
    if (error != null) _toast(error);
  }

  Future<void> _editEmployee(int premId, Employee employee, List<Role> roles) async {
    final result = await _showEmployeeEditor(
      title: 'Editar persona',
      roles: roles,
      employee: employee,
    );
    if (result == null) return;
    final role = roles.firstWhere(
      (r) => r.roleId == result.roleId,
      orElse: () => Role(roleId: result.roleId, roleName: employee.roleName, roleAvailable: true),
    );
    final error = await ref.read(employeesControllerProvider.notifier).updateEmployee(
          premId,
          employee.emplId,
          name: result.name,
          email: result.email,
          available: result.available,
          roleId: result.roleId,
          roleName: role.roleName,
          password: result.password,
        );
    if (error != null) _toast(error);
  }

  Future<void> _toggleEmployeeAvailable(int premId, Employee employee) async {
    final error = await ref
        .read(employeesControllerProvider.notifier)
        .toggleAvailable(premId, employee);
    if (error != null) _toast(error);
  }

  Future<_EmployeeFormResult?> _showEmployeeEditor({
    required String title,
    required List<Role> roles,
    Employee? employee,
  }) {
    return showDialog<_EmployeeFormResult>(
      context: context,
      builder: (ctx) => _EmployeeEditor(title: title, roles: roles, employee: employee),
    );
  }

  // ===========================================================================
  // Permissions ("Accesos por rol") section — a role x screen matrix, one
  // switch per cell. Assigning a module posts `role_type: 'I'`, unassigning
  // posts `'D'` — no editor dialog, the switch itself is the whole flow.
  // ===========================================================================

  Widget _permissionsSection(int? premId, List<Role> roles, RoleModulesState state) {
    return _Section(
      title: 'Accesos por rol',
      subtitle: '${state.modules.length} ${state.modules.length == 1 ? 'pantalla configurable' : 'pantallas configurables'}',
      child: _permissionsContent(premId, roles, state),
    );
  }

  Widget _permissionsContent(int? premId, List<Role> roles, RoleModulesState state) {
    if (premId == null) return const SizedBox.shrink();
    if (state.loading) return const _SectionLoading();
    if (state.error != null) return _SectionError(state.error!);
    if (roles.isEmpty) {
      return const _EmptyState(
        icon: Icons.lock_outline,
        title: 'Sin roles',
        message: 'Agrega un rol para poder asignarle acceso a pantallas.',
      );
    }
    if (state.modules.isEmpty) {
      return const _EmptyState(
        icon: Icons.dashboard_outlined,
        title: 'Sin pantallas configurables',
        message: 'No hay módulos disponibles para asignar todavía.',
      );
    }
    return _PermissionsTable(
      roles: roles,
      modules: state.modules,
      isAssigned: state.isAssigned,
      onToggle: (roleId, sysmId, next) => _toggleModule(premId, roleId, sysmId, next),
    );
  }

  Future<void> _toggleModule(int premId, int roleId, int sysmId, bool assigned) async {
    final error = await ref
        .read(roleModulesControllerProvider.notifier)
        .setAssigned(premId, roleId, sysmId, assigned);
    if (error != null) _toast(error);
  }

  // ===== shared helpers =====================================================

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ===========================================================================
// Section wrapper (title/subtitle, add button) — mirrors cobros_page.dart's
// `_Section`.
// ===========================================================================

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  /// Both null hides the add button entirely — used by the permissions
  /// section, which has no "create" action (a switch flip is the whole
  /// flow).
  final String? addLabel;
  final VoidCallback? onAdd;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    this.addLabel,
    this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            if (addLabel != null)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(addLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  const _SectionError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.red, fontSize: 14)),
      ),
    );
  }
}

// ===========================================================================
// Roles table
// ===========================================================================

class _Col {
  final String label;
  final int flex;
  const _Col(this.label, this.flex);
}

const _kActionsColWidth = 56.0;

class _RolesTable extends StatelessWidget {
  final List<Role> roles;
  final void Function(Role) onToggleAvailable;
  final void Function(Role) onEdit;

  const _RolesTable({
    required this.roles,
    required this.onToggleAvailable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ScrollableTable(
        minWidth: 480,
        child: Column(
          children: [
            const _TableHeader(columns: [_Col('ROL', 60), _Col('DISPONIBLE', 30)]),
            for (var i = 0; i < roles.length; i++)
              _RoleRow(
                role: roles[i],
                last: i == roles.length - 1,
                onToggleAvailable: () => onToggleAvailable(roles[i]),
                onEdit: () => onEdit(roles[i]),
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

class _TableHeader extends StatelessWidget {
  final List<_Col> columns;
  const _TableHeader({required this.columns});

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
          for (final c in columns) Expanded(flex: c.flex, child: Text(c.label, style: _headerStyle)),
          const SizedBox(
            width: _kActionsColWidth,
            child: Text('', style: _headerStyle, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final Role role;
  final bool last;
  final VoidCallback onToggleAvailable;
  final VoidCallback onEdit;

  const _RoleRow({
    required this.role,
    required this.last,
    required this.onToggleAvailable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final available = role.roleAvailable;
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 60,
            child: Text(
              role.roleName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          Expanded(
            flex: 30,
            child: Row(
              children: [
                _Toggle(on: available, onChanged: (_) => onToggleAvailable()),
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
                _IconBtn(icon: Icons.edit_outlined, color: AppColors.ink3, tooltip: 'Editar', onPressed: onEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Employees ("Personal") table
// ===========================================================================

class _EmployeesTable extends StatelessWidget {
  final List<Employee> employees;
  final void Function(Employee) onToggleAvailable;
  final void Function(Employee) onEdit;

  const _EmployeesTable({
    required this.employees,
    required this.onToggleAvailable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ScrollableTable(
        minWidth: 820,
        child: Column(
          children: [
            const _TableHeader(columns: [
              _Col('NOMBRE', 24),
              _Col('CORREO', 30),
              _Col('ROL', 18),
              _Col('DISPONIBLE', 20),
            ]),
            for (var i = 0; i < employees.length; i++)
              _EmployeeRow(
                employee: employees[i],
                last: i == employees.length - 1,
                onToggleAvailable: () => onToggleAvailable(employees[i]),
                onEdit: () => onEdit(employees[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final bool last;
  final VoidCallback onToggleAvailable;
  final VoidCallback onEdit;

  const _EmployeeRow({
    required this.employee,
    required this.last,
    required this.onToggleAvailable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final available = employee.emplAvailable;
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Text(
              employee.emplName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          Expanded(
            flex: 30,
            child: Text(
              employee.emplEmail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              employee.roleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: 20,
            child: Row(
              children: [
                _Toggle(on: available, onChanged: (_) => onToggleAvailable()),
                const SizedBox(width: 10),
                Text(
                  available ? 'Activo' : 'Inactivo',
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
                _IconBtn(icon: Icons.edit_outlined, color: AppColors.ink3, tooltip: 'Editar', onPressed: onEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Permissions matrix: roles (rows) x system modules (columns), a switch per
// cell. Columns are dynamic (driven by `premises/system-module`, currently
// 3 rows but "puede ser que se agreguen más" per the backend), so this uses
// fixed-width columns inside `ScrollableTable` rather than the `_Col`/flex
// header the other two tables use — a flex split doesn't make sense for a
// column count that can grow.
// ===========================================================================

const _kRoleColWidth = 200.0;
const _kModuleColWidth = 150.0;

class _PermissionsTable extends StatelessWidget {
  final List<Role> roles;
  final List<SystemModule> modules;
  final bool Function(int roleId, int sysmId) isAssigned;
  final void Function(int roleId, int sysmId, bool next) onToggle;

  const _PermissionsTable({
    required this.roles,
    required this.modules,
    required this.isAssigned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ScrollableTable(
        minWidth: _kRoleColWidth + modules.length * _kModuleColWidth,
        child: Column(
          children: [
            _PermissionsHeader(modules: modules),
            for (var i = 0; i < roles.length; i++)
              _PermissionsRow(
                role: roles[i],
                modules: modules,
                last: i == roles.length - 1,
                isAssigned: isAssigned,
                onToggle: onToggle,
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsHeader extends StatelessWidget {
  final List<SystemModule> modules;
  const _PermissionsHeader({required this.modules});

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
          const SizedBox(width: _kRoleColWidth, child: Text('ROL', style: _headerStyle)),
          for (final m in modules)
            SizedBox(
              width: _kModuleColWidth,
              child: Text(m.sysmName.toUpperCase(), style: _headerStyle, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _PermissionsRow extends StatelessWidget {
  final Role role;
  final List<SystemModule> modules;
  final bool last;
  final bool Function(int roleId, int sysmId) isAssigned;
  final void Function(int roleId, int sysmId, bool next) onToggle;

  const _PermissionsRow({
    required this.role,
    required this.modules,
    required this.last,
    required this.isAssigned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _kRoleColWidth,
            child: Text(
              role.roleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          for (final m in modules)
            SizedBox(
              width: _kModuleColWidth,
              child: Center(
                child: _Toggle(
                  on: isAssigned(role.roleId, m.sysmId),
                  onChanged: (next) => onToggle(role.roleId, m.sysmId, next),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Toggle / icon button (mirrors printers_page.dart's private widgets)
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
          ),
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
// Role editor dialog
// ===========================================================================

class _RoleFormResult {
  final String name;
  final bool available;
  const _RoleFormResult({required this.name, required this.available});
}

class _RoleEditor extends StatefulWidget {
  final String title;
  final Role? role;
  const _RoleEditor({required this.title, this.role});

  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.role?.roleName ?? '');
  late bool _available = widget.role?.roleAvailable ?? true;
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
    Navigator.of(context).pop(_RoleFormResult(name: name, available: _available));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.role != null;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Nombre del rol'),
              const SizedBox(height: 8),
              _TextInput(
                controller: _name,
                hint: 'Ej. Mesero',
                autofocus: true,
                onChanged: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              // The insert branch of `fun_admin_role_crud` doesn't set
              // `role_available` (left at the table default) — only shown
              // for edit, where the SP does apply it.
              if (isEdit) ...[
                const SizedBox(height: 18),
                _ToggleRow(
                  label: 'Disponible',
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
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
// Employee editor dialog
// ===========================================================================

/// The fixed, non-editable domain every staff email must use — the local
/// part (before `@`) is the only thing the form lets the admin type.
const _kEmailDomain = '@clickEat.com';

/// Strips [_kEmailDomain] off a full email for display in the local-part
/// field. A legacy email on a different domain (from before this rule
/// existed) is shown as-is — saving it forces it onto [_kEmailDomain], which
/// is the intended normalization, not a bug.
String _emailLocalPart(String fullEmail) {
  final email = fullEmail.trim();
  if (email.toLowerCase().endsWith(_kEmailDomain.toLowerCase())) {
    return email.substring(0, email.length - _kEmailDomain.length);
  }
  return email;
}

class _EmployeeFormResult {
  final String name;
  final String email;
  final int roleId;
  final bool available;
  final String? password;
  const _EmployeeFormResult({
    required this.name,
    required this.email,
    required this.roleId,
    required this.available,
    this.password,
  });
}

class _EmployeeEditor extends ConsumerStatefulWidget {
  final String title;
  final List<Role> roles;
  final Employee? employee;
  const _EmployeeEditor({required this.title, required this.roles, this.employee});

  @override
  ConsumerState<_EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends ConsumerState<_EmployeeEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.employee?.emplName ?? '');
  late final TextEditingController _email =
      TextEditingController(text: _emailLocalPart(widget.employee?.emplEmail ?? ''));
  late final TextEditingController _password = TextEditingController();
  late int? _roleId = widget.employee?.roleId ?? (widget.roles.isNotEmpty ? widget.roles.first.roleId : null);
  late bool _available = widget.employee?.emplAvailable ?? true;
  String? _error;
  bool _checkingEmail = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final localPart = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    if (localPart.isEmpty) {
      setState(() => _error = 'El correo es obligatorio.');
      return;
    }
    if (localPart.contains('@') || localPart.contains(RegExp(r'\s'))) {
      setState(() => _error = 'El correo solo puede llevar lo que va antes de "$_kEmailDomain".');
      return;
    }
    if (_roleId == null) {
      setState(() => _error = 'Selecciona un rol.');
      return;
    }
    final password = _password.text.trim();
    // Only required on create — `fun_admin_employee_crud`'s update branch
    // keeps the existing password when the field is left blank (see
    // `EmployeesRepository.updateEmployee`).
    if (widget.employee == null && password.isEmpty) {
      setState(() => _error = 'La contraseña es obligatoria.');
      return;
    }

    final email = '$localPart$_kEmailDomain';
    // Skip the duplicate check when editing without touching the email —
    // `premises/employee-validate-email` would otherwise match this same
    // employee's own row and block an unrelated save (e.g. just toggling
    // "Activo").
    final unchanged =
        widget.employee != null && email.toLowerCase() == widget.employee!.emplEmail.toLowerCase();
    if (!unchanged) {
      setState(() {
        _checkingEmail = true;
        _error = null;
      });
      bool exists;
      try {
        exists = await ref.read(employeesRepositoryProvider).emailExists(email);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _checkingEmail = false;
          _error = 'No se pudo validar el correo. Intenta de nuevo.';
        });
        return;
      }
      if (!mounted) return;
      if (exists) {
        setState(() {
          _checkingEmail = false;
          _error = 'Este correo ya está registrado.';
        });
        return;
      }
      setState(() => _checkingEmail = false);
    }

    Navigator.of(context).pop(_EmployeeFormResult(
      name: name,
      email: email,
      roleId: _roleId!,
      available: _available,
      password: password.isEmpty ? null : password,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;
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
                hint: 'Ej. Juan Pérez',
                autofocus: true,
                onChanged: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Correo'),
              const SizedBox(height: 8),
              _TextInput(
                controller: _email,
                hint: 'juan.perez',
                suffixText: _kEmailDomain,
                enabled: !_checkingEmail,
                onChanged: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Rol'),
              const SizedBox(height: 8),
              _RoleSelectField(
                roles: widget.roles,
                selectedRoleId: _roleId,
                onChanged: (id) => setState(() {
                  _roleId = id;
                  _error = null;
                }),
              ),
              const SizedBox(height: 18),
              _FieldLabel(isEdit ? 'Nueva contraseña' : 'Contraseña'),
              const SizedBox(height: 8),
              _TextInput(
                controller: _password,
                hint: isEdit ? 'Dejar en blanco para no cambiarla' : 'Contraseña de acceso',
                obscure: true,
                enabled: !_checkingEmail,
                onChanged: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              // The insert branch of `fun_admin_employee_crud` doesn't set
              // `empl_available` — it's only settable via update, so this
              // toggle stays edit-only.
              if (isEdit) ...[
                const SizedBox(height: 18),
                _ToggleRow(
                  label: 'Activo',
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checkingEmail ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _checkingEmail ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          child: _checkingEmail
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Single-select role picker styled like a bordered form field — custom
/// (not [DropdownButton]) per the project's convention of avoiding
/// Material's default (lavender-tinted) dropdown highlight colors.
class _RoleSelectField extends StatelessWidget {
  final List<Role> roles;
  final int? selectedRoleId;
  final ValueChanged<int> onChanged;

  const _RoleSelectField({
    required this.roles,
    required this.selectedRoleId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = roles.where((r) => r.roleId == selectedRoleId).toList();
    final label = selected.isNotEmpty ? selected.first.roleName : 'Selecciona un rol';
    return PopupMenuButton<int>(
      offset: const Offset(0, 6),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      constraints: const BoxConstraints(minWidth: 260),
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final role in roles)
          PopupMenuItem<int>(
            value: role.roleId,
            child: Text(
              role.roleName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: role.roleId == selectedRoleId ? FontWeight.w700 : FontWeight.w500,
                color: role.roleId == selectedRoleId ? AppColors.navy : AppColors.ink2,
              ),
            ),
          ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected.isNotEmpty ? AppColors.ink : AppColors.ink3,
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared form widgets (mirror printers_page.dart's private widgets)
// ===========================================================================

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final bool obscure;
  final bool enabled;
  /// Fixed, non-editable trailing text (e.g. a locked email domain) —
  /// rendered inside the field via [InputDecoration.suffixText].
  final String? suffixText;
  final VoidCallback? onChanged;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.obscure = false,
    this.enabled = true,
    this.suffixText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      enabled: enabled,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
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

  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.ink4),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink2),
            ),
            const SizedBox(height: 5),
            Text(message, style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}
