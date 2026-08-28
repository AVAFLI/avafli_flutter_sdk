// In-app legal webview (2.9.4): Official Rules and the Privacy Policy open
// INSIDE the experience — a full-screen gunmetal webview with a slim
// title + X header — instead of bouncing the user out to the external
// browser. The privacy page is loaded with `?app=1`, under which
// winrmedia.com/sdk/privacy renders a "Delete my data" section; tapping it
// navigates to `winr://delete` (the 3.0 SDK also accepts `avafli://delete`
// so the hosted page can migrate schemes without stranding either SDK
// generation), which the webview intercepts
// (NavigationDecision.prevent), then — matching iOS/web (2.9.5) — the
// webview CLOSES FIRST and the SDK's existing destructive opt-out
// confirmation ([AvafliV2OptOutFlow] → `Avafli.optOut`) presents over the
// experience, so cancel returns the user to the SDK screen they came from.
// The native "Privacy choices" screen that used to list the delete action
// is gone — the webview is now the one legal surface.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'avafli_v2_components.dart';
import 'avafli_v2_strings.dart';
import 'avafli_v2_theme.dart';

/// Canonical Avafli privacy policy, mirroring iOS `AvafliConstants.privacyURL`.
/// Publisher config carries no privacy URL (`rulesUrl` covers the Official
/// Rules only), so every "Privacy Policy" link/span opens this.
const String avafliV2PrivacyPolicyUrl = 'https://winrmedia.com/sdk/privacy';

/// Returns [url] with `app=1` appended — the flag under which the privacy
/// page renders its in-app variant (including the Delete-my-data section
/// that navigates `avafli://delete`). Built via `Uri.replace` so an existing
/// query string extends correctly instead of gaining a second `?`.
Uri avafliV2AppendAppQuery(String url) {
  final base = Uri.parse(url);
  return base.replace(
    queryParameters: {...base.queryParameters, 'app': '1'},
  );
}

/// The privacy webview destination: [avafliV2PrivacyPolicyUrl] + `?app=1`.
Uri avafliV2AppPrivacyUri() => avafliV2AppendAppQuery(avafliV2PrivacyPolicyUrl);

/// What the legal webview should do with an attempted navigation.
enum AvafliV2LegalNav {
  /// A normal web navigation — let the webview load it.
  allow,

  /// The `avafli://delete` / `winr://delete` bridge — prevent the load and
  /// raise the SDK's destructive delete-my-data confirmation.
  delete,

  /// Any other bridge-scheme message (or an unparseable URL) — prevent the load
  /// and do nothing. Unknown bridge verbs from a newer page build must
  /// degrade to a dead tap, never to a webview error page.
  block,
}

/// The bridge schemes the legal webview intercepts. `avafli://` is the
/// canonical 3.0 scheme; `winr://` stays accepted because the hosted
/// winrmedia.com privacy page still emits it (and older page builds always
/// will) — both must keep working regardless of which side ships first.
const Set<String> _avafliV2BridgeSchemes = {'avafli', 'winr'};

/// Pure decision for [NavigationDelegate.onNavigationRequest] — kept free of
/// plugin types so the bridge contract is unit-testable.
AvafliV2LegalNav avafliV2LegalNavDecision(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return AvafliV2LegalNav.block;
  if (!_avafliV2BridgeSchemes.contains(uri.scheme.toLowerCase())) {
    return AvafliV2LegalNav.allow;
  }
  // Tolerate both avafli://delete (host) and avafli:/delete (path) forms.
  final verb = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
  return verb.toLowerCase() == 'delete'
      ? AvafliV2LegalNav.delete
      : AvafliV2LegalNav.block;
}

/// Experience-level wiring the legal webview needs but the deep link/span
/// widgets don't carry: how to raise the destructive delete-my-data
/// confirmation over the experience once the webview has closed (iOS/web
/// parity — 2.9.5). The experience root provides it; the openers capture it
/// from the tapped link's context at push time (the pushed route itself
/// lives outside the experience subtree). Absent (bare widget
/// tests/previews) the webview still works — the delete bridge just closes
/// the webview.
class AvafliV2ExperienceScope extends InheritedWidget {
  /// Presents [AvafliV2OptOutFlow] over the drawer. The experience wires the
  /// erasure (`Avafli.optOut`) and the post-success drawer dismissal itself.
  final VoidCallback presentDeleteConfirmation;

  /// The publisher accent (branding.primaryColor), so surfaces pushed OUTSIDE
  /// the experience subtree (the legal webview route) stay on-brand. Null in
  /// bare tests/previews -> the Avafli default blue.
  final Color? accent;

  const AvafliV2ExperienceScope({
    super.key,
    required this.presentDeleteConfirmation,
    this.accent,
    required super.child,
  });

  /// Read-only lookup (no dependency registered) — the openers call this
  /// from tap handlers, not from build.
  static AvafliV2ExperienceScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AvafliV2ExperienceScope>();

  @override
  bool updateShouldNotify(AvafliV2ExperienceScope oldWidget) =>
      presentDeleteConfirmation != oldWidget.presentDeleteConfirmation;
}

/// Opens the publisher's Official Rules in the in-app legal webview. No-op
/// on a missing/unparseable URL, exactly as the old external launch was.
void avafliV2OpenOfficialRules(BuildContext context, String? rulesUrl) {
  if (rulesUrl == null || rulesUrl.isEmpty) return;
  final uri = Uri.tryParse(rulesUrl);
  if (uri == null) return;
  _pushLegalWebView(context, title: 'OFFICIAL RULES', uri: uri);
}

/// Opens the Avafli Privacy Policy in the in-app legal webview — the ONE
/// opener shared by every Privacy Policy link and span, so the destination
/// can never drift per screen. Loads `?app=1` (see [avafliV2AppPrivacyUri])
/// so the page includes its Delete-my-data section.
void avafliV2OpenPrivacyPolicy(BuildContext context) {
  _pushLegalWebView(
    context,
    title: 'PRIVACY POLICY',
    uri: avafliV2AppPrivacyUri(),
  );
}

void _pushLegalWebView(
  BuildContext context, {
  required String title,
  required Uri uri,
}) {
  // Captured HERE, inside the experience subtree — the pushed route sits on
  // the host navigator where the scope is not visible.
  final scope = AvafliV2ExperienceScope.maybeOf(context);
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => AvafliV2LegalWebView(
      title: title,
      uri: uri,
      accent: scope?.accent,
      onDeleteRequested: scope?.presentDeleteConfirmation,
    ),
  ));
}

/// The in-app legal document screen: slim header (title + X) over a webview
/// on the experience's gunmetal chrome, with a thin load-progress bar and an
/// honest offline state with RETRY. `avafli://delete` (from the privacy page's
/// Delete-my-data section) pops this screen and fires [onDeleteRequested] —
/// the confirmation presents over the SDK experience, not over the page
/// (iOS/web parity).
class AvafliV2LegalWebView extends StatefulWidget {
  final String title;
  final Uri uri;

  /// Publisher accent for the RETRY pill (branding parity). Null → default.
  final Color? accent;

  /// Fired AFTER this screen pops when the `avafli://delete` bridge fires (the
  /// openers wire the experience's presenter via [AvafliV2ExperienceScope]).
  /// Null (bare tests/previews) → the bridge just closes the webview.
  final VoidCallback? onDeleteRequested;

  const AvafliV2LegalWebView({
    super.key,
    required this.title,
    required this.uri,
    this.accent,
    this.onDeleteRequested,
  });

  @override
  State<AvafliV2LegalWebView> createState() => _AvafliV2LegalWebViewState();
}

class _AvafliV2LegalWebViewState extends State<AvafliV2LegalWebView> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AvafliV2Colors.gunmetal)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onNavigationRequest: (request) {
          switch (avafliV2LegalNavDecision(request.url)) {
            case AvafliV2LegalNav.allow:
              return NavigationDecision.navigate;
            case AvafliV2LegalNav.delete:
              _handleDeleteBridge();
              return NavigationDecision.prevent;
            case AvafliV2LegalNav.block:
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

  /// iOS/web parity: the webview closes FIRST, then the destructive
  /// confirmation presents over the SDK experience — cancel returns the
  /// user to the screen they came from, not to the privacy page.
  void _handleDeleteBridge() {
    if (!mounted) return;
    final onDelete = widget.onDeleteRequested;
    Navigator.of(context).pop();
    onDelete?.call();
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AvafliV2Colors.gunmetal,
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
                          color: AvafliV2Colors.textTertiary,
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
              style: AvafliV2Font.inter(
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
                color: AvafliV2Colors.deepCharcoal,
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
              color: AvafliV2Colors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              AvafliV2Strings.legalLoadFailed,
              textAlign: TextAlign.center,
              style: AvafliV2Font.inter(
                14,
                color: AvafliV2Colors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 200,
              child: AvafliV2PillButton(
                // Publisher accent when the experience provided one — the
                // legal route sits outside the themed subtree, so it must be
                // handed the brand color explicitly.
                accent: widget.accent ?? AvafliV2Colors.avafliBlue,
                title: AvafliV2Strings.tryAgain,
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
///     confirming → inFlight → done → (dismiss the whole experience)
///                          ↘ failed (inline error, retryable) ↗
///
/// Failure NEVER pretends success — the confirmation stays up with the error
/// and the destructive button remains available to retry.
enum AvafliV2OptOutPhase { confirming, inFlight, failed, done }

/// The destructive delete-my-data confirmation (scrim + card, identical to
/// the retired Privacy-choices screen's dialog), presented by the EXPERIENCE
/// over the drawer after the privacy webview's `avafli://delete` bridge closes
/// the webview (iOS/web parity). Owns the confirm → erase → done/failed
/// machine.
class AvafliV2OptOutFlow extends StatefulWidget {
  /// The authenticated erasure (`Avafli.optOut`). MUST throw on failure so the
  /// confirmation can show an honest error instead of pretending the
  /// deletion succeeded. Null (previews/tests, or a scope-less host) treats
  /// a confirm as a failure.
  final Future<void> Function()? optOutAction;

  /// Dismissed without deleting (cancel / scrim tap).
  final VoidCallback onCancel;

  /// Deletion succeeded and the success copy has held [successHold] — the
  /// experience dismisses the whole drawer.
  final VoidCallback onDeleted;

  /// How long "Your data has been deleted." holds before [onDeleted] fires.
  static const Duration successHold = Duration(milliseconds: 1400);

  const AvafliV2OptOutFlow({
    super.key,
    required this.optOutAction,
    required this.onCancel,
    required this.onDeleted,
  });

  @override
  State<AvafliV2OptOutFlow> createState() => _AvafliV2OptOutFlowState();
}

class _AvafliV2OptOutFlowState extends State<AvafliV2OptOutFlow> {
  AvafliV2OptOutPhase _phase = AvafliV2OptOutPhase.confirming;

  Future<void> _confirm() async {
    if (_phase != AvafliV2OptOutPhase.confirming &&
        _phase != AvafliV2OptOutPhase.failed) {
      return;
    }
    setState(() => _phase = AvafliV2OptOutPhase.inFlight);
    try {
      final action = widget.optOutAction;
      if (action == null) throw StateError('optOutAction not wired');
      await action();
      if (!mounted) return;
      setState(() => _phase = AvafliV2OptOutPhase.done);
      // Hold the success copy a beat, then hand back (the experience
      // dismisses the whole drawer).
      await Future<void>.delayed(AvafliV2OptOutFlow.successHold);
      if (!mounted) return;
      widget.onDeleted();
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = AvafliV2OptOutPhase.failed);
    }
  }

  void _cancel() {
    if (_phase == AvafliV2OptOutPhase.inFlight ||
        _phase == AvafliV2OptOutPhase.done) {
      return;
    }
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final inFlight = _phase == AvafliV2OptOutPhase.inFlight;
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
                  color: AvafliV2Colors.deepCharcoal,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _phase == AvafliV2OptOutPhase.done
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              AvafliV2Strings.optOutSuccess,
                              textAlign: TextAlign.center,
                              style: AvafliV2Font.inter(
                                18,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ]
                      : [
                          Text(
                            AvafliV2Strings.optOutTitle,
                            textAlign: TextAlign.center,
                            style: AvafliV2Font.inter(
                              18,
                              weight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            AvafliV2Strings.optOutBody,
                            textAlign: TextAlign.center,
                            style: AvafliV2Font.inter(
                              14,
                              color: const Color(0xBFFFFFFF),
                              height: 1.3,
                            ),
                          ),
                          if (_phase == AvafliV2OptOutPhase.failed) ...[
                            const SizedBox(height: 14),
                            Text(
                              AvafliV2Strings.optOutFailed,
                              textAlign: TextAlign.center,
                              style: AvafliV2Font.inter(
                                13,
                                color: AvafliV2Colors.errorRed,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          AvafliV2PillButton(
                            accent: AvafliV2Colors.errorRed,
                            title: AvafliV2Strings.optOutConfirm,
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
                                AvafliV2Strings.optOutCancel,
                                style: AvafliV2Font.inter(
                                  14,
                                  color: AvafliV2Colors.textTertiary,
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
