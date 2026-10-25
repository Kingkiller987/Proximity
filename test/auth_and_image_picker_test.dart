import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/media/media_sanitizer.dart';
import 'package:proximity_app/core/media/native_image_picker_helper.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/auth/auth_screen.dart';
import 'package:proximity_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  String? mockPickedPath;
  Map<String, dynamic>? mockLostData;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('proximity_test_images');
    mockPickedPath = null;
    mockLostData = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'pickImage') {
              return mockPickedPath;
            } else if (methodCall.method == 'retrieve' ||
                methodCall.method == 'retrieveLostData') {
              return mockLostData ??
                  <String, dynamic>{'type': 'image', 'path': null};
            }
            return null;
          },
        );
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          null,
        );
  });

  group('Phase 2: NativeImagePickerHelper Tests', () {
    test('Cancellation: platform returns null -> helper returns null without throwing', () async {
      final helper = NativeImagePickerHelper();
      mockPickedPath = null;

      final result = await helper.pickSanitizedImage(
        source: ImageSource.gallery,
      );
      expect(result, isNull);
    });

    test(
      'Valid JPEG with EXIF: helper reads file, sanitizes, and strips metadata',
      () async {
        final helper = NativeImagePickerHelper();
        final jpegWithGpsExif = Uint8List.fromList(<int>[
          0xFF, 0xD8, // SOI
          0xFF, 0xE1, 0x00, 0x14, // APP1 marker + length (20 bytes)
          0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // 'Exif\0\0'
          0x47,
          0x50,
          0x53,
          0x4C,
          0x61,
          0x74,
          0x34,
          0x30,
          0x2E,
          0x39,
          0x31,
          0x35, // mock GPS tag payload
          0xFF,
          0xC0,
          0x00,
          0x0B,
          0x08,
          0x00,
          0x40,
          0x00,
          0x50,
          0x01,
          0x01,
          0x11,
          0x00, // SOF0 (80x64)
          0xFF, 0xD9, // EOI
        ]);

        final file = File('${tempDir.path}/test_with_exif.jpg');
        file.writeAsBytesSync(jpegWithGpsExif);
        mockPickedPath = file.path;

        final result = await helper.pickSanitizedImage(
          source: ImageSource.camera,
        );
        expect(result, isNotNull);
        expect(result!.isValid, isTrue);
        expect(result.hadMetadataStripped, isTrue);
        expect(result.mimeType, equals('image/jpeg'));
        expect(result.sanitizedBytes, isNotNull);
        expect(
          MediaSanitizer.containsExifMetadata(result.sanitizedBytes!),
          isFalse,
        );
      },
    );

    test('Corrupt image payload: helper rejects with invalid result', () async {
      final helper = NativeImagePickerHelper();
      final corruptBytes = Uint8List.fromList(<int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
      ]);
      final file = File('${tempDir.path}/corrupt.jpg');
      file.writeAsBytesSync(corruptBytes);
      mockPickedPath = file.path;

      final result = await helper.pickSanitizedImage(
        source: ImageSource.gallery,
      );
      expect(result, isNotNull);
      expect(result!.isValid, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.sanitizedBytes, isNull);
    });

    test(
      'Oversized image payload (> 5MB): helper rejects before storing',
      () async {
        final helper = NativeImagePickerHelper();
        final oversizedBytes = Uint8List(5 * 1024 * 1024 + 1024); // 5MB + 1KB
        // Set JPEG SOI so format check passes but size limit rejects
        oversizedBytes[0] = 0xFF;
        oversizedBytes[1] = 0xD8;
        final file = File('${tempDir.path}/oversized.jpg');
        file.writeAsBytesSync(oversizedBytes);
        mockPickedPath = file.path;

        final result = await helper.pickSanitizedImage(
          source: ImageSource.gallery,
        );
        expect(result, isNotNull);
        expect(result!.isValid, isFalse);
        expect(result.errorMessage, contains('exceeds maximum allowed size'));
        expect(result.sanitizedBytes, isNull);
      },
    );

    test(
      'Android lost data recovery: recovers and sanitizes payload',
      () async {
        final helper = NativeImagePickerHelper();
        final validJpeg = Uint8List.fromList(<int>[
          0xFF, 0xD8, // SOI
          0xFF,
          0xC0,
          0x00,
          0x0B,
          0x08,
          0x00,
          0x40,
          0x00,
          0x50,
          0x01,
          0x01,
          0x11,
          0x00, // SOF0
          0xFF, 0xD9, // EOI
        ]);
        final file = File('${tempDir.path}/recovered.jpg');
        file.writeAsBytesSync(validJpeg);

        mockLostData = <String, dynamic>{'type': 'image', 'path': file.path};

        final result = await helper.retrieveLostSanitizedImage();
        expect(result, isNotNull);
        expect(result!.isValid, isTrue);
        expect(result.sanitizedBytes, isNotNull);
      },
    );
  });

  group('Phase 2: AppController Authentication Contract', () {
    test('Default initial state opens authenticated with seeded "Alex"', () {
      final controller = AppController();
      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile.username, equals('Alex'));
      expect(controller.profile.id, equals('user-me'));
    });

    test('Logout clears session and sets isAuthenticated to false', () {
      final controller = AppController();
      controller.logout();
      expect(controller.isAuthenticated, isFalse);
    });

    test(
      'Demo login succeeds case-insensitively for existing mock account',
      () {
        final controller = AppController();
        controller.logout();
        expect(controller.isAuthenticated, isFalse);

        final error = controller.login('alex');
        expect(error, isNull);
        expect(controller.isAuthenticated, isTrue);
        expect(controller.profile.username, equals('Alex'));
      },
    );

    test('Demo login fails with clear demo message for unknown account', () {
      final controller = AppController();
      controller.logout();

      final error = controller.login('unknown_person');
      expect(error, isNotNull);
      expect(error, contains('Demonstration mode'));
      expect(controller.isAuthenticated, isFalse);
    });

    test(
      'Registration input validation and collision-resistant ID generation',
      () {
        final controller = AppController();

        // Short username
        expect(
          controller.register(
            username: 'ab',
            email: 'test@example.com',
            password: 'password123',
          ),
          contains('Username must be 3-20 characters'),
        );

        // Invalid username chars
        expect(
          controller.register(
            username: 'alex!bad',
            email: 'test@example.com',
            password: 'password123',
          ),
          contains('letters, numbers, and underscores'),
        );

        // Case-insensitive collision with existing user 'Alex'
        expect(
          controller.register(
            username: 'ALEX',
            email: 'alex@example.com',
            password: 'password123',
          ),
          contains('already taken'),
        );

        // Invalid email
        expect(
          controller.register(
            username: 'valid_user',
            email: 'bad-email',
            password: 'password123',
          ),
          contains('valid email'),
        );

        // Short password (< 8 chars)
        expect(
          controller.register(
            username: 'valid_user',
            email: 'user@test.com',
            password: '12345',
          ),
          contains('at least 8 characters'),
        );

        // Successful registration
        final regError = controller.register(
          username: 'Jordan_99',
          email: 'jordan@test.com',
          password: 'secure_local_password',
        );
        expect(regError, isNull);
        expect(controller.isAuthenticated, isTrue);
        expect(controller.profile.username, equals('Jordan_99'));
        expect(controller.profile.id, startsWith('user-'));
        expect(controller.profile.id, isNot(equals('user-me')));

        // Rapid registration generates distinct collision-resistant IDs
        controller.register(
          username: 'Jordan_100',
          email: 'j100@test.com',
          password: 'password123',
        );
        final id1 = controller.profile.id;
        controller.register(
          username: 'Jordan_101',
          email: 'j101@test.com',
          password: 'password123',
        );
        final id2 = controller.profile.id;
        expect(id1, isNot(equals(id2)));
      },
    );
  });

  group('Phase 2: AuthScreen Widget and Password Ephemerality', () {
    testWidgets(
      'AuthScreen shows honest demo copy and handles login with password clearing',
      (tester) async {
        final controller = AppController();
        controller.logout();

        await tester.pumpWidget(
          MaterialApp(home: AuthScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Honest demonstration copy present
        expect(find.textContaining('Demonstration'), findsWidgets);

        // Enter login credentials
        final usernameField = find.byKey(const Key('auth-username-field'));
        final passwordField = find.byKey(const Key('auth-password-field'));
        final submitButton = find.byKey(const Key('auth-submit-btn'));

        expect(usernameField, findsOneWidget);
        expect(passwordField, findsOneWidget);
        expect(submitButton, findsOneWidget);

        await tester.enterText(usernameField, 'Alex');
        await tester.enterText(passwordField, 'ephemeral_pass_123');
        await tester.pump();

        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Successful login
        expect(controller.isAuthenticated, isTrue);
        // Password field must be cleared
        final EditableText passwordEditable = tester.widget(
          find.descendant(
            of: passwordField,
            matching: find.byType(EditableText),
          ),
        );
        expect(passwordEditable.controller.text, isEmpty);
      },
    );

    testWidgets(
      'AuthScreen registration switches tab, validates, and registers',
      (tester) async {
        final controller = AppController();
        controller.logout();

        await tester.pumpWidget(
          MaterialApp(home: AuthScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Switch to Create Account / Register tab
        final registerTab = find.byKey(const Key('auth-switch-to-register'));
        expect(registerTab, findsOneWidget);
        await tester.tap(registerTab);
        await tester.pumpAndSettle();

        final usernameField = find.byKey(const Key('auth-username-field'));
        final emailField = find.byKey(const Key('auth-email-field'));
        final passwordField = find.byKey(const Key('auth-password-field'));
        final submitButton = find.byKey(const Key('auth-submit-btn'));

        // Enter invalid data first
        await tester.enterText(usernameField, 'x');
        await tester.enterText(emailField, 'not-an-email');
        await tester.enterText(passwordField, '123');
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Username must be 3-20 characters'),
          findsOneWidget,
        );
        expect(controller.isAuthenticated, isFalse);

        // Enter valid registration data
        await tester.enterText(usernameField, 'TaylorSwift');
        await tester.enterText(emailField, 'taylor@music.com');
        await tester.enterText(passwordField, 'supersecretpass');
        final confirmField = find.byKey(
          const Key('auth-confirm-password-field'),
        );
        if (confirmField.evaluate().isNotEmpty) {
          await tester.enterText(confirmField, 'supersecretpass');
        }
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(controller.isAuthenticated, isTrue);
        expect(controller.profile.username, equals('TaylorSwift'));
      },
    );

    testWidgets(
      'ProximityApp switches to AuthScreen on logout and back on login',
      (tester) async {
        final config = AppConfig.fromEnvironment();
        final controller = AppController();

        await tester.pumpWidget(
          ProximityApp(config: config, controller: controller),
        );
        await tester.pumpAndSettle();

        // Initially authenticated
        expect(find.text('Nearby'), findsWidgets);

        // Simulate logout
        controller.logout();
        await tester.pumpAndSettle();

        // Now AuthScreen is rendered
        expect(find.byType(AuthScreen), findsOneWidget);

        // Log back in
        controller.login('Alex');
        await tester.pumpAndSettle();

        // Returned to main tabs
        expect(find.text('Nearby'), findsWidgets);
      },
    );
  });
}
