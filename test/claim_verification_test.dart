// Prize-claim email-ownership step (3.2.0 spec, Part A): a six-digit code
// emailed to the address on file, entered before the claim form opens.
//
//   * no `verification` block / `required: false` → today's flow, unchanged;
//   * `required: true` → the code screen, painted at once, then ONE
//     idempotent send;
//   * every outcome of the send and the check has a next action on screen;
//   * the SERVER holds the state — a fresh experience resumes from the block.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/src/domain/claim_verification.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/avafli_api.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/storage/preferences_storage.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/storage/storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_strings.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const _giveawayId = 'gw_123';
const _masked = 'w****r@avafli.example.com';

/// A scriptable backend. Each handler returns a response, a Future of one
/// (to hold a call in flight), or throws the AvafliException under test.
class _ClaimBackend implements NetworkClient {
  PrizeClaimBlock? block;

  Object Function(SendClaimVerificationCodeRequest request)? onSend;
  Object Function(ConfirmClaimVerificationCodeRequest request)? onConfirm;
  Object Function(SubmitPrizeClaimRequest request)? onSubmit;

  final List<ApiRequest<dynamic>> requests = [];

  List<SendClaimVerificationCodeRequest> get sends =>
      requests.whereType<SendClaimVerificationCodeRequest>().toList();
  List<ConfirmClaimVerificationCodeRequest> get confirms =>
      requests.whereType<ConfirmClaimVerificationCodeRequest>().toList();
  List<SubmitPrizeClaimRequest> get submits =>
      requests.whereType<SubmitPrizeClaimRequest>().toList();

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    requests.add(request);
    if (request is GetActiveGiveawayRequest) {
      return GetActiveGiveawayResponse(
        giveaway: _giveaway(),
        claimedToday: true,
        streakDay: 3,
        totalEntries: 40,
        weeklyCurrent: 3,
        monthlyCurrent: 3,
        emailConsentStatus: true,
        prizeClaim: block,
      ) as T;
    }
    // (A local: `is` cannot promote the generic parameter itself.)
    final Object call = request;
    if (call is SendClaimVerificationCodeRequest) {
      return _run(onSend?.call(call));
    }
    if (call is ConfirmClaimVerificationCodeRequest) {
      return _run(onConfirm?.call(call));
    }
    if (call is SubmitPrizeClaimRequest) {
      return _run(onSubmit?.call(call));
    }
    return Completer<T>().future; // anything else: never completes
  }

  Future<T> _run<T>(Object? result) async {
    if (result == null) throw const AvafliException(AvafliError.networkError);
    if (result is Future) return (await result) as T;
    return result as T;
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
      id: _giveawayId,
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

PrizeClaimBlock _block({ClaimVerification? verification}) => PrizeClaimBlock(
      status: 'pending',
      giveawayId: _giveawayId,
      prizeDescription: 'Cash prize',
      prizeValue: 1000,
      maskedEmail: _masked,
      verification: verification,
    );

/// A block whose code went out [sentAgo] ago (60 s resend cooldown, 10 min
/// lifetime — the backend's constants).
ClaimVerification _liveCode({Duration sentAgo = Duration.zero}) {
  final sent = DateTime.now().subtract(sentAgo);
  return ClaimVerification(
    required: true,
    codeSentAt: sent,
    codeExpiresAt: sent.add(const Duration(minutes: 10)),
    resendAvailableAt: sent.add(const Duration(seconds: 60)),
  );
}

AvafliException _rejection(String reason, String message,
        [Map<String, dynamic> extra = const {}]) =>
    AvafliException(
        AvafliError.unknown, message, false, {'reason': reason, ...extra});

Widget _experience(_ClaimBackend backend, PreferencesStorage prefs) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AvafliV2Experience(
      configuration: const AvafliConfiguration(
        apiKey: 'winr_test_key',
        bundleId: 'com.example.test',
        user: AvafliUser(id: 'user-1', firstName: 'Test', lastName: 'User'),
      ),
      networkClient: backend,
      secureStorage: _RegisteredSecureStorage(),
      preferencesStorage: prefs,
      streakEngine: StreakEngine(),
    ),
  );
}

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

/// Drains async work + the step cross-fade (300 ms) without waiting on the
/// splash's endless confetti.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Mounts the experience and waits for the winner splash.
Future<void> _openToSplash(
  WidgetTester tester,
  _ClaimBackend backend,
  PreferencesStorage prefs,
) async {
  await tester.pumpWidget(_experience(backend, prefs));
  await _settle(tester);
  expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text(text));
}

/// Splash CONTINUE, then ONE frame — what the person sees first.
Future<void> _tapClaim(WidgetTester tester) async {
  await _tapText(tester, 'CONTINUE');
  await tester.pump();
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await _settle(tester);
}

TextEditingController _codeField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!;

AvafliV2CodeEntryView _codeView(WidgetTester tester) =>
    tester.widget<AvafliV2CodeEntryView>(find.byType(AvafliV2CodeEntryView));

Future<void> _tapResend(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('code-resend')));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(const ValueKey('code-resend')));
  await tester.pump();
}

/// Unmounts everything, draining whatever timers the last screen left.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(_loadRealFonts);

  late PreferencesStorage prefs;
  late _ClaimBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = PreferencesStorage();
    await prefs.setBool(StorageKeys.emailConfirmed, true);
    backend = _ClaimBackend();
  });

  // -------------------------------------------------------------------------
  // Contract (unit)
  // -------------------------------------------------------------------------

  group('contract', () {
    test('prizeClaim.verification parses; absent → null', () {
      final block = PrizeClaimBlock.fromJson({
        'status': 'pending',
        'giveawayId': _giveawayId,
        'prizeDescription': 'Cash prize',
        'prizeValue': 1000,
        'maskedEmail': _masked,
        'verification': {
          'required': true,
          'codeSentAt': '2026-09-29T12:00:00.000Z',
          'codeExpiresAt': '2026-09-29T12:10:00.000Z',
          'resendAvailableAt': '2026-09-29T12:01:00.000Z',
        },
      });
      expect(block.requiresVerification, isTrue);
      expect(
          block.verification!.codeSentAt, DateTime.utc(2026, 9, 29, 12, 0, 0));
      expect(block.verification!.codeExpiresAt,
          DateTime.utc(2026, 9, 29, 12, 10, 0));
      expect(block.verification!.resendAvailableAt,
          DateTime.utc(2026, 9, 29, 12, 1, 0));

      final legacy = PrizeClaimBlock.fromJson({
        'status': 'pending',
        'giveawayId': _giveawayId,
        'prizeDescription': 'Cash prize',
        'prizeValue': 1000,
      });
      expect(legacy.verification, isNull);
      expect(legacy.requiresVerification, isFalse);

      final proven = PrizeClaimBlock.fromJson({
        'status': 'pending',
        'giveawayId': _giveawayId,
        'verification': {'required': false},
      });
      expect(proven.requiresVerification, isFalse);
      expect(proven.verification!.codeSentAt, isNull);
    });

    test('resendWait follows the block and is capped at its own cooldown', () {
      final sent = DateTime.utc(2026, 9, 29, 12, 0, 0);
      final block = ClaimVerification(
        required: true,
        codeSentAt: sent,
        resendAvailableAt: sent.add(const Duration(seconds: 60)),
      );
      expect(block.resendWait(sent.add(const Duration(seconds: 45))),
          const Duration(seconds: 15));
      expect(block.resendWait(sent.add(const Duration(seconds: 90))),
          Duration.zero);
      // A device clock running an hour behind the server's.
      expect(block.resendWait(sent.subtract(const Duration(hours: 1))),
          const Duration(seconds: 60));
      expect(const ClaimVerification(required: true).resendWait(sent),
          Duration.zero);
    });

    test('the two new requests match the backend contract', () {
      final open = SendClaimVerificationCodeRequest(giveawayId: _giveawayId);
      expect(open.endpoint, '/sendClaimVerificationCode');
      expect(open.body, {'giveawayId': _giveawayId});
      expect(open.requiresAuth, isTrue);

      final resend = SendClaimVerificationCodeRequest(
          giveawayId: _giveawayId, resend: true);
      expect(resend.body, {'giveawayId': _giveawayId, 'resend': true});

      final confirm = ConfirmClaimVerificationCodeRequest(
          giveawayId: _giveawayId, code: '123456');
      expect(confirm.endpoint, '/confirmClaimVerificationCode');
      expect(confirm.body, {'giveawayId': _giveawayId, 'code': '123456'});

      final sent = SendClaimVerificationCodeResponse.fromJson({
        'sent': true,
        'verification': {
          'required': true,
          'codeSentAt': '2026-09-29T12:00:00.000Z',
          'resendAvailableAt': '2026-09-29T12:01:00.000Z',
        },
      });
      expect(sent.sent, isTrue);
      expect(sent.verification!.required, isTrue);

      final verified = ConfirmClaimVerificationCodeResponse.fromJson({
        'verified': true,
        'verification': {'required': false},
      });
      expect(verified.verified, isTrue);
      expect(verified.verification!.required, isFalse);
    });

    test('submitPrizeClaim always sends supportsClaimVerification: true', () {
      final request = SubmitPrizeClaimRequest(
        giveawayId: _giveawayId,
        firstName: 'Sam',
        lastName: 'Winner',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
        country: 'United States',
      );
      expect(request.body['supportsClaimVerification'], isTrue);
    });

    test('the mismatch copy counts the tries left', () {
      expect(AvafliV2Strings.claimCodeMismatch(4),
          "That code didn't match. 4 tries left.");
      expect(AvafliV2Strings.claimCodeMismatch(1),
          "That code didn't match. 1 try left.");
    });
  });

  // -------------------------------------------------------------------------
  // Network layer: callable error `details` reach the claim flow
  // -------------------------------------------------------------------------

  group('NetworkClientImpl error details', () {
    late int httpCalls;

    NetworkClientImpl client(int status, Map<String, dynamic> error) {
      httpCalls = 0;
      return NetworkClientImpl(
        baseURL: 'https://example.test',
        apiKey: 'winr_test_key',
        client: MockClient((request) async {
          httpCalls++;
          return http.Response(jsonEncode({'error': error}), status);
        }),
      )..setRefreshHandler(() async => 'fresh-token');
    }

    Future<AvafliException> failureOf(NetworkClientImpl client) async {
      try {
        await client.send(ConfirmClaimVerificationCodeRequest(
            giveawayId: _giveawayId, code: '123456'));
      } on AvafliException catch (e) {
        return e;
      }
      fail('expected an AvafliException');
    }

    test('a wrong code (403) surfaces reason + tries, with no retry', () async {
      final e = await failureOf(client(403, {
        'status': 'PERMISSION_DENIED',
        'message': "That code didn't match. Check the email and try again.",
        'details': {'reason': 'code_mismatch', 'attemptsRemaining': 4},
      }));
      expect(e.reason, 'code_mismatch');
      expect(e.details!['attemptsRemaining'], 4);
      expect(e.serverMessage,
          "That code didn't match. Check the email and try again.");
      expect(e.transport, isFalse);
      // Never the token-refresh retry — that would re-submit the code and
      // burn another try.
      expect(httpCalls, 1);
    });

    test('a resend cooldown (429) surfaces retryAfterSeconds, with no backoff',
        () async {
      final e = await failureOf(client(429, {
        'status': 'RESOURCE_EXHAUSTED',
        'message': 'Please wait 42 seconds before requesting another code.',
        'details': {'reason': 'resend_cooldown', 'retryAfterSeconds': 42},
      }));
      expect(e.reason, 'resend_cooldown');
      expect(e.details!['retryAfterSeconds'], 42);
      expect(httpCalls, 1);
    });

    test('fresh_code_sent carries the new verification block', () async {
      final e = await failureOf(client(400, {
        'status': 'FAILED_PRECONDITION',
        'message':
            'That code expired, so we sent you a new one. Check your email.',
        'details': {
          'reason': 'fresh_code_sent',
          'verification': {
            'required': true,
            'codeSentAt': '2026-09-29T12:00:00.000Z',
            'resendAvailableAt': '2026-09-29T12:01:00.000Z',
          },
        },
      }));
      expect(e.reason, 'fresh_code_sent');
      final block = ClaimVerification.fromJson(
          e.details!['verification'] as Map<String, dynamic>);
      expect(block.required, isTrue);
      expect(block.resendAvailableAt, DateTime.utc(2026, 9, 29, 12, 1, 0));
    });

    test('errors without a reason map exactly as before', () async {
      final expired = await failureOf(client(400, {
        'status': 'FAILED_PRECONDITION',
        'message': 'The claim window for this prize has expired',
      }));
      expect(expired.error, AvafliError.unknown);
      expect(expired.reason, isNull);
      expect(expired.details, isNull);
      expect(
          expired.serverMessage, 'The claim window for this prize has expired');

      final notWinner = await failureOf(client(403, {
        'status': 'PERMISSION_DENIED',
        'message': 'Not the winner',
      }));
      expect(notWinner.error, AvafliError.unknown);
      expect(notWinner.reason, isNull);

      // Details WITHOUT a reason change nothing either (409 already-exists).
      final duplicate = await failureOf(client(409, {
        'status': 'ALREADY_EXISTS',
        'message': 'Already submitted',
        'details': {'claimNumber': 'C-1'},
      }));
      expect(duplicate.error, AvafliError.ineligibleToday);
      expect(duplicate.reason, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  testWidgets('no verification block → the claim form, exactly as before',
      (tester) async {
    backend.block = _block();
    await _openToSplash(tester, backend, prefs);

    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2ClaimStepsFlow), findsOneWidget);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.byType(AvafliV2CodeEntryView), findsNothing);
    expect(backend.sends, isEmpty);
    await _teardown(tester);
  });

  testWidgets('required: false → the claim form directly', (tester) async {
    backend.block =
        _block(verification: const ClaimVerification(required: false));
    await _openToSplash(tester, backend, prefs);

    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2ClaimStepsFlow), findsOneWidget);
    expect(find.byType(AvafliV2CodeEntryView), findsNothing);
    expect(backend.sends, isEmpty);
    await _teardown(tester);
  });

  testWidgets(
      'required: true → the code screen paints at once with the masked '
      'email, and the send goes out once, without resend', (tester) async {
    backend.block =
        _block(verification: const ClaimVerification(required: true));
    final gate = Completer<SendClaimVerificationCodeResponse>();
    backend.onSend = (_) => gate.future;
    await _openToSplash(tester, backend, prefs);

    await _tapClaim(tester);

    // First frame: the whole screen, not a spinner.
    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(find.text('Enter the 6-digit code we sent to $_masked'),
        findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('code-resend')), findsOneWidget);
    expect(find.byKey(const ValueKey('code-contact-help')), findsOneWidget);
    expect(
        find.textContaining("Can't get to this email? Contact info@avafli.com",
            findRichText: true),
        findsOneWidget);
    expect(find.text(AvafliV2Strings.claimCodeSending), findsOneWidget);
    expect(find.byType(AvafliV2ClaimStepsFlow), findsNothing);

    // The field: numeric, six digits, one-time-code autofill.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.maxLength, 6);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));

    expect(backend.sends, hasLength(1));
    expect(backend.sends.single.body, {'giveawayId': _giveawayId});

    gate.complete(SendClaimVerificationCodeResponse(
        sent: true, verification: _liveCode()));
    await _settle(tester);

    expect(find.text(AvafliV2Strings.claimCodeSending), findsNothing);
    expect(find.text(AvafliV2Strings.claimCodeSent), findsOneWidget);
    expect(backend.sends, hasLength(1));
    await _teardown(tester);
  });

  testWidgets(
      'a live code in the block → still one idempotent send, and no '
      '"Code sent" when the backend re-used it', (tester) async {
    final live = _liveCode(sentAgo: const Duration(seconds: 20));
    backend.block = _block(verification: live);
    backend.onSend = (_) =>
        SendClaimVerificationCodeResponse(sent: false, verification: live);
    await _openToSplash(tester, backend, prefs);

    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(backend.sends, hasLength(1));
    expect(backend.sends.single.resend, isFalse);
    expect(find.text(AvafliV2Strings.claimCodeSent), findsNothing);
    expect(find.text(AvafliV2Strings.claimCodeSending), findsNothing);
    expect(find.text(AvafliV2Strings.claimCodeNetworkError), findsNothing);
    await _teardown(tester);
  });

  testWidgets('a pasted code with a space lands whole and submits',
      (tester) async {
    backend.block = _block(verification: _liveCode());
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: false, verification: _liveCode());
    backend.onConfirm = (_) => Completer<Object>().future;
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    await _typeCode(tester, '123 456');

    expect(_codeField(tester).text, '123456');
    expect(backend.confirms.single.body,
        {'giveawayId': _giveawayId, 'code': '123456'});
    await _teardown(tester);
  });

  testWidgets('the right code → a brief confirmation → the claim form',
      (tester) async {
    backend.block = _block(verification: _liveCode());
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: false, verification: _liveCode());
    backend.onConfirm = (_) => const ConfirmClaimVerificationCodeResponse(
        verified: true, verification: ClaimVerification(required: false));
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();

    expect(backend.confirms, hasLength(1));
    expect(find.text(AvafliV2Strings.claimCodeVerified), findsOneWidget);
    expect(find.byType(AvafliV2ClaimStepsFlow), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    expect(find.byType(AvafliV2ClaimStepsFlow), findsOneWidget);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.byType(AvafliV2CodeEntryView), findsNothing);
    await _teardown(tester);
  });

  testWidgets('a wrong code → the tries left, a cleared field, focus kept',
      (tester) async {
    backend.block = _block(verification: _liveCode());
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: false, verification: _liveCode());
    backend.onConfirm = (_) => throw _rejection(
        'code_mismatch',
        "That code didn't match. Check the email and try again.",
        {'attemptsRemaining': 3});
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    await _typeCode(tester, '111111');

    expect(find.text("That code didn't match. 3 tries left."), findsOneWidget);
    expect(_codeField(tester).text, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue);
    expect(_codeView(tester).isVerifying, isFalse);
    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets(
      'a dead code → the backend already sent a new one: information, not '
      'an error, a cleared field and a restarted countdown', (tester) async {
    // The old code's cooldown is long over: "Send a new code" is unlocked.
    final stale = _liveCode(sentAgo: const Duration(minutes: 9));
    backend.block = _block(verification: stale);
    backend.onSend = (_) =>
        SendClaimVerificationCodeResponse(sent: false, verification: stale);
    const message =
        'That code expired, so we sent you a new one. Check your email.';
    backend.onConfirm = (_) {
      final sent = DateTime.now();
      throw _rejection('fresh_code_sent', message, {
        'verification': {
          'required': true,
          'codeSentAt': sent.toUtc().toIso8601String(),
          'codeExpiresAt':
              sent.add(const Duration(minutes: 10)).toUtc().toIso8601String(),
          'resendAvailableAt':
              sent.add(const Duration(seconds: 60)).toUtc().toIso8601String(),
        },
      });
    };
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);
    expect(_codeView(tester).resendAvailableAt, isNull);
    expect(find.textContaining('Send a new code in', findRichText: true),
        findsNothing);

    await _typeCode(tester, '222222');

    // The server's own words, in the information slot.
    expect(find.text(message), findsOneWidget);
    expect(_codeView(tester).infoText, message);
    expect(_codeView(tester).errorText, isNull);
    expect(_codeField(tester).text, isEmpty);
    expect(_codeView(tester).resendAvailableAt, isNotNull);
    expect(find.textContaining('Send a new code in', findRichText: true),
        findsOneWidget);
    await _teardown(tester);
  });

  testWidgets(
      '"Send a new code" is locked until resendAvailableAt, then sends '
      'with resend: true', (tester) async {
    final live = _liveCode(sentAgo: const Duration(seconds: 50));
    backend.block = _block(verification: live);
    backend.onSend = (request) => SendClaimVerificationCodeResponse(
          sent: request.resend,
          verification: request.resend ? _liveCode() : live,
        );
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    expect(backend.sends, hasLength(1));
    expect(find.textContaining('Send a new code in 0:', findRichText: true),
        findsOneWidget);

    // Locked: a tap sends nothing.
    await _tapResend(tester);
    await _settle(tester);
    expect(backend.sends, hasLength(1));

    // The countdown runs out.
    for (var i = 0; i < 11; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('Send a new code in', findRichText: true),
        findsNothing);

    await _tapResend(tester);
    await _settle(tester);

    expect(backend.sends, hasLength(2));
    expect(
        backend.sends.last.body, {'giveawayId': _giveawayId, 'resend': true});
    expect(find.text(AvafliV2Strings.claimCodeSent), findsOneWidget);
    // …and the fresh code locks the action again.
    expect(find.textContaining('Send a new code in', findRichText: true),
        findsOneWidget);
    await _teardown(tester);
  });

  testWidgets(
      'a resend refused for cooldown → inline message, and the countdown '
      'follows retryAfterSeconds', (tester) async {
    final stale = _liveCode(sentAgo: const Duration(minutes: 5));
    backend.block = _block(verification: stale);
    const message = 'Please wait 30 seconds before requesting another code.';
    backend.onSend = (request) {
      if (request.resend) {
        throw _rejection('resend_cooldown', message, {'retryAfterSeconds': 30});
      }
      return SendClaimVerificationCodeResponse(
          sent: false, verification: stale);
    };
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    await _tapResend(tester);
    await tester.pump();

    expect(find.text(message), findsOneWidget);
    expect(find.byKey(const ValueKey('code-error-retry')), findsNothing);
    expect(find.textContaining('Send a new code in 0:30', findRichText: true),
        findsOneWidget);
    await _teardown(tester);
  });

  testWidgets(
      'a failed send is inline and retryable, and the field stays usable',
      (tester) async {
    backend.block =
        _block(verification: const ClaimVerification(required: true));
    var fail = true;
    backend.onSend = (_) {
      if (fail) {
        throw const AvafliException(AvafliError.networkError, null, true);
      }
      return SendClaimVerificationCodeResponse(
          sent: true, verification: _liveCode());
    };
    backend.onConfirm = (_) => Completer<Object>().future;
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(find.text(AvafliV2Strings.claimCodeNetworkError), findsOneWidget);
    expect(find.text(AvafliV2Strings.claimCodeRetry), findsOneWidget);
    expect(find.text(AvafliV2Strings.claimCodeSending), findsNothing);

    // Retry repeats the same idempotent request.
    fail = false;
    await tester.ensureVisible(find.byKey(const ValueKey('code-error-retry')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('code-error-retry')));
    await _settle(tester);

    expect(backend.sends, hasLength(2));
    expect(backend.sends.last.resend, isFalse);
    expect(find.text(AvafliV2Strings.claimCodeNetworkError), findsNothing);
    expect(find.text(AvafliV2Strings.claimCodeSent), findsOneWidget);

    // A code from an earlier send can still be entered.
    await _typeCode(tester, '123456');
    expect(backend.confirms, hasLength(1));
    await _teardown(tester);
  });

  testWidgets('a failed send leaves the field usable before any retry',
      (tester) async {
    backend.block =
        _block(verification: const ClaimVerification(required: true));
    backend.onSend = (_) => throw _rejection('send_failed',
        "We couldn't send your code just now. Please try again in a minute.");
    backend.onConfirm = (_) => Completer<Object>().future;
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    expect(
        find.text("We couldn't send your code just now. Please try again in a "
            'minute.'),
        findsOneWidget);
    expect(find.text(AvafliV2Strings.claimCodeRetry), findsOneWidget);

    await _typeCode(tester, '123456');
    expect(backend.confirms.single.code, '123456');
    await _teardown(tester);
  });

  testWidgets('a code check that never reached the server keeps what was typed',
      (tester) async {
    backend.block = _block(verification: _liveCode());
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: false, verification: _liveCode());
    backend.onConfirm = (_) =>
        throw const AvafliException(AvafliError.networkError, null, true);
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    await _typeCode(tester, '123456');

    expect(find.text(AvafliV2Strings.claimCodeNetworkError), findsOneWidget);
    expect(_codeField(tester).text, '123456');
    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);

    // VERIFY re-submits what is still in the field.
    await _tapText(tester, 'VERIFY');
    await _settle(tester);
    expect(backend.confirms, hasLength(2));
    await _teardown(tester);
  });

  testWidgets('an expired claim leaves the code screen for the dashboard',
      (tester) async {
    backend.block = _block(verification: _liveCode());
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: false, verification: _liveCode());
    backend.onConfirm = (_) => throw const AvafliException(
        AvafliError.unknown, 'The claim window for this prize has expired');
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    await _typeCode(tester, '123456');
    await _settle(tester);

    expect(find.byType(AvafliV2CodeEntryView), findsNothing);
    expect(find.byType(AvafliV2WinnerSplashView), findsNothing);
    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('Back returns to the splash and sends nothing', (tester) async {
    final live = _liveCode(sentAgo: const Duration(seconds: 5));
    backend.block = _block(verification: live);
    backend.onSend = (_) =>
        SendClaimVerificationCodeResponse(sent: false, verification: live);
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);
    final before = backend.requests.length;

    await tester.tap(find.byIcon(Icons.chevron_left));
    await _settle(tester);

    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    expect(find.byType(AvafliV2CodeEntryView), findsNothing);
    expect(backend.requests.length, before);

    // The claim button resumes on the code screen, the live code still good.
    await _tapClaim(tester);
    await _settle(tester);
    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(backend.sends, hasLength(2));
    expect(backend.sends.every((s) => !s.resend), isTrue);
    await _teardown(tester);
  });

  testWidgets(
      'SUBMIT answered with claim_verification_required → the code screen, '
      'then back to the form with every field intact', (tester) async {
    // The block said nothing was needed; the state changed underneath us.
    backend.block = _block();
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: true, verification: _liveCode());
    backend.onConfirm = (_) => const ConfirmClaimVerificationCodeResponse(
        verified: true, verification: ClaimVerification(required: false));
    var rejectSubmit = true;
    backend.onSubmit = (_) {
      if (rejectSubmit) {
        throw _rejection('claim_verification_required',
            'Verify your email to claim your prize.');
      }
      return Completer<Object>().future;
    };
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);

    // Step 1 (names prefilled by the host app) → step 2.
    await _tapText(tester, 'CONTINUE');
    await _settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '5 Haide Pl.');
    await tester.enterText(fields.at(1), 'Apt 4B');
    await tester.enterText(fields.at(2), 'Brooklyn');
    await tester.enterText(fields.at(3), '11737');
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    await _tapText(tester, 'Select');
    await _settle(tester);
    await tester.tap(find.text('Alabama').last);
    await _settle(tester);
    await _tapText(tester, 'CONTINUE');
    await _settle(tester);
    // Step 3 (photo, optional) → review.
    await _tapText(tester, 'CONTINUE');
    await _settle(tester);
    expect(find.text('ALMOST DONE!'), findsOneWidget);

    await _tapText(tester, 'SUBMIT PRIZE CLAIM');
    await tester.pump();
    await tester.pump();

    expect(backend.submits, hasLength(1));
    expect(backend.submits.single.body['supportsClaimVerification'], isTrue);
    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(find.text('Enter the 6-digit code we sent to $_masked'),
        findsOneWidget);
    await _settle(tester);
    expect(backend.sends, hasLength(1));
    expect(backend.sends.single.resend, isFalse);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    // Back on the review screen they left — nothing to re-type.
    expect(find.byType(AvafliV2CodeEntryView), findsNothing);
    expect(find.text('ALMOST DONE!'), findsOneWidget);

    rejectSubmit = false;
    await _tapText(tester, 'SUBMIT PRIZE CLAIM');
    await tester.pump();

    expect(backend.submits, hasLength(2));
    final first = Map<String, dynamic>.from(backend.submits.first.body);
    final second = Map<String, dynamic>.from(backend.submits.last.body);
    expect(second, first);
    expect(second['firstName'], 'Test');
    expect(second['lastName'], 'User');
    expect(second['street'], '5 Haide Pl.');
    expect(second['apt'], 'Apt 4B');
    expect(second['city'], 'Brooklyn');
    expect(second['state'], 'Alabama');
    expect(second['zip'], '11737');
    await _teardown(tester);
  });

  testWidgets('a form handed back after the code keeps its photo',
      (tester) async {
    final photo = base64Encode(List<int>.filled(16, 7));
    AvafliPrizeClaimForm? submitted;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        child: AvafliV2ClaimStepsFlow(
          accent: const Color(0xFF00A3FF),
          logoUrl: null,
          maskedEmail: _masked,
          initialForm: AvafliPrizeClaimForm(
            firstName: 'Sam',
            lastName: 'Winner',
            street: '5 Haide Pl.',
            city: 'Brooklyn',
            state: 'New York',
            zip: '11737',
            photoBase64: photo,
            promoConsentGranted: true,
          ),
          initialStep: AvafliV2ClaimStepsFlow.reviewStep,
          isSubmitting: false,
          submitError: null,
          onSubmit: (form) => submitted = form,
          onClose: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ALMOST DONE!'), findsOneWidget);
    await _tapText(tester, 'SUBMIT PRIZE CLAIM');

    expect(submitted!.photoBase64, photo);
    expect(submitted!.promoConsentGranted, isTrue);
    expect(submitted!.zip, '11737');
  });

  // -------------------------------------------------------------------------
  // Resume from server state (nothing is stored on the device)
  // -------------------------------------------------------------------------

  testWidgets(
      'closing mid-step stores nothing, and a fresh open resumes on the '
      'code screen with the live code', (tester) async {
    final live = _liveCode(sentAgo: const Duration(seconds: 30));
    backend.block =
        _block(verification: const ClaimVerification(required: true));
    backend.onSend = (_) =>
        SendClaimVerificationCodeResponse(sent: true, verification: live);
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);
    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);

    // Closed (or killed) on the code screen.
    final stored = await SharedPreferences.getInstance();
    final keysBefore = stored.getKeys();
    await _teardown(tester);
    expect((await SharedPreferences.getInstance()).getKeys(), keysBefore);
    expect(keysBefore.where((k) => k.contains('claim') && k.contains('code')),
        isEmpty);
    expect(keysBefore.where((k) => k.contains('verif')), isEmpty);

    // A brand-new experience (new process, or another device): the server
    // hands the state back in the block.
    final reopened = _ClaimBackend()
      ..block = _block(verification: live)
      ..onSend = (_) =>
          SendClaimVerificationCodeResponse(sent: false, verification: live);
    await _openToSplash(tester, reopened, prefs);

    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(reopened.sends, hasLength(1));
    expect(reopened.sends.single.resend, isFalse);
    expect(find.text(AvafliV2Strings.claimCodeSent), findsNothing);
    expect(find.textContaining('Send a new code in 0:', findRichText: true),
        findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('a fresh open after the code was accepted goes to the form',
      (tester) async {
    final reopened = _ClaimBackend()
      ..block = _block(verification: const ClaimVerification(required: false));
    await _openToSplash(tester, reopened, prefs);

    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2ClaimStepsFlow), findsOneWidget);
    expect(reopened.sends, isEmpty);
    await _teardown(tester);
  });

  testWidgets('once verified, the rest of the session does not ask again',
      (tester) async {
    backend.block = _block(verification: _liveCode());
    backend.onSend = (_) => SendClaimVerificationCodeResponse(
        sent: false, verification: _liveCode());
    backend.onConfirm = (_) => const ConfirmClaimVerificationCodeResponse(
        verified: true, verification: ClaimVerification(required: false));
    await _openToSplash(tester, backend, prefs);
    await _tapClaim(tester);
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();
    expect(find.text(AvafliV2Strings.claimCodeVerified), findsOneWidget);

    // Back to the splash during the confirmation, then claim again.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);

    await _tapClaim(tester);
    await _settle(tester);

    expect(find.byType(AvafliV2ClaimStepsFlow), findsOneWidget);
    expect(backend.sends, hasLength(1));
    expect(backend.confirms, hasLength(1));
    await _teardown(tester);
  });
}
