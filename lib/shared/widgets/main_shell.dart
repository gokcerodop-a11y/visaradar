import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/locale.dart';
import '../../features/stays/presentation/stays_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the stays coordinator alive throughout the app session so that GPS
    // country changes are automatically recorded to the stay history.
    ref.watch(staysCoordinatorProvider);
    final isTr = ref.watch(isTurkishProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Radar',
          ),
          NavigationDestination(
            icon: const Icon(Icons.public_outlined),
            selectedIcon: const Icon(Icons.public),
            label: isTr ? 'Ülkeler' : 'Countries',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt),
            label: isTr ? 'Asistan' : 'Assistant',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: isTr ? 'Ayarlar' : 'Settings',
          ),
        ],
      ),
    );
  }
}
