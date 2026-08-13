import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:ds_clickeat_web_admin/core/errors/error_logger.dart';
import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/router/app_router.dart';
import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';

/// Created up front (instead of letting `ProviderScope` own its container)
/// so the global error handlers below — which run outside the widget tree —
/// can still read the current session's access token for [ErrorLogger.log]
/// (every backend endpoint, `scrip/log-error` included, requires it).
final _container = ProviderContainer();

void main() {
  usePathUrlStrategy();

  String? currentToken() =>
      _container.read(sessionControllerProvider)?.accessToken;

  // Catches framework-level errors (widget build/layout exceptions, e.g. a
  // RenderFlex overflow) that Flutter would otherwise only print to the
  // console.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLogger.log(
      functionName: details.library ?? 'FlutterError',
      message: details.exceptionAsString(),
      parameters: details.stack,
      token: currentToken(),
    );
  };

  // Catches everything else uncaught (async gaps, non-widget exceptions).
  runZonedGuarded(
    () => runApp(UncontrolledProviderScope(container: _container, child: const App())),
    (error, stack) => ErrorLogger.log(
      functionName: 'UncaughtZoneError',
      message: error.toString(),
      parameters: stack,
      token: currentToken(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ClickEat Admin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
