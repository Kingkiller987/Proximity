import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/core/theme/app_theme.dart';
import 'package:proximity_app/features/events/events_screen.dart';
import 'package:proximity_app/features/inbox/inbox_screen.dart';
import 'package:proximity_app/features/nearby/nearby_screen.dart';
import 'package:proximity_app/features/profile/profile_screen.dart';

void main() {
  group('AppTheme light theme tests', () {
    test('AppTheme.light() provides correct light-mode configuration', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.dialogTheme.backgroundColor, Colors.white);
      expect(theme.bottomSheetTheme.backgroundColor, Colors.white);
      expect(theme.navigationBarTheme.backgroundColor, Colors.white);

      final colors = theme.extension<AppColorsExtension>();
      expect(colors, isNotNull);
      expect(colors!.canvas, const Color(0xFFF8FAFC));
      expect(colors.surface, Colors.white);
      expect(colors.card, Colors.white);
      expect(colors.textPrimary, const Color(0xFF0F172A));
      expect(colors.textSecondary, const Color(0xFF334155));
      expect(colors.textMuted, const Color(0xFF64748B));
    });

    test('ThemeMode persistence in AppController', () async {
      final storage = <String, String>{};
      final controller = AppController(handleStorage: storage);
      addTearDown(controller.dispose);

      // Default themeMode is dark
      expect(controller.themeMode, ThemeMode.dark);

      // Change to light mode
      controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);
      expect(storage['app_theme_mode'], 'light');

      // Re-initialize controller with storage containing 'light'
      final reloadedController = AppController(handleStorage: storage);
      addTearDown(reloadedController.dispose);
      expect(reloadedController.themeMode, ThemeMode.light);
    });

    testWidgets(
      'ProfileScreen renders with light theme surfaces and controls',
      (tester) async {
        final controller = AppController();
        addTearDown(controller.dispose);
        controller.setThemeMode(ThemeMode.light);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
            home: ProfileScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // Check scaffold background
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, isNull);

        // Verify segmented button has Light selected
        final segmentedFinder = find.byKey(
          const Key('settings-theme-segmented'),
        );
        expect(segmentedFinder, findsOneWidget);
        final segmented = tester.widget<SegmentedButton<ThemeMode>>(
          segmentedFinder,
        );
        expect(segmented.selected, <ThemeMode>{ThemeMode.light});

        // Verify cards have white backgrounds
        final cardFinder = find.byType(Card);
        expect(cardFinder, findsWidgets);
        final firstCard = tester.widget<Card>(cardFinder.first);
        final cardColor = firstCard.color ?? AppTheme.light().cardTheme.color;
        expect(cardColor, Colors.white);
      },
    );

    testWidgets('NearbyScreen renders cleanly under light theme', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light,
          home: NearbyScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NearbyScreen), findsOneWidget);
      expect(find.text('Nearby Pulse'), findsOneWidget);
    });

    testWidgets('InboxScreen renders cleanly under light theme', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light,
          home: InboxScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Inbox & Requests'), findsOneWidget);
    });

    testWidgets('ExploreEventsScreen renders cleanly under light theme', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light,
          home: ExploreEventsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExploreEventsScreen), findsOneWidget);
      // Switch to List mode to inspect search and filter controls
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('explore-event-search-field')),
        findsOneWidget,
      );
    });
  });
}
