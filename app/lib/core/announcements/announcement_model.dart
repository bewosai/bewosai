class Announcement {
  final int id;
  final String title;
  final String body;

  Announcement({required this.id, required this.title, required this.body});

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}
