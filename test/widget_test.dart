import 'package:flutter/material.dart';
import 'package:saafe_aa_sdk/saafe_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saafe_sdk_flutter_demo/main.dart';

void main() {
  test('validates complete secure consent URLs', () {
    expect(validateConsentUrl(''), isNotNull);
    expect(validateConsentUrl('http://example.com'), isNotNull);
    expect(validateConsentUrl('https:///'), isNotNull);
    expect(validateConsentUrl('https://user:secret@example.com'), isNotNull);
    expect(validateConsentUrl('https://example.com/${'x' * 8192}'), isNotNull);
    expect(
      validateConsentUrl(' https://example.com/login?ecreq=a%2Bb '),
      isNull,
    );
  });

  test(
    'summarizes map and JSON callbacks without consent or personal data',
    () {
      final payload = {
        'type': 'AA',
        'status': 'approved',
        'flowCompleted': true,
        'consentHandle': 'private',
        'redirectUrl': 'https://private.example',
        'userFeedback': 'private',
      };
      expect(callbackSummary(payload), {
        'type': 'AA',
        'status': 'approved',
        'flowCompleted': true,
      });
      expect(
        callbackSummary('{"status":"rejected","consentHandle":"private"}'),
        {'status': 'rejected'},
      );
      expect(callbackSummary('not JSON'), contains('message'));
      expect(callbackSummary(null), contains('message'));
    },
  );

  testWidgets('requires configuration before invoking native SDK', (
    tester,
  ) async {
    await tester.pumpWidget(const SaafeDemoApp());
    await tester.ensureVisible(find.text('Open consent flow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open consent flow'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your registered client ID.'), findsOneWidget);
    expect(
      find.text('Enter the consent URL from your backend.'),
      findsOneWidget,
    );
  });

  testWidgets('recovers from trust denial and passes configuration', (
    tester,
  ) async {
    String? requestedClient;
    SaafeEnvironment? requestedEnvironment;
    await tester.pumpWidget(
      MaterialApp(
        home: ConsentDemoPage(
          launch: (context, clientId, environment, options) async {
            requestedClient = clientId;
            requestedEnvironment = environment;
            throw const SaafeAccessDeniedException(
              'Denied',
              code: 'app_not_allowed',
            );
          },
        ),
      ),
    );
    await fillAndOpen(tester);
    expect(requestedClient, 'registered-demo-client');
    expect(requestedEnvironment, SaafeEnvironment.sandbox);
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.textContaining('app_not_allowed'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  for (final outcome in ['complete', 'cancel', 'error']) {
    testWidgets('handles $outcome callback and allows retry', (tester) async {
      SaafeRedirectOptions? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: ConsentDemoPage(
            launch: (context, clientId, environment, options) async {
              captured = options;
              options.onLoad?.call();
            },
          ),
        ),
      );
      await fillAndOpen(tester);
      expect(captured!.displayMode, DisplayMode.fullPage);
      expect(captured!.showCloseButton, isTrue);
      expect(
        captured!.redirectUrl,
        'https://sandbox.redirection.saafe.in/login?ecreq=test',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      switch (outcome) {
        case 'complete':
          captured!.onComplete?.call({
            'status': 'approved',
            'flowCompleted': true,
          });
        case 'cancel':
          captured!.onCancel?.call();
        case 'error':
          captured!.onError?.call('{"errorCode":"NETWORK_ERROR"}');
      }
      await tester.pumpAndSettle();
      expect(
        find.text(switch (outcome) {
          'complete' => 'Flow completed',
          'cancel' => 'Flow cancelled',
          _ => 'Flow failed',
        }),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> fillAndOpen(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'registered-demo-client',
  );
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'https://sandbox.redirection.saafe.in/login?ecreq=test',
  );
  await tester.ensureVisible(find.text('Open consent flow'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open consent flow'));
  await tester.pump();
}
