/// Represents a user within the WINR system.
///
/// Only the user ID is required. Email and consent are handled
/// internally by the SDK's capture flow — publishers don't set them.
///
/// Example:
/// ```dart
/// final user = WINRUser(id: 'user123');
/// // Or with optional profile data:
/// final user = WINRUser(id: 'user123', firstName: 'John');
/// ```
class WINRUser {
  /// Your app's unique user ID (Firebase UID, database ID, etc.)
  final String id;

  /// Optional first name for profile enrichment
  final String? firstName;

  /// Optional last name for profile enrichment
  final String? lastName;

  /// Optional phone number
  final String? phone;

  // ── Internal state managed by the SDK ──
  String? _email;
  // ignore: unused_field
  bool _isEmailPermissioned = false;
  bool _isSMSPermissioned = false;

  /// Internal email getter
  String? get email => _email;

  /// Internal SMS permission getter
  bool get isSMSPermissioned => _isSMSPermissioned;

  /// Creates a new [WINRUser] with just a user ID.
  WINRUser({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
  });

  /// Creates an anonymous user from a device ID.
  factory WINRUser.anonymous(String deviceId) {
    return WINRUser(id: 'anon-$deviceId');
  }

  /// Returns true if this user has profile data to submit
  bool get hasProfileData {
    return firstName != null || lastName != null || phone != null;
  }

  @override
  String toString() => 'WINRUser(id: $id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WINRUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
