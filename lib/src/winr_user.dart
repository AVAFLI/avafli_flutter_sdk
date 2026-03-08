/// Represents a user within the WINR system.
/// 
/// Contains user identification and profile information that can be
/// submitted to the backend for personalization and analytics.
class WINRUser {
  /// Unique identifier for the user within your application
  final String id;
  
  /// User's email address (optional)
  final String? email;
  
  /// User's first name (optional)
  final String? firstName;
  
  /// User's last name (optional)
  final String? lastName;
  
  /// User's phone number (optional)
  final String? phone;
  
  /// Whether user has consented to SMS communications
  final bool isSMSPermissioned;
  
  /// Creates a new [WINRUser] instance.
  /// 
  /// The [id] parameter is required and should be a unique identifier
  /// for this user within your application.
  /// 
  /// Example:
  /// ```dart
  /// final user = WINRUser(
  ///   id: 'user123',
  ///   email: 'user@example.com',
  ///   firstName: 'John',
  ///   lastName: 'Doe',
  ///   isSMSPermissioned: true,
  /// );
  /// ```
  const WINRUser({
    required this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.isSMSPermissioned = false,
  });
  
  /// Creates a copy of this user with the given fields replaced with new values.
  WINRUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    bool? isSMSPermissioned,
  }) {
    return WINRUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      isSMSPermissioned: isSMSPermissioned ?? this.isSMSPermissioned,
    );
  }
  
  /// Returns true if this user has profile data that should be submitted to the backend
  bool get hasProfileData {
    return firstName != null || 
           lastName != null || 
           phone != null || 
           isSMSPermissioned;
  }
  
  @override
  String toString() {
    return 'WINRUser(id: $id, email: $email)';
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WINRUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          phone == other.phone &&
          isSMSPermissioned == other.isSMSPermissioned;
  
  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      firstName.hashCode ^
      lastName.hashCode ^
      phone.hashCode ^
      isSMSPermissioned.hashCode;
}