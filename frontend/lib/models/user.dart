/// Roles del sistema (spec §6.1)
enum UserRole { caregiver, monitored, itAdmin }

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.caregiver:
        return 'CAREGIVER';
      case UserRole.monitored:
        return 'MONITORED';
      case UserRole.itAdmin:
        return 'IT_ADMIN';
    }
  }

  static UserRole fromString(String s) {
    switch (s.toUpperCase()) {
      case 'CAREGIVER':
        return UserRole.caregiver;
      case 'MONITORED':
        return UserRole.monitored;
      case 'IT_ADMIN':
        return UserRole.itAdmin;
      default:
        return UserRole.caregiver;
    }
  }
}

class User {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String locale;
  final bool active;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.locale = 'es',
    this.active = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: UserRoleX.fromString(json['role'] as String),
      locale: json['locale'] as String? ?? 'es',
      active: json['active'] as bool? ?? true,
    );
  }

  User copyWith({bool? active}) => User(
        id: id,
        email: email,
        fullName: fullName,
        role: role,
        locale: locale,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'role': role.value,
        'locale': locale,
        'active': active,
      };
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final User user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
