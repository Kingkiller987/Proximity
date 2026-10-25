import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/profile/profile_screen.dart';
import 'package:proximity_app/features/profile/report_user_dialog.dart';

void main() {
  testWidgets(
    'ReportUserDialog allows selecting all 3 presets and requires explanation',
    (tester) async {
      final controller = AppController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const Key('open-report-dialog-btn'),
                  onPressed: () {
                    ReportUserDialog.show(
                      context,
                      controller: controller,
                      targetId: 'user-bad-actor',
                      targetLabel: '@bad_actor',
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byKey(const Key('open-report-dialog-btn')));
      await tester.pumpAndSettle();

      // Verify dialog elements
      expect(find.text('Report @bad_actor'), findsOneWidget);
      expect(find.byKey(const Key('report-preset-spamming')), findsOneWidget);
      expect(find.byKey(const Key('report-preset-harassment')), findsOneWidget);
      expect(find.byKey(const Key('report-preset-other')), findsOneWidget);
      expect(find.byKey(const Key('report-explanation-field')), findsOneWidget);
      expect(find.byKey(const Key('report-submit-btn')), findsOneWidget);
      expect(find.byKey(const Key('report-cancel-btn')), findsOneWidget);

      // Select Harassment
      await tester.tap(find.byKey(const Key('report-preset-harassment')));
      await tester.pumpAndSettle();

      // Try submitting with empty explanation
      await tester.tap(find.byKey(const Key('report-submit-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-error-text')), findsOneWidget);
      expect(controller.reports, isEmpty);

      // Enter short explanation (< 5 chars)
      await tester.enterText(
        find.byKey(const Key('report-explanation-field')),
        'bad',
      );
      await tester.tap(find.byKey(const Key('report-submit-btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('Explanation must be at least 5 characters.'),
        findsOneWidget,
      );
      expect(controller.reports, isEmpty);

      // Enter valid explanation and submit
      await tester.enterText(
        find.byKey(const Key('report-explanation-field')),
        'Sending repeated unwanted harassment messages.',
      );
      await tester.tap(find.byKey(const Key('report-submit-btn')));
      await tester.pumpAndSettle();

      // Dialog should be dismissed and report added
      expect(find.byType(ReportUserDialog), findsNothing);
      expect(controller.reports.length, 1);
      final report = controller.reports.first;
      expect(report.targetId, 'user-bad-actor');
      expect(report.targetLabel, '@bad_actor');
      expect(report.preset, ReportReasonPreset.harassment);
      expect(
        report.explanation,
        'Sending repeated unwanted harassment messages.',
      );
      expect(report.status, 'Local Demo Ticket (Pending Review)');
    },
  );

  testWidgets('ReportUserDialog handles duplicate report rejection', (
    tester,
  ) async {
    final controller = AppController();

    // Pre-populate with a report
    controller.submitSafetyReport(
      targetId: 'user-spammer',
      targetLabel: '@spammer',
      preset: ReportReasonPreset.spamming,
      explanation: 'Flooding chat with affiliate links.',
    );
    expect(controller.reports.length, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open-report-dialog-btn'),
                onPressed: () {
                  ReportUserDialog.show(
                    context,
                    controller: controller,
                    targetId: 'user-spammer',
                    targetLabel: '@spammer',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.byKey(const Key('open-report-dialog-btn')));
    await tester.pumpAndSettle();

    // Default preset is spamming, enter explanation
    await tester.enterText(
      find.byKey(const Key('report-explanation-field')),
      'More spam advertising from this user.',
    );
    await tester.tap(find.byKey(const Key('report-submit-btn')));
    await tester.pumpAndSettle();

    // Should show duplicate error and stay open
    expect(find.byType(ReportUserDialog), findsOneWidget);
    expect(
      find.text(
        'A report for this user under "Spamming" has already been submitted.',
      ),
      findsOneWidget,
    );
    expect(controller.reports.length, 1);

    // Cancel closes dialog without crash
    await tester.tap(find.byKey(const Key('report-cancel-btn')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportUserDialog), findsNothing);
  });

  testWidgets(
    'Submitted report tickets appear in Profile Miscellaneous section',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = AppController();
      controller.submitSafetyReport(
        targetId: 'user-troll',
        targetLabel: '@troll_master',
        preset: ReportReasonPreset.other,
        explanation: 'Disrupting event with offensive remarks.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Check Miscellaneous section
      expect(
        find.byKey(const Key('settings-section-miscellaneous')),
        findsOneWidget,
      );
      expect(find.text('Report: @troll_master'), findsOneWidget);
      expect(find.text('OTHER'), findsOneWidget);
      expect(
        find.text('Disrupting event with offensive remarks.'),
        findsOneWidget,
      );
      expect(find.text('Local Demo Ticket (Pending Review)'), findsOneWidget);
    },
  );

  test(
    'AppController.submitSafetyReport validation and backwards compatibility',
    () {
      final controller = AppController();

      // Empty explanation
      final err1 = controller.submitSafetyReport(
        targetId: 'user-1',
        targetLabel: '@user1',
        preset: ReportReasonPreset.spamming,
        explanation: '   ',
      );
      expect(err1, 'Explanation is required.');

      // Short explanation
      final err2 = controller.submitSafetyReport(
        targetId: 'user-1',
        targetLabel: '@user1',
        preset: ReportReasonPreset.spamming,
        explanation: 'abc',
      );
      expect(err2, 'Explanation must be at least 5 characters.');

      // Valid submission
      final ok1 = controller.submitSafetyReport(
        targetId: 'user-1',
        targetLabel: '@user1',
        preset: ReportReasonPreset.spamming,
        explanation: 'Spamming advertisement links',
      );
      expect(ok1, isNull);
      expect(controller.reports.length, 1);
      expect(
        controller.reports.first.reason,
        '[SPAMMING] Spamming advertisement links',
      );

      // Duplicate submission
      final dupErr = controller.submitSafetyReport(
        targetId: 'user-1',
        targetLabel: '@user1',
        preset: ReportReasonPreset.spamming,
        explanation: 'More spam ads',
      );
      expect(dupErr, contains('already been submitted'));
      expect(controller.reports.length, 1);

      // Different preset for same user is allowed
      final ok2 = controller.submitSafetyReport(
        targetId: 'user-1',
        targetLabel: '@user1',
        preset: ReportReasonPreset.harassment,
        explanation: 'Now harassing other members in chat',
      );
      expect(ok2, isNull);
      expect(controller.reports.length, 2);
    },
  );
}
