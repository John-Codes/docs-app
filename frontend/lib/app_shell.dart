import 'package:flutter/material.dart';

import 'core/theme/theme_controller.dart';
import 'features/chat/chat_page.dart';
import 'features/library/library_page.dart';
import 'features/local_ai/local_ai.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [LibraryPage(), ChatPage()];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded, size: 22),
            SizedBox(width: 10),
            Text('Docs'),
          ],
        ),
        actions: [
          const OfflineBadge(),
          IconButton(
            tooltip: 'Toggle dark mode',
            onPressed: themeController.toggle,
            icon: Icon(
              themeController.mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: OfflineAwareBody(
        child: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.library_books_outlined),
                      selectedIcon: Icon(Icons.library_books_rounded),
                      label: Text('Library'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.forum_outlined),
                      selectedIcon: Icon(Icons.forum_rounded),
                      label: Text('Chat'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: _index, children: _pages),
                ),
              ],
            )
          : IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books_rounded),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.forum_outlined),
                  selectedIcon: Icon(Icons.forum_rounded),
                  label: 'Chat',
                ),
              ],
            ),
    );
  }
}
