import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_screens.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_theme.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_winner.dart';
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(child: child),
  );
}

Giveaway _giveaway({String? streakMode, GiveawayWinner? winner}) {
  return Giveaway(
    id: 'g1',
    title: 'Test Giveaway',
    period: GiveawayPeriod.monthly,
    maxDailyBaseEntries: 300,
    doublingEnabled: false,
    streakConfig: const StreakConfig(),
    streakLadder: const [10, 30, 60, 130, 240, 300, 500],
    milestones: const [MilestoneConfig(day: 7, bonusEntries: 25)],
    prizeDescription: '',
    prizeValue: 1000,
    rulesUrl: 'https://example.com/rules',
    streakMode: streakMode,
    latestWinner: winner,
  );
}

/// Loads the real bundled Inter/Oswald faces so text measures like production
/// (the test-default Ahem font is much wider and would skew layout).
Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/winr_flutter_sdk/Inter');
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

  final oswald = FontLoader('packages/winr_flutter_sdk/Oswald');
  for (final file in [
    'oswald-v57-latin-500.ttf',
    'oswald-v57-latin-700.ttf',
  ]) {
    oswald.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await oswald.load();
}

void main() {
  setUpAll(_loadRealFonts);

  final accent = WINRV2Accent(null).color;

  testWidgets('capture view renders', (tester) async {
    await tester.pumpWidget(_host(WINRV2CaptureView(
      accent: accent,
      logoUrl: null,
      rulesUrl: null,
      giveaway: _giveaway(),
      isSubmitting: false,
      onSubmit: (_) {},
      onInfo: () {},
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('VISIT. EARN. WIN.'), findsOneWidget);
    expect(find.text('\$1,000.00 CASH PRIZE'), findsOneWidget);
    expect(find.text('CLAIM MY 10 ENTRIES'), findsOneWidget);
    expect(
        find.text('I confirm I am 18 years of age or older'), findsOneWidget);
  });

  testWidgets('dashboard renders with winner banner and rail', (tester) async {
    await tester.pumpWidget(_host(WINRV2DashboardView(
      accent: accent,
      logoUrl: null,
      rulesUrl: null,
      giveaway: _giveaway(
        winner: const GiveawayWinner(
          name: 'Catherine C.',
          location: 'Brooklyn, New York',
          awardedAt: '2026-08-20',
        ),
      ),
      streakDay: 3,
      totalEntries: 100,
      entriesToday: 60,
      ladder: const [10, 30, 60, 130, 240, 300, 500],
      claimedToday: true,
      onInfo: () {},
      onClose: () {},
      onWinnerTap: () {},
    )));
    // Let the rail auto-center timer (350ms) and scroll animation play out.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('WE HAVE A WINNER!'), findsOneWidget);
    expect(find.text('3 DAY STREAK'), findsOneWidget);
    expect(find.text('Total Entries'), findsOneWidget);
    expect(find.text('DAILY PROGRESS'), findsWidgets);
    expect(find.text('GOT IT'), findsOneWidget);
    // Delta A: any claimed-today dashboard state celebrates the added
    // entries in the black bar instead of pitching tomorrow.
    expect(find.text('60 ENTRIES ADDED'), findsOneWidget);
    expect(find.text('You’re on a roll!'), findsOneWidget);
    // Day-7 milestone accelerator tile.
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('EVERY DAY!'), findsOneWidget);
  });

  testWidgets('dashboard Day 2+ pre-reveal holds yesterday, CLAIM reveals',
      (tester) async {
    var revealed = false;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => WINRV2DashboardView(
        accent: accent,
        logoUrl: null,
        rulesUrl: null,
        giveaway: _giveaway(),
        streakDay: 3,
        // Pre-reveal shows the pre-claim total; post-reveal the fresh total.
        totalEntries: revealed ? 100 : 40,
        entriesToday: 60,
        ladder: const [10, 30, 60, 130, 240, 300, 500],
        claimedToday: true,
        onInfo: () {},
        onClose: () {},
        pendingClaimEntries: 60,
        revealed: revealed,
        onClaim: () => setState(() => revealed = true),
      ),
    )));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Pinned to yesterday: streak label N-1, CLAIM pill, no GOT IT.
    expect(find.text('2 DAY STREAK'), findsOneWidget);
    expect(find.text('CLAIM 60 ENTRIES'), findsOneWidget);
    expect(find.text('GOT IT'), findsNothing);

    // Tapping CLAIM is the reveal: label advances, pill becomes GOT IT.
    await tester.ensureVisible(find.text('CLAIM 60 ENTRIES'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CLAIM 60 ENTRIES'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3 DAY STREAK'), findsOneWidget);
    expect(find.text('GOT IT'), findsOneWidget);
    expect(find.text('CLAIM 60 ENTRIES'), findsNothing);
  });

  testWidgets('dashboard visit mode swaps copy', (tester) async {
    await tester.pumpWidget(_host(WINRV2DashboardView(
      accent: accent,
      logoUrl: null,
      rulesUrl: null,
      giveaway: _giveaway(streakMode: 'visit'),
      streakDay: 2,
      totalEntries: 40,
      entriesToday: 30,
      ladder: const [10, 30, 60],
      // Unclaimed keeps the come-back pitch (Delta A only swaps the bar once
      // today's entries are claimed AND revealed).
      claimedToday: false,
      onInfo: () {},
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2 VISIT STREAK'), findsOneWidget);
    expect(find.text('PROGRESS'), findsWidgets);
    expect(find.text('Come back again to receive:'), findsOneWidget);
  });

  testWidgets('celebration modal day 1 vs day 2+', (tester) async {
    await tester.pumpWidget(_host(WINRV2CelebrationModal(
      accent: accent,
      streakDay: 1,
      earnedEntries: 10,
      nextEntries: 30,
      onDismiss: () {},
    )));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('You’re in!'), findsOneWidget);
    expect(find.text('10 ENTRIES HAVE BEEN ADDED'), findsOneWidget);

    await tester.pumpWidget(_host(WINRV2CelebrationModal(
      accent: accent,
      streakDay: 5,
      earnedEntries: 240,
      nextEntries: 300,
      onDismiss: () {},
    )));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('YOU’RE ON A'), findsOneWidget);
    expect(find.text('5 DAY STREAK!'), findsOneWidget);
    expect(find.text('YOU EARNED'), findsOneWidget);
    expect(find.text('Come back tomorrow for'), findsOneWidget);
    expect(find.text('300 ENTRIES'), findsOneWidget);
  });

  testWidgets('winner modal renders with initials fallback', (tester) async {
    await tester.pumpWidget(_host(WINRV2WinnerModal(
      accent: accent,
      winner: const GiveawayWinner(
        name: 'Catherine C.',
        location: 'Brooklyn, New York',
        awardedAt: '2026-08-20',
      ),
      onDismiss: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('WINNER!'), findsOneWidget);
    expect(find.text('LATEST WINNER:'), findsOneWidget);
    expect(find.text('Catherine C.'), findsOneWidget);
    expect(find.text('This prize awarded on August 20, 2026'), findsOneWidget);
    expect(
        find.text('All new prize available now! Keep going!'), findsOneWidget);
    // Initials fallback (no avatarUrl).
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('how it works renders with visit-mode variants', (tester) async {
    await tester.pumpWidget(_host(WINRV2HowItWorksView(
      accent: accent,
      logoUrl: null,
      day1Entries: 10,
      onDone: () {},
      onClose: () {},
    )));
    await tester.pump();
    expect(find.text('HOW IT WORKS'), findsOneWidget);
    expect(find.text('VISIT EVERY DAY'), findsOneWidget);
    expect(find.text('Don’t miss a day - your streak resets if you do.'),
        findsOneWidget);

    await tester.pumpWidget(_host(WINRV2HowItWorksView(
      accent: accent,
      logoUrl: null,
      day1Entries: 10,
      visitMode: true,
      onDone: () {},
      onClose: () {},
    )));
    await tester.pump();
    expect(find.text('KEEP VISITING'), findsOneWidget);
    expect(find.text('Every visit counts - your streak never resets.'),
        findsOneWidget);
  });
}
