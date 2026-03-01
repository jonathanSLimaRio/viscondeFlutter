import '../story_room/models/story_models.dart';

class BookProjectModel {
  final String id;
  final String userId;
  final String childProfileId;
  final String month;
  final String title;
  final String status;
  final String? pdfUrl;
  final List<String> includedStories;
  final List<StorySessionModel> stories;
  final DateTime createdAt;

  BookProjectModel({
    required this.id,
    required this.userId,
    required this.childProfileId,
    required this.month,
    required this.title,
    required this.status,
    this.pdfUrl,
    required this.includedStories,
    required this.stories,
    required this.createdAt,
  });

  factory BookProjectModel.fromJson(Map<String, dynamic> json) {
    return BookProjectModel(
      id: json['id'],
      userId: json['userId'],
      childProfileId: json['childProfileId'],
      month: json['month'],
      title: json['title'],
      status: json['status'],
      pdfUrl: json['pdfUrl'],
      includedStories: List<String>.from(json['includedStories'] ?? []),
      stories:
          (json['stories'] as List?)
              ?.map((s) => StorySessionModel.fromJson(s))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
