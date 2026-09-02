// DEV-ONLY visual-parity gallery — NOT part of the example app proper.
//
// Renders the V2 screens with fixed demo data so iOS↔Flutter screenshot
// pairs can be captured deterministically (no backend state required):
//
//   flutter run -t lib/parity_gallery.dart
//
// The numbered buttons across the top switch screens; the claim flow page is
// live, so CONTINUE walks its real steps (about you → address → photo →
// review). Because this drives SDK-internal widgets directly it imports
// implementation files — fine for a dev harness, never for an integration.
//
// ignore_for_file: implementation_imports

import 'package:avafli_sdk/src/domain/giveaway.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';
import 'package:flutter/material.dart';

const _giveaway = Giveaway(
  id: 'demo',
  title: 'Demo Giveaway',
  period: GiveawayPeriod.monthly,
  maxDailyBaseEntries: 300,
  doublingEnabled: false,
  streakConfig: StreakConfig(),
  streakLadder: [10, 30, 60, 130, 240, 300, 500],
  milestones: [MilestoneConfig(day: 7, bonusEntries: 25)],
  prizeDescription: '',
  prizeValue: 1000,
  rulesUrl: 'https://example.com/rules',
);

void main() => runApp(const ParityGalleryApp());

class ParityGalleryApp extends StatelessWidget {
  const ParityGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ParityGallery(),
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    );
  }
}

class ParityGallery extends StatefulWidget {
  const ParityGallery({super.key});

  @override
  State<ParityGallery> createState() => _ParityGalleryState();
}

class _ParityGalleryState extends State<ParityGallery> {
  /// Screenshot automation: `--dart-define=PARITY_PAGE=n` opens page n.
  int _page = const int.fromEnvironment('PARITY_PAGE');

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final accent = AvafliV2Accent(null).color;
    final pages = <String, Widget Function()>{
      'Capture': () => _drawer(
            AvafliV2CaptureView(
              accent: accent,
              logoUrl: null,
              rulesUrl: _giveaway.rulesUrl,
              giveaway: _giveaway,
              isSubmitting: false,
              onSubmit: (
                email, {
                required ageConfirmed,
                required marketingConsent,
              }) {},
              onInfo: _noop,
              onClose: _noop,
            ),
          ),
      'Dash': () => _drawer(
            AvafliV2DashboardView(
              accent: accent,
              logoUrl: null,
              rulesUrl: _giveaway.rulesUrl,
              giveaway: _giveaway,
              streakDay: 3,
              totalEntries: 240,
              entriesToday: 60,
              ladder: _giveaway.streakLadder,
              claimedToday: true,
              onInfo: _noop,
              onClose: _noop,
            ),
          ),
      'Splash': () => AvafliV2WinnerSplashView(
            accent: accent,
            logoUrl: null,
            prizeHeadline: r'$1,000.00 CASH PRIZE',
            onContinue: _noop,
            onClose: _noop,
          ),
      'Claim': () => _claimFlow(accent, initialStep: 1),
      'Photo': () => _claimFlow(accent, initialStep: 3),
      'Confirm': () => AvafliV2ClaimConfirmationView(
            accent: accent,
            logoUrl: null,
            form: AvafliPrizeClaimForm(
              firstName: 'Catherine',
              lastName: 'Cinosta',
              city: 'Brooklyn',
              state: 'New York',
            ),
            claimNumber: '9823457758',
            submittedAt: '2026-09-01T12:00:00Z',
            onDone: _noop,
          ),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  TextButton(
                    onPressed: () => setState(() => _page = i),
                    child: Text(
                      pages.keys.elementAt(i),
                      style: TextStyle(
                        fontSize: 12,
                        color: i == _page ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            // KeyedSubtree so switching pages fully remounts (one-shot
            // celebration effects replay per visit).
            child: KeyedSubtree(
              key: ValueKey(_page),
              child: pages.values.elementAt(_page)(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimFlow(Color accent, {required int initialStep}) {
    return AvafliV2ClaimStepsFlow(
      accent: accent,
      logoUrl: null,
      maskedEmail: 'c******a@avafli.example.com',
      initialForm: AvafliPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
      ),
      initialStep: initialStep,
      isSubmitting: false,
      submitError: null,
      onSubmit: (_) {},
      onClose: _noop,
    );
  }

  /// The capture/dashboard screens live inside the gunmetal drawer sheet in
  /// production — reproduce that framing (rounded top, flush sides).
  Widget _drawer(Widget child) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: ColoredBox(color: AvafliV2Colors.gunmetal, child: child),
    );
  }
}
