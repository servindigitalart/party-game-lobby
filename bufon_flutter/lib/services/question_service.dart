// services/question_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/question.dart';

class QuestionService {
  List<Question> _questions = [];
  final Random _random = Random();

  Future<void> loadQuestions() async {
    final String jsonString = await rootBundle.loadString(
      'assets/questions.json',
    );
    final List<dynamic> jsonList = json.decode(jsonString);
    _questions = jsonList.map((json) => Question.fromJson(json)).toList();
  }

  Question getRandomQuestion(List<String> usedQuestionIds) {
    final availableQuestions = _questions
        .where((q) => !usedQuestionIds.contains(q.id))
        .toList();

    if (availableQuestions.isEmpty) {
      // If all questions used, reset and pick any
      return _questions[_random.nextInt(_questions.length)];
    }

    return availableQuestions[_random.nextInt(availableQuestions.length)];
  }

  List<Question> getAllQuestions() => _questions;
}
