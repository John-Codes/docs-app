import 'dart:async';

import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/local_ai/local_ai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();
  runApp(const DocsApp());
  // Boots the on-device engine in the background; never blocks the UI and
  // never breaks the cloud app if it fails.
  unawaited(startLocalAi());
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
