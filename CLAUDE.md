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

`lib/core/` holds cross-cutting infra: `env.dart`, `http/dio_client.dart`, `router/app_router.dart`, `theme/app_theme.dart`.

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

Implemented screens: **Products**, **Categories & preparation areas**, **Options/modifications** (`variants` feature), **Inventory**, **Tables & zones** (`tables`), **Cobros** (`cobros`), **Cancellation reasons** (`reasons`), **Branches** (`branches`, under a "Negocio" sidebar section), and **Reports** (`reports`, under a "Reportes" sidebar section with 5 sub-routes: dashboard, ventas, pedidos, productos, categorías). There are no stub/placeholder screens left — every sidebar item routes to a real page.

**Cobros** (`/app/cobros`) is one screen composing two independent features: payment methods (`payments`, `payments/<premId>`) and tip presets (`tips`, `orders/tips/<premId>`), each rendered with the same card layout. There is no `cobros` model/data/controller — `cobros/presentation/cobros_page.dart` watches both the `payments` and `tips` controllers. **Cancellation reasons** (`/app/cancel-reasons`, `reasons` feature, `orders/reason-cancel/<premId>`) renders rows as a table (mirroring the Products table) rather than cards.

**Branches** (`/app/branches`) deviates from the CRUD convention below: `BranchesRepository` only has `getByUser` (`premises/<userId>`), `getDetail` (`premises-detail/<userId>/<premId>`), and `update` (`premises-update`) — there is no insert or delete, and no `*_type` discriminator. `update` always carries `password` (empty string when the user left it unchanged).

**Reports** (`/app/reports/*`) is read-only — `ReportsRepository` has no `_crud`/mutate methods, only `GET`s. Each of the 5 report screens (daily dashboard, sales, orders, products, categories) has its own `StateNotifier` controller with a two-step flow: `loadParameters()` fetches filter option catalogs (via `reports/parameter/*` endpoints, e.g. premises, order types/states, payments, cancellation reasons, products/categories/sizes/options) and defaults every filter to "select all", but does **not** fetch report data; the user then stages filter changes (`applyX(...)` setters, no fetch) and explicitly triggers the query via `search()`. Report data endpoints (`reports/daily`, `reports/sales`, `reports/orders`, `reports/product`, `reports/product-category`) accept the staged filters as repeated query params, omitting any empty selection entirely rather than sending `[]`/`null`. Each also has a paginated `*-export` sibling endpoint (`reports/sales-export`, etc.) behind both the on-screen detail table and a CSV button — pass `allRecords: true` to fetch every row unpaginated for CSV, or `page: N` for the 100-rows/page on-screen table; responses come back wrapped in `PagedRows` (rows + optional `ReportPagination`). The sidebar hides the global premise selector on `/app/reports/*` routes since each report has its own premise filter instead.

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

### Web-only platform code

Image picking and file download are browser-only. The image picker uses a conditional import (`data/image_picker.dart` re-exports `image_picker_stub.dart` or `image_picker_web.dart` based on `dart.library.js_interop`); `web_download.dart` uses `package:web` directly. Keep platform-specific code behind this stub/web split rather than calling `dart:html`/`package:web` from shared code.

## Design system & theming

The UI follows a Claude Design bundle ("ClickEat Admin"). Key tokens live in `AppColors` (`lib/core/theme/app_theme.dart`): `navy #16203B`, `gold #F5B82E`, `green #22C55E`, `amber #F59E0B`, `red #EF4444`, surfaces/lines, and an ink ramp (`ink`/`ink2`/`ink3`/`ink4`). The design uses fully-rounded (pill, radius 99) buttons/search/segments and 16px-radius cards; stat cards carry a 4px left color bar.

`buildTheme()` sets `colorScheme` from `seedColor: navy` with `primary: navy`. Do **not** remove this — without it Material 3 defaults to a purple primary, which leaks into dropdown/popup highlights and splashes. Prefer custom popups (see `_BranchSelector` in `shell_page.dart`) over raw `DropdownButton` to keep the rounded look and avoid default Material highlight colors.
