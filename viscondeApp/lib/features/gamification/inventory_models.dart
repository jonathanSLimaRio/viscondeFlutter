class InventoryItemModel {
  final String id;
  final String key;
  final String name;
  final String description;
  final String rarity;
  final String category;
  final String icon;
  final List<String> tags;

  InventoryItemModel({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.rarity,
    required this.category,
    required this.icon,
    required this.tags,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'],
      key: json['key'],
      name: json['name'],
      description: json['description'],
      rarity: json['rarity'],
      category: json['category'],
      icon: json['icon'],
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class ChildInventoryModel {
  final String id;
  final String childProfileId;
  final String itemId;
  final int qty;
  final DateTime acquiredAt;
  final InventoryItemModel? item;

  ChildInventoryModel({
    required this.id,
    required this.childProfileId,
    required this.itemId,
    required this.qty,
    required this.acquiredAt,
    this.item,
  });

  factory ChildInventoryModel.fromJson(Map<String, dynamic> json) {
    return ChildInventoryModel(
      id: json['id'],
      childProfileId: json['childProfileId'],
      itemId: json['itemId'],
      qty: json['qty'],
      acquiredAt: DateTime.parse(json['acquiredAt']),
      item: json['item'] != null
          ? InventoryItemModel.fromJson(json['item'])
          : null,
    );
  }
}

class StoryMemoryModel {
  final String id;
  final String storyId;
  final String summary;

  StoryMemoryModel({
    required this.id,
    required this.storyId,
    required this.summary,
  });

  factory StoryMemoryModel.fromJson(Map<String, dynamic> json) {
    return StoryMemoryModel(
      id: json['id'],
      storyId: json['storyId'],
      summary: json['summary'],
    );
  }
}
