// User-facing error messaging (2.6.0) — Scott's "User Message (UI)" column
// of the Master Field List, executed:
//
//   * email capture: inline validation error + retryable submit failure,
//     with the email-confirmed flag persisted ONLY after a successful submit;
//   * winner claim step 1: first/last-name + optional-phone validation with
//     inline errors;
//   * dashboard notices: transient "already entered today" and the
//     failed-auto-claim notice with TRY AGAIN — the HONEST unclaimed state,
//     never a fabricated local success;
//   * dedicated geo-blocked and session-expired states.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/network/avafli_api.dart';
import 'package:avafli_sdk/src/storage/preferences_storage.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/storage/storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_strings.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// A scriptable backend: each request kind delegates to a closure that
/// returns a response — or throws the AvafliException under test.
class _FakeNetworkClient implements NetworkClient {
  Object Function()? onGetActiveGiveaway;
  Object Function()? onClaim;
  Object Function()? onSubmitEmail;

  int getCalls = 0;
  int claimCalls = 0;
  int submitEmailCalls = 0;

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    if (request is GetActiveGiveawayRequest) {
      getCalls++;
      return _run(onGetActiveGiveaway);
    }
    if (request is ClaimDailyEntriesRequest) {
      claimCalls++;
      return _run(onClaim);
    }
    if (request is SubmitEmailRequest) {
      submitEmailCalls++;
      return _run(onSubmitEmail);
    }
    throw const AvafliException(AvafliError.networkError);
  }

  T _run<T>(Object Function()? handler) {
    if (handler == null) throw const AvafliException(AvafliError.networkError);
    return handler() as T;
  }

  @override
  void setAuthToken(String? token) {}

  @override
  void setRefreshHandler(Future<String?> Function() handler) {}
}

/// Registration handshake already done on this device.
class _RegisteredSecureStorage extends SecureStorage {
  @override
  Future<String?> getUserUuid() async => 'uuid-cached';
}

Giveaway _giveaway() => const Giveaway(
      id: 'g1',
      title: 'Test Giveaway',
      period: GiveawayPeriod.monthly,
      maxDailyBaseEntries: 300,
      doublingEnabled: false,
      streakConfig: StreakConfig(),
      streakLadder: [10, 30, 60, 130, 240, 300, 500],
      prizeDescription: '',
      prizeValue: 1000,
      rulesUrl: 'https://example.com/rules',
    );

GetActiveGiveawayResponse _statusResponse({
  bool claimedToday = false,
  bool emailConsentStatus = true,
  int streakDay = 2,
  int totalEntries = 40,
}) {
  return GetActiveGiveawayResponse(
    giveaway: _giveaway(),
    claimedToday: claimedToday,
    streakDay: streakDay,
    totalEntries: totalEntries,
    weeklyCurrent: streakDay,
    monthlyCurrent: streakDay,
    emailConsentStatus: emailConsentStatus,
  );
}

ClaimDailyEntriesResponse _claimResponse({
  int entries = 30,
  int streakDay = 2,
  int totalEntries = 70,
}) {
  return ClaimDailyEntriesResponse(
    entries: entries,
    streakDay: streakDay,
    totalEntries: totalEntries,
    weeklyCurrent: streakDay,
    monthlyCurrent: streakDay,
  );
}

Widget _experience({
  required NetworkClient client,
  required PreferencesStorage prefs,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AvafliV2Experience(
      configuration: const AvafliConfiguration(
        apiKey: 'winr_test_key',
        bundleId: 'com.example.test',
        user: AvafliUser(id: 'user-1', firstName: 'Test', lastName: 'User'),
      ),
      networkClient: client,
      secureStorage: _RegisteredSecureStorage(),
      preferencesStorage: prefs,
      streakEngine: StreakEngine(),
    ),
  );
}

/// Real bundled faces so the screens measure like production (the
/// test-default Ahem font is far wider and would overflow rows).
Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/avafli_sdk/Inter');
  for (final file in [
    'inter-v20-latin-regular.ttf',
    'inter-v20-latin-500.ttf',
    'inter-v20-latin-600.ttf',
    'inter-v20-latin-700.ttf',
    'inter-v20-latin-800.ttf',
    'inter-v20-latin-900.ttf',
  ]) {
    inter.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await inter.load();
}

/// Drains the mount → load → claim → reveal pipeline (network answers are
/// immediate; the reveal beat is 150ms; drawer slide is 450ms).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(_loadRealFonts);

  late PreferencesStorage prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = PreferencesStorage();
  });

  Future<void> seedConsentedDay2() async {
    await prefs.cacheGiveaway(_giveaway());
    await prefs.saveStreakState(const StreakState(
      currentDay: 2,
      totalEntriesEarned: 40,
      weeklyCurrent: 2,
      monthlyCurrent: 2,
    ));
    await prefs.setBool(StorageKeys.emailConfirmed, true);
  }

  // -------------------------------------------------------------------------
  // Validation rules (unit)
  // -------------------------------------------------------------------------

  group('name validation (Master Field List rule)', () {
    test('accepts letters, spaces, apostrophes, hyphens, periods', () {
      expect(AvafliPrizeClaimForm.isValidName('Catherine'), isTrue);
      expect(AvafliPrizeClaimForm.isValidName("O'Brien"), isTrue);
      expect(AvafliPrizeClaimForm.isValidName('Mary-Jane'), isTrue);
      expect(AvafliPrizeClaimForm.isValidName('J. R.'), isTrue);
      expect(AvafliPrizeClaimForm.isValidName('  Sam  '), isTrue); // trimmed
      // Unicode letters are letters.
      expect(AvafliPrizeClaimForm.isValidName('José'), isTrue);
      expect(AvafliPrizeClaimForm.isValidName('Zoë'), isTrue);
      expect(AvafliPrizeClaimForm.isValidName('François'), isTrue);
    });

    test('rejects digits, symbols, emptiness, and over-length', () {
      expect(AvafliPrizeClaimForm.isValidName(''), isFalse);
      expect(AvafliPrizeClaimForm.isValidName('   '), isFalse);
      expect(AvafliPrizeClaimForm.isValidName('Sam1'), isFalse);
      expect(AvafliPrizeClaimForm.isValidName('a@b'), isFalse);
      expect(AvafliPrizeClaimForm.isValidName('.'), isFalse); // no letter
      expect(AvafliPrizeClaimForm.isValidName('a' * 50), isTrue); // max 50
      expect(AvafliPrizeClaimForm.isValidName('a' * 51), isFalse);
    });
  });

  group('optional phone validation', () {
    test('normalizes to 10 digits, allowing a leading country 1', () {
      expect(AvafliPrizeClaimForm.normalizePhone('5551234567'), '5551234567');
      expect(
        AvafliPrizeClaimForm.normalizePhone('(555) 123-4567'),
        '5551234567',
      );
      expect(
        AvafliPrizeClaimForm.normalizePhone('+1 555 123 4567'),
        '5551234567',
      );
      expect(AvafliPrizeClaimForm.normalizePhone('15551234567'), '5551234567');
      expect(AvafliPrizeClaimForm.normalizePhone('555123'), isNull);
      expect(AvafliPrizeClaimForm.normalizePhone('25551234567'), isNull);
      expect(AvafliPrizeClaimForm.normalizePhone('555123456789'), isNull);
    });

    test('blank stays allowed; junk blocks step 1', () {
      expect(AvafliPrizeClaimForm.isValidOptionalPhone(''), isTrue);
      expect(AvafliPrizeClaimForm.isValidOptionalPhone('   '), isTrue);
      expect(AvafliPrizeClaimForm.isValidOptionalPhone('555'), isFalse);

      final form = AvafliPrizeClaimForm(firstName: 'Sam', lastName: 'Winner');
      expect(form.isStep1Valid, isTrue);
      form.phone = '555';
      expect(form.isStep1Valid, isFalse);
      form.phone = '(555) 123-4567';
      expect(form.isStep1Valid, isTrue);
    });

    test('names gate step 1 with the new rule', () {
      expect(
        AvafliPrizeClaimForm(firstName: 'Sam1', lastName: 'Winner')
            .isStep1Valid,
        isFalse,
      );
      expect(
        AvafliPrizeClaimForm(firstName: 'Sam', lastName: 'W!').isStep1Valid,
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Email capture — inline validation error
  // -------------------------------------------------------------------------

  group('capture email inline error', () {
    Future<void> pumpCapture(WidgetTester tester, {String? submitError}) async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: AvafliV2CaptureView(
            accent: AvafliV2Accent(null).color,
            logoUrl: null,
            rulesUrl: null,
            giveaway: _giveaway(),
            isSubmitting: false,
            submitError: submitError,
            onSubmit: (email,
                {required ageConfirmed, required marketingConsent}) {},
            onInfo: () {},
            onClose: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows only after the field is touched, then live-clears',
        (tester) async {
      await pumpCapture(tester);

      // Typing an invalid value never flashes red mid-keystroke.
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidEmail), findsNothing);

      // Focus lost with an invalid non-empty value → the error appears.
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidEmail), findsOneWidget);

      // Fixing the address clears it immediately.
      await tester.enterText(find.byType(TextField), 'winner@example.com');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidEmail), findsNothing);
    });

    testWidgets('a keyboard submit attempt also surfaces the error',
        (tester) async {
      await pumpCapture(tester);
      await tester.enterText(find.byType(TextField), 'still@wrong');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidEmail), findsOneWidget);
    });

    testWidgets('an empty field dims the CTA but never scolds', (tester) async {
      await pumpCapture(tester);
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidEmail), findsNothing);
      expect(
        tester
            .widget<AvafliV2PillButton>(find.byType(AvafliV2PillButton))
            .enabled,
        isFalse,
      );
    });

    testWidgets('a submit failure renders inline under the field',
        (tester) async {
      await pumpCapture(tester, submitError: AvafliV2Strings.emailSubmitFailed);
      expect(find.text(AvafliV2Strings.emailSubmitFailed), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Claim step 1 — inline field errors
  // -------------------------------------------------------------------------

  group('claim step 1 inline errors', () {
    Future<void> pumpSteps(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: AvafliV2ClaimStepsFlow(
            accent: AvafliV2Accent(null).color,
            logoUrl: null,
            maskedEmail: 'c******a@avafli.example.com',
            initialForm: AvafliPrizeClaimForm(),
            isSubmitting: false,
            submitError: null,
            onSubmit: (_) {},
            onClose: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    bool continueEnabled(WidgetTester tester) => tester
        .widget<AvafliV2PillButton>(find.byType(AvafliV2PillButton))
        .enabled;

    testWidgets('invalid names show the mandated errors and block CONTINUE',
        (tester) async {
      await pumpSteps(tester);
      final fields = find.byType(TextField); // first, last, phone

      await tester.enterText(fields.at(0), 'Sam4');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidFirstName), findsOneWidget);
      expect(continueEnabled(tester), isFalse);

      await tester.enterText(fields.at(1), 'W!nner');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidLastName), findsOneWidget);

      // Fixing both clears the errors and (with a blank phone) enables
      // CONTINUE.
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), "O'Winner");
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidFirstName), findsNothing);
      expect(find.text(AvafliV2Strings.invalidLastName), findsNothing);
      expect(continueEnabled(tester), isTrue);
    });

    testWidgets(
        'a junk phone shows the 10-digit error and blocks CONTINUE; '
        'blank stays allowed', (tester) async {
      await pumpSteps(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), 'Winner');
      await tester.pump();
      expect(continueEnabled(tester), isTrue);

      await tester.enterText(fields.at(2), '555');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidPhone), findsOneWidget);
      expect(continueEnabled(tester), isFalse);

      await tester.enterText(fields.at(2), '(555) 123-4567');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidPhone), findsNothing);
      expect(continueEnabled(tester), isTrue);

      await tester.enterText(fields.at(2), '');
      await tester.pump();
      expect(find.text(AvafliV2Strings.invalidPhone), findsNothing);
      expect(continueEnabled(tester), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Experience — email submit failure keeps the user on capture
  // -------------------------------------------------------------------------

  testWidgets(
      'a failed email submit stays on capture with a retryable error and '
      'does NOT persist the email-confirmed flag', (tester) async {
    final client = _FakeNetworkClient()
      ..onGetActiveGiveaway =
          (() => _statusResponse(emailConsentStatus: false, streakDay: 1))
      ..onSubmitEmail =
          (() => throw const AvafliException(AvafliError.networkError));

    await tester.pumpWidget(_experience(client: client, prefs: prefs));
    await _settle(tester);
    expect(find.byType(AvafliV2CaptureView), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'winner@example.com');
    await tester.tap(find.text('I confirm I am 18 years of age or older'));
    await tester.pump();
    await tester.ensureVisible(find.byType(AvafliV2PillButton));
    await tester.pump();
    await tester.tap(find.byType(AvafliV2PillButton));
    await _settle(tester);

    // Still on capture, honest inline error, nothing persisted.
    expect(find.byType(AvafliV2CaptureView), findsOneWidget);
    expect(find.text(AvafliV2Strings.emailSubmitFailed), findsOneWidget);
    expect(await prefs.getBool(StorageKeys.emailConfirmed), isNot(isTrue));
    expect(client.submitEmailCalls, 1);

    // Retry with the backend healthy: the flag persists ONLY now, and the
    // Day-1 dashboard mounts.
    client
      ..onSubmitEmail = (() => const SubmitEmailResponse())
      ..onGetActiveGiveaway =
          (() => _statusResponse(streakDay: 1, totalEntries: 0))
      ..onClaim =
          (() => _claimResponse(entries: 10, streakDay: 1, totalEntries: 10));
    await tester.tap(find.byType(AvafliV2PillButton));
    await _settle(tester);

    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    expect(find.text(AvafliV2Strings.emailSubmitFailed), findsNothing);
    expect(await prefs.getBool(StorageKeys.emailConfirmed), isTrue);

    await tester.pump(const Duration(seconds: 2));
  });

  // -------------------------------------------------------------------------
  // Experience — failed auto-claim: honest unclaimed state + TRY AGAIN
  // -------------------------------------------------------------------------

  testWidgets(
      'auto-claim transport failure shows the unclaimed dashboard with the '
      'entry-not-recorded notice, and TRY AGAIN re-claims', (tester) async {
    await seedConsentedDay2();
    final client = _FakeNetworkClient()
      ..onGetActiveGiveaway = (() => _statusResponse())
      ..onClaim = (() => throw const AvafliException(AvafliError.networkError));

    await tester.pumpWidget(_experience(client: client, prefs: prefs));
    await _settle(tester);

    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    expect(find.text(AvafliV2Strings.entryNotRecorded), findsOneWidget);
    expect(find.text(AvafliV2Strings.tryAgain), findsOneWidget);
    // No fabricated success: the dashboard is in the unclaimed state.
    expect(
      tester
          .widget<AvafliV2DashboardView>(find.byType(AvafliV2DashboardView))
          .claimedToday,
      isFalse,
    );
    expect(client.claimCalls, 1);

    // TRY AGAIN with the backend healthy → claim lands, notice retires.
    client.onClaim = (() => _claimResponse());
    await tester.tap(find.text(AvafliV2Strings.tryAgain));
    await _settle(tester);

    expect(client.claimCalls, 2);
    expect(find.text(AvafliV2Strings.entryNotRecorded), findsNothing);
    expect(
      tester
          .widget<AvafliV2DashboardView>(find.byType(AvafliV2DashboardView))
          .claimedToday,
      isTrue,
    );

    await tester.pump(const Duration(seconds: 2));
  });

  // -------------------------------------------------------------------------
  // Experience — duplicate same-day entry: transient notice
  // -------------------------------------------------------------------------

  testWidgets(
      'an already-claimed rejection the device did not know about shows the '
      'transient duplicate-entry notice', (tester) async {
    await seedConsentedDay2();
    final client = _FakeNetworkClient()
      ..onClaim =
          (() => throw const AvafliException(AvafliError.ineligibleToday));
    // First status says unclaimed (stale); the re-sync load says claimed.
    client.onGetActiveGiveaway =
        () => _statusResponse(claimedToday: client.getCalls > 1);

    await tester.pumpWidget(_experience(client: client, prefs: prefs));
    await _settle(tester);

    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    expect(find.text(AvafliV2Strings.alreadyEnteredToday), findsOneWidget);
    // No retry affordance on a duplicate — tomorrow is the retry.
    expect(find.text(AvafliV2Strings.tryAgain), findsNothing);

    // Transient: the notice clears itself.
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    expect(find.text(AvafliV2Strings.alreadyEnteredToday), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  // -------------------------------------------------------------------------
  // Experience — dedicated geo-blocked and session-expired states
  // -------------------------------------------------------------------------

  testWidgets(
      'geographyNotAllowed renders the dedicated geo state, not the '
      'generic empty state', (tester) async {
    final client = _FakeNetworkClient()
      ..onGetActiveGiveaway =
          (() => throw const AvafliException(AvafliError.geographyNotAllowed));

    await tester.pumpWidget(_experience(client: client, prefs: prefs));
    await _settle(tester);

    expect(find.byType(AvafliV2GeoBlockedView), findsOneWidget);
    expect(find.text(AvafliV2Strings.geoBlockedHeadline), findsOneWidget);
    expect(find.text(AvafliV2Strings.geoBlockedBody), findsOneWidget);
    expect(find.text('Nothing to see here yet'), findsNothing);
  });

  testWidgets(
      'a dead session renders the session-expired state and RETRY '
      'reloads into the dashboard', (tester) async {
    await seedConsentedDay2();
    final client = _FakeNetworkClient()
      ..onGetActiveGiveaway =
          (() => throw const AvafliException(AvafliError.authenticationFailed));

    await tester.pumpWidget(_experience(client: client, prefs: prefs));
    await _settle(tester);

    expect(find.byType(AvafliV2SessionExpiredView), findsOneWidget);
    expect(find.text(AvafliV2Strings.sessionExpired), findsOneWidget);
    expect(find.text(AvafliV2Strings.retry), findsOneWidget);

    // RETRY with a recovered session → normal dashboard.
    client
      ..onGetActiveGiveaway = (() => _statusResponse())
      ..onClaim = (() => _claimResponse());
    await tester.tap(find.text(AvafliV2Strings.retry));
    await _settle(tester);

    expect(find.byType(AvafliV2SessionExpiredView), findsNothing);
    expect(find.byType(AvafliV2DashboardView), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'other load errors keep the quiet empty state — raw backend '
      'text never renders', (tester) async {
    final client = _FakeNetworkClient()
      ..onGetActiveGiveaway = (() => throw const AvafliException(
          AvafliError.unknown, 'INTERNAL: stack trace soup from the backend'));

    await tester.pumpWidget(_experience(client: client, prefs: prefs));
    await _settle(tester);

    expect(find.byType(AvafliV2EmptyStateView), findsOneWidget);
    expect(
      find.textContaining('INTERNAL', findRichText: true),
      findsNothing,
    );
  });
}
