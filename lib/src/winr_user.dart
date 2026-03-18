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

  /// Creates a new [WINRUser].
  ///
  /// [id], [firstName], and [lastName] are required.
  const WINRUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
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
