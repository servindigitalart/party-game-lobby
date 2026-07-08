// models/question.dart
class Question {
  final String id;
  final String text;
  final String pack;

  Question({required this.id, required this.text, required this.pack});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'pack': pack};

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    text: json['text'] as String,
    pack: json['pack'] as String,
  );
}
