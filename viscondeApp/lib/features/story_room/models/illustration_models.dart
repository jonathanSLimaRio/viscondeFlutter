class ArtStyleModel {
  const ArtStyleModel({
    required this.id,
    required this.name,
    this.promptTemplate,
  });

  final String id;
  final String name;
  final String? promptTemplate;

  factory ArtStyleModel.fromJson(Map<String, dynamic> json) {
    return ArtStyleModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      promptTemplate: json['promptTemplate'] as String?,
    );
  }
}

class StoryIllustrationModel {
  const StoryIllustrationModel({
    required this.id,
    required this.storyId,
    required this.stepIndex,
    required this.status,
    this.imageUrl,
  });

  final String id;
  final String storyId;
  final int stepIndex;
  final String status;
  final String? imageUrl;

  factory StoryIllustrationModel.fromJson(Map<String, dynamic> json) {
    return StoryIllustrationModel(
      id: json['id'] as String? ?? '',
      storyId: json['storyId'] as String? ?? '',
      stepIndex: json['stepIndex'] as int? ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
