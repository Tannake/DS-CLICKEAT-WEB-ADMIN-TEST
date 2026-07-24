import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ds_clickeat_web_admin/core/responsive/breakpoints.dart';
import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/auth/models/session.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/premises/models/premise.dart';

/// Builds the avatar initials from a first/last name, e.g. "Ivan" + "Gomez"
/// → "IG". Falls back to whatever is available if a part is empty.
String _initials(String firstName, String lastName) {
  final f = firstName.trim();
  final l = lastName.trim();
  final a = f.isNotEmpty ? f[0] : '';
  final b = l.isNotEmpty ? l[0] : '';
  final result = '$a$b';
  return result.isNotEmpty ? result.toUpperCase() : '?';
}

class _MenuSection {
  final String label;
  final List<_MenuItem> items;
  const _MenuSection(this.label, this.items);
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  const _MenuItem(this.icon, this.label, this.route);
}

const _sections = [
  _MenuSection('Catálogo', [
    _MenuItem(Icons.inventory_2_outlined, 'Productos', '/app/products'),
    _MenuItem(Icons.category_outlined, 'Categorías y Área de prepación',
        '/app/categories-preparation'),
    _MenuItem(Icons.tune_outlined, 'Opciones y modificaciones', '/app/options'),
    _MenuItem(Icons.warehouse_outlined, 'Inventario', '/app/inventory'),
  ]),
  _MenuSection('Operación', [
    _MenuItem(Icons.table_restaurant_outlined, 'Mesas y zonas', '/app/tables'),
    _MenuItem(Icons.payment_outlined, 'Cobros', '/app/cobros'),
    _MenuItem(Icons.block_outlined, 'Razones de cancelación',
        '/app/cancel-reasons'),
  ]),
  _MenuSection('Negocio', [
    _MenuItem(Icons.store_outlined, 'Sucursales', '/app/branches'),
  ]),
  _MenuSection('Reportes', [
    _MenuItem(Icons.bar_chart_outlined, 'Dashboard diario',
        '/app/reports/dashboard'),
    _MenuItem(Icons.trending_up_outlined, 'Ventas', '/app/reports/ventas'),
    _MenuItem(Icons.receipt_long_outlined, 'Pedidos', '/app/reports/pedidos'),
    _MenuItem(Icons.inventory_2_outlined, 'Productos',
        '/app/reports/productos'),
    _MenuItem(Icons.category_outlined, 'Categorías',
        '/app/reports/categorias'),
  ]),
];

class ShellPage extends ConsumerStatefulWidget {
  final Widget child;
  const ShellPage({super.key, required this.child});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrapAndLoad);
  }

  /// On a hard reload (F5) the provider tree is rebuilt from scratch and the
  /// session is no longer in memory, so rehydrate it from storage before
  /// loading premises — otherwise `PremisesController.load()` sees a null
  /// session, bails out, and the branch selector never appears. With no
  /// persisted session there is nothing to show, so go back to login.
  Future<void> _bootstrapAndLoad() async {
    if (ref.read(sessionControllerProvider) == null) {
      await ref.read(sessionControllerProvider.notifier).bootstrap();
    }
    if (!mounted) return;
    if (ref.read(sessionControllerProvider) == null) {
      context.go('/login');
      return;
    }
    await ref.read(premisesControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    // Session is normally cleared by the 401 interceptor mid-session (e.g.
    // an expired token) rather than through an explicit logout tap, so
    // there's no user action to hang a navigation off of — react to the
    // state transition itself instead of leaving the shell stuck rendering
    // stale data.
    ref.listen<Session?>(sessionControllerProvider, (previous, next) {
      if (previous != null && next == null) {
        context.go('/login');
      }
    });

    final premState = ref.watch(premisesControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final sidebarContent =
        _buildSidebarContent(premState, session, currentPath);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kCompactBreakpoint;

        if (!compact) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                // Sidebar
                SizedBox(
                  width: 260,
                  child: Material(
                    color: AppColors.sidebar,
                    child: sidebarContent,
                  ),
                ),
                // Content area
                Expanded(child: widget.child),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: Drawer(
            width: 280,
            backgroundColor: AppColors.sidebar,
            child: SafeArea(child: sidebarContent),
          ),
          body: Column(
            children: [
              _CompactTopBar(
                premState: premState,
                currentPath: currentPath,
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                onSelectPremise: (id) => ref
                    .read(premisesControllerProvider.notifier)
                    .select(id),
              ),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }

  /// The sidebar's content (logo, branch selector, menu, user/logout),
  /// shared between the permanent wide-layout sidebar and the compact
  /// layout's drawer.
  Widget _buildSidebarContent(
    PremisesState premState,
    Session? session,
    String currentPath,
  ) {
    return Column(
      children: [
        // Logo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(text: 'Click', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'Eat', style: TextStyle(color: AppColors.accent)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Admin',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1, thickness: 1),
        // Branch / premise selector — hidden on Reportes, since
        // those screens let the user pick their own business(es)
        // per report instead of relying on this global selector.
        if (!currentPath.startsWith('/app/reports'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: premState.loading
                ? const SizedBox(
                    height: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                : premState.premises.isNotEmpty
                    ? _BranchSelector(
                        premises: premState.premises,
                        selectedId: premState.selectedPremId,
                        onSelect: (id) => ref
                            .read(premisesControllerProvider.notifier)
                            .select(id),
                      )
                    : const SizedBox.shrink(),
          ),
        // Menu
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 12),
            children: [
              for (final section in _sections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    section.label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.sidebarSection,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final item in section.items)
                  _SidebarItem(
                    icon: item.icon,
                    label: item.label,
                    selected: currentPath == item.route,
                    onTap: () {
                      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                        Navigator.of(context).pop();
                      }
                      context.go(item.route);
                    },
                  ),
              ],
            ],
          ),
        ),
        // User / logout
        const Divider(color: Colors.white12, height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text(
                  session != null
                      ? _initials(session.userName, session.userLastname)
                      : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session != null
                      ? '${session.userName} ${session.userLastname}'
                      : '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                onPressed: () async {
                  await ref.read(sessionControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slim top bar shown instead of the permanent sidebar on narrow viewports:
/// a hamburger button that opens the sidebar as a drawer, the wordmark, and
/// (outside Reportes) the branch selector.
class _CompactTopBar extends StatelessWidget {
  final PremisesState premState;
  final String currentPath;
  final VoidCallback onMenuTap;
  final ValueChanged<int> onSelectPremise;

  const _CompactTopBar({
    required this.premState,
    required this.currentPath,
    required this.onMenuTap,
    required this.onSelectPremise,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sidebar,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: onMenuTap,
                  tooltip: 'Menú',
                ),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                    children: [
                      TextSpan(text: 'Click', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Eat', style: TextStyle(color: AppColors.accent)),
                    ],
                  ),
                ),
                const Spacer(),
                if (!currentPath.startsWith('/app/reports') &&
                    !premState.loading &&
                    premState.premises.isNotEmpty)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: _BranchSelector(
                        premises: premState.premises,
                        selectedId: premState.selectedPremId,
                        onSelect: onSelectPremise,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded branch/premise selector matching the design's `.branchsel`.
/// Uses a custom popup so it never shows Material's default highlight color.
class _BranchSelector extends StatelessWidget {
  final List<Premise> premises;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _BranchSelector({
    required this.premises,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Premise? selected;
    for (final p in premises) {
      if (p.premId == selectedId) {
        selected = p;
        break;
      }
    }
    selected ??= premises.first;

    return PopupMenuButton<int>(
      onSelected: onSelect,
      offset: const Offset(0, 6),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
      position: PopupMenuPosition.under,
      splashRadius: 0,
      itemBuilder: (context) {
        return [
          for (final p in premises)
            PopupMenuItem<int>(
              value: p.premId,
              height: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(right: 11),
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.premName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        if (p.premAddress.isNotEmpty)
                          Text(
                            p.premAddress,
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
                  if (p.premId == selected!.premId)
                    const Icon(Icons.check,
                        size: 17, color: AppColors.greenInk),
                ],
              ),
            ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected.premName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? AppColors.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: Colors.white10,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? AppColors.sidebar : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.sidebar : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
