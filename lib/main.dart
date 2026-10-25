import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/location/location_service.dart';
import 'core/state/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/events/events_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/nearby/nearby_screen.dart';
import 'features/onboarding/onboarding_overlay.dart';
import 'features/profile/profile_screen.dart';

final Map<String, String> _appHandleStorage = <String, String>{};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final controller = AppController(
    handleStorage: _appHandleStorage,
    locationService: const GeolocatorLocationService(),
    maxImageBytes: config.maxImageBytes,
  );
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

class _ProximityAppState extends State<ProximityApp>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final GlobalKey _nearbyTabKey = GlobalKey();
  final GlobalKey _exploreTabKey = GlobalKey();
  final GlobalKey _createTabKey = GlobalKey();
  final GlobalKey _inboxTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();

  late final List<GlobalKey> _tutorialTargetKeys = <GlobalKey>[
    _nearbyTabKey,
    _exploreTabKey,
    _createTabKey,
    _inboxTabKey,
    _profileTabKey,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerUpdates);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdates);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleControllerUpdates() {
    final requestedTab = widget.controller.consumeRequestedTabIndex();
    if (requestedTab != null && requestedTab != _selectedIndex && mounted) {
      setState(() => _selectedIndex = requestedTab);
    }

    final deepLinkEventId = widget.controller.pendingDeepLinkEventId;
    if (deepLinkEventId != null && mounted) {
      widget.controller.clearPendingDeepLinkEvent();
      setState(() => _selectedIndex = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final event = widget.controller.eventById(deepLinkEventId);
        if (event != null && !event.isEnded && mounted) {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => FractionallySizedBox(
              heightFactor: 0.88,
              child: EventDetailSheet(
                controller: widget.controller,
                eventId: event.id,
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This event is ended, deleted, or unavailable.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setAppLifecycleActive(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isAuthenticated) {
          return MaterialApp(
            title: 'Proximity',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: widget.controller.themeMode,
            home: AuthScreen(controller: widget.controller),
          );
        }

        final pendingCount = widget.controller.pendingDmRequests.length;
        final pages = <Widget>[
          NearbyScreen(controller: widget.controller, config: widget.config),
          ExploreEventsScreen(
            controller: widget.controller,
            config: widget.config,
          ),
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
          themeMode: widget.controller.themeMode,
          home: Stack(
            children: <Widget>[
              Scaffold(
                body: pages[_selectedIndex],
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => _selectedIndex = idx),
                  destinations: <Widget>[
                    NavigationDestination(
                      key: _nearbyTabKey,
                      icon: const Icon(Icons.forum_outlined),
                      selectedIcon: const Icon(Icons.forum),
                      label: 'Nearby',
                    ),
                    NavigationDestination(
                      key: _exploreTabKey,
                      icon: const Icon(Icons.explore_outlined),
                      selectedIcon: const Icon(Icons.explore),
                      label: 'Explore',
                    ),
                    NavigationDestination(
                      key: _createTabKey,
                      icon: const Icon(Icons.add_circle_outline),
                      selectedIcon: const Icon(Icons.add_circle),
                      label: 'Create',
                    ),
                    NavigationDestination(
                      key: _inboxTabKey,
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
                    NavigationDestination(
                      key: _profileTabKey,
                      icon: const Icon(Icons.shield_outlined),
                      selectedIcon: const Icon(Icons.shield),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
              if (widget.controller.isOnboardingActive)
                OnboardingOverlay(
                  controller: widget.controller,
                  targetKeys: _tutorialTargetKeys,
                  onStepChanged: (stepIndex) {
                    setState(() {
                      _selectedIndex = stepIndex;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
