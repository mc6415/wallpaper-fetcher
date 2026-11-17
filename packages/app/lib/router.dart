import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'features/browse/browse_screen.dart';
import 'features/browse/remote_preview_screen.dart';
import 'features/library/library_detail_screen.dart';
import 'features/library/library_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/browse',
    redirect: (context, state) {
      final hasLibrary = ref.read(libraryRootProvider) != null;
      final atWelcome = state.matchedLocation == '/welcome';
      if (!hasLibrary && !atWelcome) return '/welcome';
      if (hasLibrary && atWelcome) return '/browse';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse',
                builder: (_, _) => const BrowseScreen(),
                routes: [
                  GoRoute(
                    path: 'preview',
                    redirect: (_, state) => state.extra is RemoteWallpaper ? null : '/browse',
                    builder: (_, state) => RemotePreviewScreen(wallpaper: state.extra! as RemoteWallpaper),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => LibraryDetailScreen(id: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())],
          ),
        ],
      ),
    ],
  );
});

/// Navigation rail on wide windows, bottom bar on narrow ones (phones).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.explore_outlined, selected: Icons.explore, label: 'Browse'),
    (icon: Icons.photo_library_outlined, selected: Icons.photo_library, label: 'Library'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.9,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }
        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
            ],
          ),
        );
      },
    );
  }
}
