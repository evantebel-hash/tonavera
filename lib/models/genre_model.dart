class GenreModel {
  final int id;
  final String name;

  GenreModel({required this.id, required this.name});

  factory GenreModel.fromJson(Map<String, dynamic> json) {
    return GenreModel(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
    );
  }
}
