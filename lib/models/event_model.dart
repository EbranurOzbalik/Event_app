class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final String date;
  final String createdBy;
  final String createdByRole;
  final bool isActive;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.createdBy,
    required this.createdByRole,
    required this.isActive,
  });

  factory EventModel.fromMap(String id, Map<String, dynamic> map) {
    return EventModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      date: map['date'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByRole: map['createdByRole'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'isActive': isActive,
    };
  }
}