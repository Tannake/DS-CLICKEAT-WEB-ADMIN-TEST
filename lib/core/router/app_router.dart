import 'package:go_router/go_router.dart';

import 'package:ds_clickeat_web_admin/features/auth/presentation/login_page.dart';
import 'package:ds_clickeat_web_admin/features/shell/presentation/shell_page.dart';
import 'package:ds_clickeat_web_admin/features/products/presentation/products_page.dart';
import 'package:ds_clickeat_web_admin/features/categories/presentation/categories_page.dart';
import 'package:ds_clickeat_web_admin/features/variants/presentation/variants_page.dart';
import 'package:ds_clickeat_web_admin/features/inventory/presentation/inventory_page.dart';
import 'package:ds_clickeat_web_admin/features/tables/presentation/tables_page.dart';
import 'package:ds_clickeat_web_admin/features/cobros/presentation/cobros_page.dart';
import 'package:ds_clickeat_web_admin/features/reasons/presentation/reasons_page.dart';
import 'package:ds_clickeat_web_admin/features/branches/presentation/branches_page.dart';
import 'package:ds_clickeat_web_admin/features/printers/presentation/printers_page.dart';
import 'package:ds_clickeat_web_admin/features/reports/presentation/reports_page.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => ShellPage(child: child),
      routes: [
        GoRoute(
          path: '/app/products',
          builder: (context, state) => const ProductsPage(),
        ),
        GoRoute(
          path: '/app/categories-preparation',
          builder: (context, state) => const CategoriesPage(),
        ),
        GoRoute(
          path: '/app/options',
          builder: (context, state) => const VariantsPage(),
        ),
        GoRoute(
          path: '/app/inventory',
          builder: (context, state) => const InventoryPage(),
        ),
        GoRoute(
          path: '/app/tables',
          builder: (context, state) => const TablesPage(),
        ),
        GoRoute(
          path: '/app/cobros',
          builder: (context, state) => const CobrosPage(),
        ),
        GoRoute(
          path: '/app/cancel-reasons',
          builder: (context, state) => const ReasonsPage(),
        ),
        GoRoute(
          path: '/app/branches',
          builder: (context, state) => const BranchesPage(),
        ),
        GoRoute(
          path: '/app/printers',
          builder: (context, state) => const PrintersPage(),
        ),
        GoRoute(
          path: '/app/reports/dashboard',
          builder: (context, state) =>
              const ReportsPage(type: ReportType.dashboard),
        ),
        GoRoute(
          path: '/app/reports/ventas',
          builder: (context, state) =>
              const ReportsPage(type: ReportType.ventas),
        ),
        GoRoute(
          path: '/app/reports/pedidos',
          builder: (context, state) =>
              const ReportsPage(type: ReportType.pedidos),
        ),
        GoRoute(
          path: '/app/reports/productos',
          builder: (context, state) =>
              const ReportsPage(type: ReportType.productos),
        ),
        GoRoute(
          path: '/app/reports/categorias',
          builder: (context, state) =>
              const ReportsPage(type: ReportType.categorias),
        ),
      ],
    ),
  ],
);
