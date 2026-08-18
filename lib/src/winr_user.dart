/// Represents a user within the WINR system.
///
/// Only [id] is required; everything else is optional and the SDK captures what's
/// missing (email via its capture screen, name via the winner prize-claim form).
/// Phone is optional.
///
/// Example:
/// ```dart
/// final user = WINRUser(id: 'user123');
/// ```
class WINRUser {
  /// Your app's unique user ID (Firebase UID, database ID, etc.)
  final String id;

  /// User's first name (optional — the SDK collects it at prize-claim if missing)
  final String firstName;

  /// User's last name (optional — the SDK collects it at prize-claim if missing)
  final String lastName;

  /// Optional phone number
  final String? phone;

  /// The user's email from YOUR authenticated session (optional).
  ///
  /// When supplied, the WINR capture screen shows it pre-filled and READ-ONLY —
  /// the user cannot swap in a different address. Deliberate: WINR links
  /// accounts across devices by email, so a free-typed address lets a user
  /// attach themselves to someone else's record, and a partner-authenticated
  /// address is the most reliable destination for a winner notification.
  ///
  /// Supplying it never records any consent — the user still ticks the boxes
  /// and submits inside the WINR flow. A malformed value is ignored and the
  /// field stays editable.
  ///
  /// This is a plain email STRING. For an app with no signed-in user, don't
  /// pass anything here — use [WINRUser.guest] as the entire `user:` value
  /// instead (`user: WINRUser.guest`).
  final String? email;

  /// A guest session — the person is not signed in to YOUR app (or your app
  /// has no accounts). The SDK mints a stable per-install guest id
  /// (`winr_guest_…`) and uses it for attribution, so there is always a real
  /// identifier without your integration fabricating one. The WINR experience
  /// is fully functional for guests; when your user signs in, call configure
  /// again with the real user and attribution upgrades in place — the streak
  /// is device-anchored and unaffected.
  static const WINRUser guest = WINRUser(id: '', firstName: '', lastName: '');

  /// True when this value is the [guest] sentinel.
  bool get isGuest => id.isEmpty;

  /// Creates a new [WINRUser].
  ///
  /// Only [id] is required; [firstName] and [lastName] default to empty and the
  /// SDK captures them later (at prize-claim if the user wins).
  const WINRUser({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.phone,
    this.email,
  });

  @override
  String toString() => 'WINRUser(id: $id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WINRUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
