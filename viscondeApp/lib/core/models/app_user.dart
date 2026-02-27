enum AppUserRole { user, admin }

AppUserRole appUserRoleFromApi(String? value) {
  switch (value) {
    case 'ADMIN':
      return AppUserRole.admin;
    case 'USER':
    default:
      return AppUserRole.user;
  }
}

String appUserRoleToApi(AppUserRole value) {
  switch (value) {
    case AppUserRole.admin:
      return 'ADMIN';
    case AppUserRole.user:
      return 'USER';
  }
}

class AppUser {
  const AppUser({
    required this.id,
    this.name,
    this.email,
    required this.timezone,
    this.imageUrl,
    this.role = AppUserRole.user,
  });

  final String id;
  final String? name;
  final String? email;
  final String timezone;
  final String? imageUrl;
  final AppUserRole role;

  bool get isAdmin => role == AppUserRole.admin;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      imageUrl: json['imageUrl'] as String?,
      role: appUserRoleFromApi(json['role'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'timezone': timezone,
      'imageUrl': imageUrl,
      'role': appUserRoleToApi(role),
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? timezone,
    String? imageUrl,
    AppUserRole? role,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      timezone: timezone ?? this.timezone,
      imageUrl: imageUrl ?? this.imageUrl,
      role: role ?? this.role,
    );
  }
}
