/// Controls WHEN the SDK opens the Avafli experience on its own.
///
/// Set via [AvafliConfiguration.autoOpen]. The default, [always], is the
/// behavior every prior release shipped with: the drawer auto-opens at most
/// once per calendar day when the person is eligible. Whatever the mode,
/// device registration (`registerDevice` — the DAU/MAU heartbeat) still runs
/// inside `Avafli.configure()`; only the presentation is affected.
///
/// The server can also set a mode (`sdkConfig.experience.autoOpenMode`); the
/// effective mode is the MORE restrictive of the two, and the existing
/// `experience.autoOpenEnabled == false` kill switch always wins.
enum AvafliAutoOpen {
  /// Auto-open once per day when eligible (today's behavior — the default).
  always,

  /// Skip the auto-open for the session in which `registerDevice` reported
  /// this as a brand-new device (`isNewUser == true`) — e.g. so the drawer
  /// never pops over a first-run onboarding. Every later launch auto-opens
  /// as normal. Older backends that omit `isNewUser` are treated as
  /// returning (auto-open).
  returningUsersOnly,

  /// Never auto-open; the host app calls [Avafli.present] itself.
  never;

  /// Parses the server wire value (`'always' | 'returningUsersOnly' |
  /// 'never'`). Unknown or absent values return null, which callers treat
  /// as [always] — a newer backend must never silence an older SDK by
  /// accident.
  static AvafliAutoOpen? fromWire(String? value) {
    switch (value) {
      case 'always':
        return AvafliAutoOpen.always;
      case 'returningUsersOnly':
        return AvafliAutoOpen.returningUsersOnly;
      case 'never':
        return AvafliAutoOpen.never;
      default:
        return null;
    }
  }

  /// The more restrictive of two modes (`never` > `returningUsersOnly` >
  /// `always`). Declaration order doubles as the restrictiveness order.
  static AvafliAutoOpen mostRestrictive(AvafliAutoOpen a, AvafliAutoOpen b) =>
      a.index >= b.index ? a : b;
}
