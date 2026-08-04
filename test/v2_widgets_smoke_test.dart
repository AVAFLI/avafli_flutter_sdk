import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_effects.dart'
    show WINRV2GifView;
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_experience.dart'
    show winrV2MountRevealDelay;
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
    // Non-celebration open (same-day reopen, no staged grant): the bar rests
    // on the come-back pitch — the toast never shows.
    expect(find.text('YOU’RE ON A ROLL!'), findsNothing);
    expect(
      find.text('Come back tomorrow to\nkeep your streak alive and receive:'),
      findsOneWidget,
    );
    // A tile that MOUNTS already active never replays the confetti burst.
    expect(find.byType(WINRV2GifView), findsNothing);
    // Day-7 milestone accelerator tile.
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('EVERY DAY!'), findsOneWidget);
  });

  testWidgets(
      'dashboard Day 2+ celebration is the FIRST visible frame — toast '
      'before pitch, no CLAIM tap, pill stays GOT IT', (tester) async {
    var revealed = false;
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) {
        rebuild = setState;
        return WINRV2DashboardView(
          accent: accent,
          logoUrl: null,
          rulesUrl: null,
          giveaway: _giveaway(),
          streakDay: 3,
          // The controller stages a PREDICTED grant pre-mount: the readout
          // holds the pre-claim total for one imperceptible beat, then
          // counts up to the predicted post-claim total.
          totalEntries: revealed ? 100 : 40,
          entriesToday: 60,
          ladder: const [10, 30, 60, 130, 240, 300, 500],
          claimedToday: true,
          onInfo: () {},
          onClose: () {},
          pendingClaimEntries: 60,
          revealed: revealed,
        );
      },
    )));
    // Mirror the experience controller: the predicted grant is staged BEFORE
    // the dashboard mounts and the reveal fires on its own
    // winrV2MountRevealDelay (150ms) after mount.
    Future<void>.delayed(
        winrV2MountRevealDelay, () => rebuild(() => revealed = true));

    // FIRST visible frame: the bar opens ON the "YOU'RE ON A ROLL!" toast —
    // the pitch is NEVER shown before it — while the streak label holds the
    // staged "before" numbers for one beat. The pill reads GOT IT; there is
    // no CLAIM pill at any point, and no burst GIF yet (the tile is still
    // ready, pre-flip).
    await tester.pump();
    expect(find.text('YOU’RE ON A ROLL!'), findsOneWidget);
    expect(find.text('Your 60 entries have been added automatically.'),
        findsOneWidget);
    expect(
      find.text('Come back tomorrow to\nkeep your streak alive and receive:'),
      findsNothing,
    );
    expect(find.text('2 DAY STREAK'), findsOneWidget);
    expect(find.text('GOT IT'), findsOneWidget);
    expect(find.text('CLAIM 60 ENTRIES'), findsNothing);
    expect(find.byType(WINRV2GifView), findsNothing);

    // ~150ms later the reveal flips in place: the streak label advances and
    // the tile flips ready → active, mounting the one-shot confetti-burst
    // GIF overlay. The toast is still holding — it slides ONCE, later.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('3 DAY STREAK'), findsOneWidget);
    expect(find.byType(WINRV2GifView), findsWidgets);
    expect(find.text('YOU’RE ON A ROLL!'), findsOneWidget);
    expect(find.text('GOT IT'), findsOneWidget);
    expect(find.text('CLAIM 60 ENTRIES'), findsNothing);

    // After the ~2.5s hold the toast slides once to the resting pitch — the
    // pitch is the bar's FINAL state, and the toast never returns.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('YOU’RE ON A ROLL!'), findsNothing);
    expect(find.text('Your 60 entries have been added automatically.'),
        findsNothing);
    expect(
      find.text('Come back tomorrow to\nkeep your streak alive and receive:'),
      findsOneWidget,
    );
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

  testWidgets('day 1 celebrates in place with the YOU’RE IN! toast',
      (tester) async {
    // Unified Day-1 flow (Aug 2026 CTO decision): no "You're in!" modal —
    // the dashboard mounts celebrating exactly like Day 2+, only the toast
    // headline differs.
    await tester.pumpWidget(_host(WINRV2DashboardView(
      accent: accent,
      logoUrl: null,
      rulesUrl: null,
      giveaway: _giveaway(),
      streakDay: 1,
      totalEntries: 10,
      entriesToday: 10,
      ladder: const [10, 30, 60, 130, 240, 300, 500],
      claimedToday: true,
      onInfo: () {},
      onClose: () {},
      pendingClaimEntries: 10,
      revealed: false,
    )));
    await tester.pump();

    // Day-1 headline; same subline and GOT IT pill as Day 2+.
    expect(find.text('YOU’RE IN!'), findsOneWidget);
    expect(find.text('YOU’RE ON A ROLL!'), findsNothing);
    expect(find.text('Your 10 entries have been added automatically.'),
        findsOneWidget);
    expect(find.text('GOT IT'), findsOneWidget);

    // After the ~2.5s hold the toast slides once to the resting pitch.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('YOU’RE IN!'), findsNothing);
    expect(
      find.text('Come back tomorrow to\nkeep your streak alive and receive:'),
      findsOneWidget,
    );
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
