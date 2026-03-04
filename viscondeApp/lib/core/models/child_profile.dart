class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    this.avatarUrl,
    this.avatarPresetKey = 'guardian',
    this.avatarVariant = 1,
    this.avatarAccent = 'amber',
    required this.favoriteThemes,
    required this.isArchived,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String? avatarUrl;
  final String avatarPresetKey;
  final int avatarVariant;
  final String avatarAccent;
  final List<String> favoriteThemes;
  final bool isArchived;

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      avatarUrl: json['avatarUrl'] as String?,
      avatarPresetKey: (json['avatarPresetKey'] as String?) ?? 'guardian',
      avatarVariant: (json['avatarVariant'] as num?)?.toInt() ?? 1,
      avatarAccent: (json['avatarAccent'] as String?) ?? 'amber',
      favoriteThemes:
          ((json['favoriteThemes'] as List<dynamic>?) ?? <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      isArchived: (json['isArchived'] as bool?) ?? false,
    );
  }
}
