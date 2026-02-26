class AppUser {
  const AppUser({
    required this.id,
    this.name,
    this.email,
    required this.timezone,
    this.imageUrl,
  });

  final String id;
  final String? name;
  final String? email;
  final String timezone;
  final String? imageUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'timezone': timezone,
      'imageUrl': imageUrl,
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? timezone,
    String? imageUrl,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      timezone: timezone ?? this.timezone,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
