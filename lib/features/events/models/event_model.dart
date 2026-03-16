class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final String date;
  final String imageUrl;
  final String createdBy;
  final String createdByRole;
  final bool isActive;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.date,
    required this.imageUrl,
    required this.createdBy,
    required this.createdByRole,
    required this.isActive,
  });

  factory EventModel.fromMap(String id, Map<String, dynamic> map) {
    return EventModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'genel',
      location: map['location'] ?? '',
      date: map['date'] ?? '',
      imageUrl: (map['imageUrl'] ?? '').toString(),
      createdBy: map['createdBy'] ?? '',
      createdByRole: map['createdByRole'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'date': date,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'isActive': isActive,
    };
  }
}
