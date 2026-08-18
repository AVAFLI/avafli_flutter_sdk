// In-app legal webview (2.9.4): Official Rules and the Privacy Policy open
// INSIDE the experience — a full-screen gunmetal webview with a slim
// title + X header — instead of bouncing the user out to the external
// browser. The privacy page is loaded with `?app=1`, under which
// winrmedia.com/sdk/privacy renders a "Delete my data" section; tapping it
// navigates to `winr://delete`, which the webview intercepts
// (NavigationDecision.prevent) and hands back to the SDK's existing
// destructive opt-out confirmation + authenticated erasure flow
// ([WINRV2OptOutFlow] → `WINR.optOut`). The native "Privacy choices" screen
// that used to list the delete action is gone — the webview is now the one
// legal surface.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'winr_v2_components.dart';
import 'winr_v2_strings.dart';
import 'winr_v2_theme.dart';

/// Canonical WINR privacy policy, mirroring iOS `WINRConstants.privacyURL`.
/// Publisher config carries no privacy URL (`rulesUrl` covers the Official
/// Rules only), so every "Privacy Policy" link/span opens this.
const String winrV2PrivacyPolicyUrl = 'https://winrmedia.com/sdk/privacy';

/// Returns [url] with `app=1` appended — the flag under which the privacy
/// page renders its in-app variant (including the Delete-my-data section
/// that navigates `winr://delete`). Built via `Uri.replace` so an existing
/// query string extends correctly instead of gaining a second `?`.
Uri winrV2AppendAppQuery(String url) {
  final base = Uri.parse(url);
  return base.replace(
    queryParameters: {...base.queryParameters, 'app': '1'},
  );
}

/// The privacy webview destination: [winrV2PrivacyPolicyUrl] + `?app=1`.
Uri winrV2AppPrivacyUri() => winrV2AppendAppQuery(winrV2PrivacyPolicyUrl);

/// What the legal webview should do with an attempted navigation.
enum WINRV2LegalNav {
  /// A normal web navigation — let the webview load it.
  allow,

  /// The `winr://delete` bridge — prevent the load and raise the SDK's
  /// destructive delete-my-data confirmation.
  delete,

  /// Any other `winr://` message (or an unparseable URL) — prevent the load
  /// and do nothing. Unknown bridge verbs from a newer page build must
  /// degrade to a dead tap, never to a webview error page.
  block,
}

/// Pure decision for [NavigationDelegate.onNavigationRequest] — kept free of
/// plugin types so the bridge contract is unit-testable.
WINRV2LegalNav winrV2LegalNavDecision(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return WINRV2LegalNav.block;
  if (uri.scheme.toLowerCase() != 'winr') return WINRV2LegalNav.allow;
  // Tolerate both winr://delete (host) and winr:/delete (path) forms.
  final verb = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
  return verb.toLowerCase() == 'delete'
      ? WINRV2LegalNav.delete
      : WINRV2LegalNav.block;
}

/// Experience-level wiring the legal webview needs but the deep link/span
/// widgets don't carry: how to perform the authenticated erasure
/// (`WINR.optOut`) and how to dismiss the whole drawer after a completed
/// deletion. The experience root provides it; the openers capture it from
/// the tapped link's context at push time (the pushed route itself lives
/// outside the experience subtree). Absent (bare widget tests/previews) the
/// webview still works — a confirmed delete just fails honestly.
class WINRV2ExperienceScope extends InheritedWidget {
  /// Animated dismissal of the whole experience drawer.
  final VoidCallback closeExperience;

  /// The RTD opt-out (the experience wires `WINR.optOut`). MUST throw on
  /// failure so the confirmation shows an honest error.
  final Future<void> Function()? optOutAction;

  const WINRV2ExperienceScope({
    super.key,
    required this.closeExperience,
    this.optOutAction,
    required super.child,
  });

  /// Read-only lookup (no dependency registered) — the openers call this
  /// from tap handlers, not from build.
  static WINRV2ExperienceScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WINRV2ExperienceScope>();

  @override
  bool updateShouldNotify(WINRV2ExperienceScope oldWidget) =>
      closeExperience != oldWidget.closeExperience ||
      optOutAction != oldWidget.optOutAction;
}

/// Opens the publisher's Official Rules in the in-app legal webview. No-op
/// on a missing/unparseable URL, exactly as the old external launch was.
void winrV2OpenOfficialRules(BuildContext context, String? rulesUrl) {
  if (rulesUrl == null || rulesUrl.isEmpty) return;
  final uri = Uri.tryParse(rulesUrl);
  if (uri == null) return;
  _pushLegalWebView(context, title: 'OFFICIAL RULES', uri: uri);
}

/// Opens the WINR Privacy Policy in the in-app legal webview — the ONE
/// opener shared by every Privacy Policy link and span, so the destination
/// can never drift per screen. Loads `?app=1` (see [winrV2AppPrivacyUri])
/// so the page includes its Delete-my-data section.
void winrV2OpenPrivacyPolicy(BuildContext context) {
  _pushLegalWebView(
    context,
    title: 'PRIVACY POLICY',
    uri: winrV2AppPrivacyUri(),
  );
}

void _pushLegalWebView(
  BuildContext context, {
  required String title,
  required Uri uri,
}) {
  // Captured HERE, inside the experience subtree — the pushed route sits on
  // the host navigator where the scope is not visible.
  final scope = WINRV2ExperienceScope.maybeOf(context);
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => WINRV2LegalWebView(
      title: title,
      uri: uri,
      optOutAction: scope?.optOutAction,
      onExperienceClose: scope?.closeExperience,
    ),
  ));
}

/// The in-app legal document screen: slim header (title + X) over a webview
/// on the experience's gunmetal chrome, with a thin load-progress bar and an
/// honest offline state with RETRY. `winr://delete` (from the privacy page's
/// Delete-my-data section) raises [WINRV2OptOutFlow] over the page.
class WINRV2LegalWebView extends StatefulWidget {
  final String title;
  final Uri uri;

  /// Performs the RTD opt-out when the bridge fires (the openers wire the
  /// experience's `WINR.optOut` via [WINRV2ExperienceScope]). Null → a
  /// confirmed delete fails honestly instead of pretending.
  final Future<void> Function()? optOutAction;

  /// Dismisses the whole experience after a completed deletion.
  final VoidCallback? onExperienceClose;

  const WINRV2LegalWebView({
    super.key,
    required this.title,
    required this.uri,
    this.optOutAction,
    this.onExperienceClose,
  });

  @override
  State<WINRV2LegalWebView> createState() => _WINRV2LegalWebViewState();
}

class _WINRV2LegalWebViewState extends State<WINRV2LegalWebView> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;
  bool _showsOptOut = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(WINRV2Colors.gunmetal)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onNavigationRequest: (request) {
          switch (winrV2LegalNavDecision(request.url)) {
            case WINRV2LegalNav.allow:
              return NavigationDecision.navigate;
            case WINRV2LegalNav.delete:
              _showOptOut();
              return NavigationDecision.prevent;
            case WINRV2LegalNav.block:
              return NavigationDecision.prevent;
          }
        },
        onWebResourceError: (error) {
          // Sub-resource hiccups (an image, a font) must not nuke the page.
          if (error.isForMainFrame ?? true) {
            if (mounted) setState(() => _failed = true);
          }
        },
      ))
      ..loadRequest(widget.uri);
  }

  void _showOptOut() {
    if (_showsOptOut || !mounted) return;
    setState(() => _showsOptOut = true);
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(widget.uri);
  }

  /// Deletion completed: leave this screen, then dismiss the whole drawer.
  void _handleDeleted() {
    final close = widget.onExperienceClose;
    Navigator.of(context).pop();
    close?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WINRV2Colors.gunmetal,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _header(),
                const SizedBox(height: 10),
                // Thin determinate progress strip — reserved height so the
                // page doesn't jump when loading finishes.
                SizedBox(
                  height: 2,
                  child: (_progress < 100 && !_failed)
                      ? LinearProgressIndicator(
                          value: _progress <= 0 ? null : _progress / 100,
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: WINRV2Colors.textTertiary,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: _failed
                      ? _errorState()
                      : WebViewWidget(controller: _controller),
                ),
              ],
            ),
          ),
          if (_showsOptOut)
            WINRV2OptOutFlow(
              optOutAction: widget.optOutAction,
              onCancel: () => setState(() => _showsOptOut = false),
              onDeleted: _handleDeleted,
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WINRV2Font.inter(
                18,
                weight: FontWeight.w900,
                letterSpacing: -0.54,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: WINRV2Colors.deepCharcoal,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: WINRV2Colors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              WINRV2Strings.legalLoadFailed,
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(
                14,
                color: WINRV2Colors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 200,
              child: WINRV2PillButton(
                accent: WINRV2Colors.winrBlue,
                title: WINRV2Strings.tryAgain,
                onTap: _retry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The delete-my-data confirmation's phase while the flow is up:
///
///     confirming → inFlight → done → (dismiss webview + whole experience)
///                          ↘ failed (inline error, retryable) ↗
///
/// Failure NEVER pretends success — the confirmation stays up with the error
/// and the destructive button remains available to retry.
enum WINRV2OptOutPhase { confirming, inFlight, failed, done }

/// The destructive delete-my-data confirmation (scrim + card, identical to
/// the retired Privacy-choices screen's dialog), raised by the privacy
/// webview's `winr://delete` bridge. Owns the confirm → erase → done/failed
/// machine; the webview stays visible behind the scrim.
class WINRV2OptOutFlow extends StatefulWidget {
  /// The authenticated erasure (`WINR.optOut`). MUST throw on failure so the
  /// confirmation can show an honest error instead of pretending the
  /// deletion succeeded. Null (previews/tests, or a scope-less host) treats
  /// a confirm as a failure.
  final Future<void> Function()? optOutAction;

  /// Dismissed without deleting (cancel / scrim tap).
  final VoidCallback onCancel;

  /// Deletion succeeded and the success copy has held [successHold].
  final VoidCallback onDeleted;

  /// How long "Your data has been deleted." holds before [onDeleted] fires.
  static const Duration successHold = Duration(milliseconds: 1400);

  const WINRV2OptOutFlow({
    super.key,
    required this.optOutAction,
    required this.onCancel,
    required this.onDeleted,
  });

  @override
  State<WINRV2OptOutFlow> createState() => _WINRV2OptOutFlowState();
}

class _WINRV2OptOutFlowState extends State<WINRV2OptOutFlow> {
  WINRV2OptOutPhase _phase = WINRV2OptOutPhase.confirming;

  Future<void> _confirm() async {
    if (_phase != WINRV2OptOutPhase.confirming &&
        _phase != WINRV2OptOutPhase.failed) {
      return;
    }
    setState(() => _phase = WINRV2OptOutPhase.inFlight);
    try {
      final action = widget.optOutAction;
      if (action == null) throw StateError('optOutAction not wired');
      await action();
      if (!mounted) return;
      setState(() => _phase = WINRV2OptOutPhase.done);
      // Hold the success copy a beat, then hand back (webview + experience
      // both dismiss).
      await Future<void>.delayed(WINRV2OptOutFlow.successHold);
      if (!mounted) return;
      widget.onDeleted();
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = WINRV2OptOutPhase.failed);
    }
  }

  void _cancel() {
    if (_phase == WINRV2OptOutPhase.inFlight ||
        _phase == WINRV2OptOutPhase.done) {
      return;
    }
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final inFlight = _phase == WINRV2OptOutPhase.inFlight;
    return Stack(
      children: [
        GestureDetector(
          onTap: inFlight ? null : _cancel,
          child: const ColoredBox(
            color: Color(0x8C000000),
            child: SizedBox.expand(),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () {}, // swallow taps inside the card
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: WINRV2Colors.deepCharcoal,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _phase == WINRV2OptOutPhase.done
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              WINRV2Strings.optOutSuccess,
                              textAlign: TextAlign.center,
                              style: WINRV2Font.inter(
                                18,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ]
                      : [
                          Text(
                            WINRV2Strings.optOutTitle,
                            textAlign: TextAlign.center,
                            style: WINRV2Font.inter(
                              18,
                              weight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            WINRV2Strings.optOutBody,
                            textAlign: TextAlign.center,
                            style: WINRV2Font.inter(
                              14,
                              color: const Color(0xBFFFFFFF),
                              height: 1.3,
                            ),
                          ),
                          if (_phase == WINRV2OptOutPhase.failed) ...[
                            const SizedBox(height: 14),
                            Text(
                              WINRV2Strings.optOutFailed,
                              textAlign: TextAlign.center,
                              style: WINRV2Font.inter(
                                13,
                                color: WINRV2Colors.errorRed,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          WINRV2PillButton(
                            accent: WINRV2Colors.errorRed,
                            title: WINRV2Strings.optOutConfirm,
                            isLoading: inFlight,
                            onTap: () => _confirm(),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: inFlight ? null : _cancel,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                WINRV2Strings.optOutCancel,
                                style: WINRV2Font.inter(
                                  14,
                                  color: WINRV2Colors.textTertiary,
                                ).copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
