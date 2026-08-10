/// Represents a user within the WINR system.
///
/// All identity fields are required. Phone is optional.
///
/// Example:
/// ```dart
/// final user = WINRUser(
///   id: 'user123',
///   firstName: 'Jane',
///   lastName: 'Doe',
/// );
/// ```
class WINRUser {
  /// Your app's unique user ID (Firebase UID, database ID, etc.)
  final String id;

  /// User's first name (required)
  final String firstName;

  /// User's last name (required)
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
  final String? email;

  /// Creates a new [WINRUser].
  ///
  /// [id], [firstName], and [lastName] are required.
  const WINRUser({
    required this.id,
    required this.firstName,
    required this.lastName,
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
