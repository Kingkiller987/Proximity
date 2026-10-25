import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/state/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/events/events_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/nearby/nearby_screen.dart';
import 'features/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final controller = AppController();
  runApp(ProximityApp(config: config, controller: controller));
}

class ProximityApp extends StatefulWidget {
  const ProximityApp({
    super.key,
    required this.config,
    required this.controller,
  });

  final AppConfig config;
  final AppController controller;

  @override
  State<ProximityApp> createState() => _ProximityAppState();
}

class _ProximityAppState extends State<ProximityApp> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pendingCount = widget.controller.pendingDmRequests.length;
        final pages = <Widget>[
          NearbyScreen(controller: widget.controller),
          ExploreEventsScreen(controller: widget.controller),
          CreateEventScreen(
            controller: widget.controller,
            onCreated: () => setState(() => _selectedIndex = 1),
          ),
          InboxScreen(controller: widget.controller),
          ProfileScreen(controller: widget.controller),
        ];

        return MaterialApp(
          title: 'Proximity',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: pages[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: <Widget>[
                const NavigationDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar),
                  label: 'Nearby',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Explore',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Create',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.inbox_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.inbox),
                  ),
                  label: 'Inbox',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
