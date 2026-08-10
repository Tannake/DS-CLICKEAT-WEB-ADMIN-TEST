# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`ds_clickeat_web_admin` — a **Flutter web** admin panel (QA build) for the ClickEat platform. It is a frontend only; it talks to a separate backend admin API over HTTP. The backend is **not** in this repo.

## Commands

```bash
# Run (debug mode crashes Chrome's renderer on some machines — "Target crashed!" / blank page;
# use --release or --profile to actually see the app):
flutter run -d chrome --release --dart-define=API_BASE_URL=http://localhost:3001/api/admin/

# If Chrome debug keeps crashing but you need hot reload, serve and open the browser manually:
flutter run -d web-server --web-port=5599 --dart-define=API_BASE_URL=http://localhost:3001/api/admin/

flutter analyze                 # lint / static analysis
flutter build web --dart-define=API_BASE_URL=...   # production build -> build/web
flutter test                    # all tests
flutter test test/widget_test.dart   # a single test file
flutter pub get                 # install deps
```

`API_BASE_URL` is required to point at a running backend. It is read at compile time via `String.fromEnvironment` (see `lib/core/env.dart`, default `http://localhost:3000/api/admin/`). It **must end with a trailing slash** — repositories use relative paths with no leading slash (e.g. `_dio.post('auth/login')` → `<base>auth/login`).

If login fails with `XMLHttpRequest onError` / "network layer" error, the backend at `API_BASE_URL` is almost certainly not running (or is blocking CORS for the Flutter origin). Verify with a direct `curl` to the login endpoint before debugging app code.

## Architecture

Feature-first layout under `lib/features/<feature>/`, each feature split into the same four layers:

- `models/` — plain data classes with `fromJson` / `fromBackend` / `toJson`.
- `data/` — a `*Repository` that wraps `Dio` and knows the endpoints. Exposed via a Riverpod `Provider`.
- `controllers/` — `StateNotifier` + an immutable `*State` (with `copyWith`) exposed via `StateNotifierProvider`. This is the only state-management pattern in use (flutter_riverpod, no codegen).
- `presentation/` — `ConsumerWidget` / `ConsumerStatefulWidget` screens that `ref.watch` state and `ref.read(...notifier)` to trigger actions.

`lib/core/` holds cross-cutting infra: `env.dart`, `http/dio_client.dart`, `router/app_router.dart`, `theme/app_theme.dart`, `errors/error_logger.dart`, `utils/web_download.dart`, plus the responsive helpers below.

### Backend response envelope

The API wraps payloads in `{ "state": 1, "result": ... }`. Repositories check `data['state'] == 1` and read `data['result']` (a Map or List); anything else is treated as failure/empty. Follow this convention when adding new endpoints.

### Auth & HTTP

- `dioProvider` (`lib/core/http/dio_client.dart`) builds the single shared `Dio`. An interceptor injects `Authorization: Bearer <token>` from the current `Session`, and on a `401` it calls `logout()`. Non-401 failures (timeouts, connection errors) do **not** clear the session — a stale/expired token persists until the backend actually rejects it with a 401.
- `Session` (access token + user id/name) is persisted in `SharedPreferences` under key `clickeat.admin.session`, with no expiry check on read — `readPersistedSession()` trusts it as long as it's present. `SessionController.bootstrap()` rehydrates it on app start; `sessionControllerProvider == null` means logged out.
- Login flow: `LoginPage` → `loginControllerProvider.login()` → `AuthRepository.login()` posts to `auth/login`, stores the session, then `SessionController.bootstrap()` reloads it before navigating to `/app/products`.
- `ShellPage.build()` runs `ref.listen<Session?>(sessionControllerProvider, ...)` and navigates to `/login` the moment the session flips from non-null to null — this is what makes a mid-session 401 (expired token) bounce the user out instead of leaving the shell stuck rendering stale/broken data.

### Error logging

`ErrorLogger` (`lib/core/errors/error_logger.dart`) posts to `scrip/log-error` on a bare `Dio` with no interceptors of its own (reusing `dioProvider` would let a failed log call recurse through this same error path). It's wired in three places: `dio_client.dart`'s `onResponse` (business-logic failures — `{state: 0, ...}` responses that return HTTP 200 and never hit `onError`), the same interceptor's `onError` (transport/HTTP errors), and `main.dart`'s `FlutterError.onError`/`runZonedGuarded` (uncaught framework/Dart errors). Callers outside the interceptor (like `main.dart`) must pass the session token explicitly since they have no interceptor access to it. Logging failures are swallowed — it must never throw or mask the original error.

### Routing

`go_router` (`lib/core/router/app_router.dart`), initial location `/login`. Authenticated screens live under a `ShellRoute` (`ShellPage`, the sidebar + premises top-bar chrome) at `/app/*`. Auth is **not** enforced by a router `redirect:` callback — instead `LoginPage` pushes to `/app/products` once a session exists, `ShellPage.initState` bounces back to `/login` if bootstrapping finds no persisted session, and `ShellPage`'s `ref.listen` (see Auth & HTTP above) bounces back to `/login` if the session is cleared mid-session. New authenticated screens go under the `ShellRoute`; the sidebar menu is the static `_sections` list in `shell_page.dart`.

### Premises scoping

Most data is scoped to a "premise" (sucursal). `premisesControllerProvider` loads the user's premises on shell init and tracks `selectedPremId` (top-bar selector). Data screens like Products fetch by that id (`products/<premId>`). When adding premise-scoped features, read the selected id from `premisesControllerProvider`.

Implemented screens: **Products**, **Categories & preparation areas**, **Options/modifications** (`variants` feature), **Inventory**, **Tables & zones** (`tables`), **Cobros** (`cobros`), **Cancellation reasons** (`reasons`), **Branches** (`branches`, under a "Negocio" sidebar section), **Printers** (`printers`, `premises/printer/<premId>` / `premises/printer-crud`, standard `prin_type` CRUD), **Personal y Accesos** (`staff`, under "Negocio"; composes the `roles` and `employees` features — see below), and **Reports** (`reports`, under a "Reportes" sidebar section with 6 sub-routes: dashboard, ventas, pedidos, productos, categorías, propinas). There are no stub/placeholder screens left — every sidebar item routes to a real page.

**Cobros** (`/app/cobros`) is one screen composing two independent features: payment methods (`payments`, `payments/<premId>`) and tip presets (`tips`, `orders/tips/<premId>`), each rendered with the same card layout. There is no `cobros` model/data/controller — `cobros/presentation/cobros_page.dart` watches both the `payments` and `tips` controllers. **Cancellation reasons** (`/app/cancel-reasons`, `reasons` feature, `orders/reason-cancel/<premId>`) renders rows as a table (mirroring the Products table) rather than cards.

**Branches** (`/app/branches`) deviates from the CRUD convention below: `BranchesRepository` only has `getByUser` (`premises/<userId>`), `getDetail` (`premises-detail/<userId>/<premId>`), and `update` (`premises-update`) — there is no insert or delete, and no `*_type` discriminator. `update` always carries `password` (empty string when the user left it unchanged).

**Personal y Accesos** (`/app/staff`) composes three independent features exactly like Cobros — `roles` (`premises/role/<premId>` / `premises/role-crud`, `role_type`), `employees` (`premises/employee/<premId>` / `premises/employee-crud`, `empl_type`), and `role_modules` (`premises/role-module/<premId>` + the global `premises/system-module` catalog / `premises/role-module-crud`, `rmod_type`) — each its own table — with no `staff` model/data/controller (`staff/presentation/staff_page.dart` watches all three controllers). `roles`/`employees` CRUDs are insert/update only, no delete; `role_modules` is insert/delete only, no update (`RoleModulesController.setAssigned` posts `rmod_type: 'I'` to assign a screen to a role, `'D'` to unassign — the third table is a role x screen matrix, one switch per cell, no editor dialog). Backend quirks to know about: (1) neither insert SP applies every field — `role_available` and `empl_available` are only settable via update, so the create forms hide those fields entirely; `empl_password` *is* accepted on employee insert (confirmed with backend — the create form requires it) even though it isn't in the `fun_admin_employee_crud` insert snippet originally documented, so if insert ever starts silently dropping it again, that SP is the first place to check; (2) `fun_admin_employee_crud`'s update branch does an unconditional `SET empl_password = var_empl_password` with no "keep existing value" guard, so `EmployeesRepository.updateEmployee` omits the `empl_password` key from the request entirely unless the user typed a new one — sending it blank/null on a routine edit (e.g. toggling availability) would otherwise silently wipe the stored hash. (2) is still flagged for backend confirmation, not settled behavior. `premises/employee/<premId>` also always appends a synthetic `empl_id: 0`/"Admin" row (`UNION ALL`, not a real `EMPLOYEE` record) that `EmployeesRepository.getByPremise` filters out before it reaches the UI. The permissions matrix's columns are dynamic (driven by however many rows `premises/system-module` returns, currently 3) — `_PermissionsTable` uses fixed-width columns inside `ScrollableTable` rather than the `_Col`/flex header the other two tables use, since a flex split doesn't fit an open-ended column count.

Employee emails are locked to a fixed `@clickEat.com` domain (`_kEmailDomain` in `staff_page.dart`) — the editor's email field only lets the admin type the local part (via `_TextInput`'s `suffixText`), and `_emailLocalPart()` strips the domain back off an existing employee's email for display, normalizing any legacy non-`@clickEat.com` address the next time it's edited and saved. `_EmployeeEditor` is a `ConsumerStatefulWidget` (unlike the other editors here, which are plain `StatefulWidget`s) so it can call `EmployeesRepository.emailExists` (`premises/employee-validate-email?empl_email=<email>`) directly and block "Guardar" on a duplicate before popping the dialog — it skips that check when editing without changing the email, since re-validating an unchanged address would otherwise match the employee's own row and false-positive as a duplicate.

**Reports** (`/app/reports/*`) is read-only — `ReportsRepository` has no `_crud`/mutate methods, only `GET`s. Each of the 6 report screens (daily dashboard, sales, orders, products, categories, propinas) has its own `StateNotifier` controller with a two-step flow: `loadParameters()` fetches filter option catalogs (via `reports/parameter/*` endpoints, e.g. premises, order types/states, payments, cancellation reasons, products/categories/sizes/options, employees) and defaults every filter to "select all", but does **not** fetch report data; the user then stages filter changes (`applyX(...)` setters, no fetch) and explicitly triggers the query via `search()`. Report data endpoints (`reports/daily`, `reports/sales`, `reports/orders`, `reports/product`, `reports/product-category`) accept the staged filters as repeated query params, omitting any empty selection entirely rather than sending `[]`/`null`. Each also has a paginated `*-export` sibling endpoint (`reports/sales-export`, etc.) behind both the on-screen detail table and a CSV button — pass `allRecords: true` to fetch every row unpaginated for CSV, or `page: N` for the 100-rows/page on-screen table; responses come back wrapped in `PagedRows` (rows + optional `ReportPagination`). The sidebar hides the global premise selector on `/app/reports/*` routes since each report has its own premise filter instead.

**Propinas** (`reports/tips-export`) breaks the pattern above: it's the only report with no separate KPI/chart-shaped data endpoint (its `ReportView` sets empty `kpis`/`charts` — just the detail table) and no server-side pagination at all — `tips-export` always returns the full matching row set, so `TipsReportController` has no `goToTablePage`/`PagedRows` and its "Exportar CSV" button reuses the already-loaded `state.rows` instead of issuing a second `allRecords: true` request. Its PDF export also keeps the table (the other reports strip it via `ReportView.copyWith(headers: [], rows: [])`, since with no KPIs/charts there'd be nothing left to render).

Each report type builds a `ReportView` (`models/report_view.dart`: KPIs, charts, optional bucket rows, table headers/rows) from its own model — this is the shared shape both the on-screen widget (`daily_report_view.dart`, `sales_report_view.dart`, etc.) and the PDF exporter (`presentation/report_pdf.dart`'s `buildReportPdfBytes`) render from, so the two stay visually in sync without duplicating layout logic per report. `report_pdf.dart` re-implements the card/chart/table look with the `pdf` package's own widget set (`pw.*`) and hand-mirrors `AppColors` as `PdfColor` constants — it can't reuse Flutter widgets directly. Keep this in mind when changing a report's on-screen layout: the PDF version needs the equivalent change made separately in `report_pdf.dart`.

### CRUD endpoint convention

Mutating endpoints take a single `*_type` discriminator string — `I` (insert), `U` (update), `D` (delete) — alongside the row fields, rather than separate REST verbs/paths. The field name varies per feature (`prodc_type` categories, `prep_type` preparation areas, `var_sect_type` tables/section-tables, `paym_type` payments, `tips_type` tips, `reas_type` cancellation reasons). Repositories funnel all three operations through one private `_crud(...)` helper that posts the body and throws `Exception(message)` on a non-`state==1` envelope. Every operation (I/U/D) carries `prem_id`. Follow this shape for new CRUD features instead of inventing per-operation methods.

The newer order-related features (`tips`, `reasons`) live under `orders/*` paths: list `orders/<thing>/<premId>`, mutate `orders/<thing>-crud` (e.g. `orders/tips-crud`, `orders/reason-cancel-crud`). Older features post to `<feature>/crud`.

**Controller mutation pattern (used by every premise-scoped controller).** Controllers wrap `_crud` calls two ways: a reload-on-success variant (`_mutate` / `_run`) used for inserts where the new server-assigned id/order matters, and an optimistic variant (`_mutateLocal` / `_runLocal`) used for update/delete that applies an in-memory patch (`_patchX`, or a list filter for delete) so the UI updates without a refetch. To survive premise switches mid-request, `load()` stamps a monotonic `_loadToken` and records the active premise id; both the load result and the optimistic patch bail out if the premise changed while the request was in flight. Naming varies slightly — most controllers use `_activePremId` / `_mutate` / `_mutateLocal`, while `categories` uses `_premId` / `_run` / `_runLocal` — but the structure is identical. Premise-scoped screens react to the selector changing via a `_ensurePremiseLoaded(premId)` helper called at the top of `build()` (see `reasons_page.dart`, `cobros_page.dart`): it compares against a stored `_lastPremId` and, on change, schedules the load through `WidgetsBinding.instance.addPostFrameCallback` (guarded by `mounted`) rather than loading synchronously during build. `shell_page` (session bootstrap) and `login_page` (post-login nav) instead use `Future.microtask` for their one-off, non-premise-driven navigation.

### Product data shape

There are two distinct product models — don't conflate them:

- `Product` (`models/product.dart`) is the flat **list-row** summary returned by `products/<premId>`. The backend has already aggregated the variants: `prodStock` is the summed total, `prodPrice` is a range string (`"149.00 - 1699.00"`, single value when uniform — use `priceDisplay` for the `$`-prefixed form), and `prodAvailable` is a single flag. `prodCategory` is a plain string; the Products page derives the category filter pills from the distinct values in the loaded list.
- `ProductDetail` (`models/product_detail.dart`) is the **full editable** shape, loaded on demand from `products/detail/<premId>/<prodId>`. This is where the per-variant data lives (sizes, options, add-ons and the size×option collection with individual price/stock/availability), plus the premise catalogs (`CategoryOption`, `PrepAreaOption`, `SizeOption`, etc.). For a *new* product, `products/master-data/<premId>` returns a blank `ProductDetail` carrying just those catalogs (`ProductDetail.fromMasterData`).

### Products CRUD & files

`ProductsRepository` covers the full lifecycle: `getByPremise`, `getDetail`, `getMasterData`, `createProduct` (`products/create`, returns the new `prod_id`), `saveProduct` (`products/update`), `deleteProduct` (`products/delete`), and `uploadProductImage` (`files/upload-product-image`, multipart, **.jpg only**). Save/create payloads are built by `ProductDetail.toBackendJson` / `toCreateJson`; create returns the new id specifically so the image can be uploaded as a follow-up call.

CSV export (`data/products_csv.dart` → `core/utils/web_download.dart`) builds one row per list `Product` and triggers a browser download (with a UTF-8 BOM so Excel renders accents). Categories are fetched separately via `CategoriesRepository.getByPremise` (`products/category/<premId>`).

### Responsive layout helpers

`kCompactBreakpoint` (`lib/core/responsive/breakpoints.dart`, 900px) is the single threshold used app-wide: below it `ShellPage` collapses the permanent sidebar into a drawer. Feature tables/pill-filters reuse two shared widgets rather than each reimplementing responsive behavior: `ScrollableTable` (`core/widgets/scrollable_table.dart`) wraps a flex-column table so it scrolls horizontally instead of crushing columns below a given `minWidth`, and `HorizontalPillRow` (`core/widgets/horizontal_pill_row.dart`) lays out filter pills in a single scrollable row instead of wrapping. Used by Products, Categories, Inventory, Printers, Reasons, and Variants — reuse these instead of adding ad hoc `LayoutBuilder`/`SingleChildScrollView` responsive logic per screen.

### Web-only platform code

Image picking and file download are browser-only. The image picker uses a conditional import (`data/image_picker.dart` re-exports `image_picker_stub.dart` or `image_picker_web.dart` based on `dart.library.js_interop`); `web_download.dart` uses `package:web` directly. Keep platform-specific code behind this stub/web split rather than calling `dart:html`/`package:web` from shared code.

## Design system & theming

The UI follows a Claude Design bundle ("ClickEat Admin"). Key tokens live in `AppColors` (`lib/core/theme/app_theme.dart`): `navy #16203B`, `gold #F5B82E`, `green #22C55E`, `amber #F59E0B`, `red #EF4444`, surfaces/lines, and an ink ramp (`ink`/`ink2`/`ink3`/`ink4`). The design uses fully-rounded (pill, radius 99) buttons/search/segments and 16px-radius cards; stat cards carry a 4px left color bar.

`buildTheme()` sets `colorScheme` from `seedColor: navy` with `primary: navy`. Do **not** remove this — without it Material 3 defaults to a purple primary, which leaks into dropdown/popup highlights and splashes. Prefer custom popups (see `_BranchSelector` in `shell_page.dart`) over raw `DropdownButton` to keep the rounded look and avoid default Material highlight colors.
