class VoiceProfileModel {
  const VoiceProfileModel({
    required this.id,
    required this.name,
    this.relationship,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? relationship;
  final String status;
  final DateTime createdAt;

  factory VoiceProfileModel.fromJson(Map<String, dynamic> json) {
    return VoiceProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class NarrationJobModel {
  const NarrationJobModel({
    required this.id,
    required this.storyId,
    this.stepIndex,
    required this.status,
    this.outputUrl,
  });

  final String id;
  final String storyId;
  final int? stepIndex;
  final String status;
  final String? outputUrl;

  factory NarrationJobModel.fromJson(Map<String, dynamic> json) {
    return NarrationJobModel(
      id: json['id'] as String? ?? '',
      storyId: json['storyId'] as String? ?? '',
      stepIndex: json['stepIndex'] as int?,
      status: json['status'] as String? ?? 'PENDING',
      outputUrl: json['outputUrl'] as String?,
    );
  }
}
