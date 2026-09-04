import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';

/// Regression: the toast → pitch handoff must never paint both texts on top
/// of each other. Flutter's AnimatedSwitcher runs the OUTGOING child's
/// animation in reverse, so an asymmetric spring curve used as switchOutCurve
/// left the old text parked at full opacity, centered, while the new text
/// arrived — the "overlapping banner" bug reported from a Skape device.
void main() {
  testWidgets('toast and come-back copy never overlap during the handoff',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              // Wide enough for the test font (square glyphs) — the real
              // bar is device-width and the copy wraps within it.
              width: 800,
              child: AvafliV2ComeBackBar(
                accent: Color(0xFF2E7D32),
                nextEntries: 50,
                celebrating: true,
                claimedEntries: 40,
              ),
            ),
          ),
        ),
      ),
    );
    // Toast is the first frame; the hold is 2.5s.
    expect(find.text('YOU’RE ON A ROLL!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2600));

    // Step through the handoff frame by frame. Whenever both texts exist,
    // their painted rects must be disjoint.
    final toast = find.text('YOU’RE ON A ROLL!');
    final pitch = find.textContaining('keep your streak alive');
    var framesWithBoth = 0;
    final trace = <String>[];
    final overlaps = <String>[];
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (toast.evaluate().isNotEmpty && pitch.evaluate().isNotEmpty) {
        framesWithBoth++;
        final a = tester.getRect(toast);
        final b = tester.getRect(pitch);
        trace.add('f$i toast[${a.left.round()}..${a.right.round()}] '
            'pitch[${b.left.round()}..${b.right.round()}]');
        if (a.overlaps(b)) overlaps.add('frame $i');
      }
    }
    // ignore: avoid_print
    print('TRACE ${trace.take(14).join(' | ')}');
    expect(overlaps, isEmpty, reason: 'overlapping frames: $overlaps');
    // Sanity: the transition really was observed (both present at some point).
    expect(framesWithBoth, greaterThan(0));
    // Settled state: only the pitch remains.
    await tester.pump(const Duration(seconds: 2));
    expect(toast, findsNothing);
    expect(pitch, findsOneWidget);
  });
}
