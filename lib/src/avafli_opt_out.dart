part of 'avafli.dart';

/// @internal — "Delete my data and stop participating".
///
/// The ONLY deletion path (3.3.3): the Privacy Policy screen inside the
/// experience. The legal webview intercepts the page's `avafli://delete`
/// (legacy `winr://delete`) navigation, pops, and the experience raises
/// `AvafliV2OptOutFlow`, whose DELETE MY DATA button runs this. Host apps
/// cannot reach it — it is hidden from `package:avafli_sdk/avafli_sdk.dart`
/// and must stay that way: a host app must never be able to erase a person's
/// Avafli data on their behalf.
///
/// Right-To-Delete erasure: the person is erased on the backend
/// (identity-wide, PII anonymized, prize-claim records included) and their
/// entries and streaks are forfeited. For 24 hours that email and this
/// device cannot register and the experience stays silent; after that the
/// person may join again as a brand-new participant with no connection to
/// the old profile (see `Avafli._liftOptOutIfLapsed`).
///
/// Throws [AvafliException] (`notConfigured` before [Avafli.configure],
/// otherwise the backend failure) so the confirmation can show an honest
/// error instead of pretending the deletion succeeded.
Future<void> performOptOut() async {
  final networkClient = Avafli._networkClient;
  if (networkClient == null) {
    throw const AvafliException(AvafliError.notConfigured);
  }
  await networkClient.send(OptOutRequest());
  Avafli.markOptedOut(until: Avafli._now().add(Avafli._optOutBlock));
  Logger.instance.info(
      'User opted out of Avafli (RTD) — experience silenced for 24 hours');
}
