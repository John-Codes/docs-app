import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/error_reports/error_reporter.dart';
import 'features/local_ai/local_ai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();
  _installGlobalErrorReporting();
  runApp(const DocsApp());
  // Boots the on-device engine in the background; never blocks the UI and
  // never breaks the cloud app if it fails.
  unawaited(startLocalAi());
}

/// Every uncaught Flutter or platform error goes to the error log, not to a
/// console nobody has open on a phone.
void _installGlobalErrorReporting() {
  FlutterError.onError = (details) {
    reportClientError(
      'flutter_error',
      'global',
      error: details.exception,
      extra: {'library': details.library ?? '', 'context': details.context.toString()},
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reportClientError('platform_error', 'global', error: error);
    return true;
  };
}

class DocsApp extends StatelessWidget {
  const DocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Docs',
        debugShowCheckedModeBanner: false,
        theme: lightTheme(),
        darkTheme: darkTheme(),
        themeMode: themeController.mode,
        home: const AppShell(),
      ),
    );
  }
}
