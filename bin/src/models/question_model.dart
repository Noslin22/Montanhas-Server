import 'dart:convert';

import 'answer_model.dart';

class QuestionModel {
  final String? id;
  final String title;
  final String subtitle;
  final String question;
  final List<AnswerModel> answers;
  QuestionModel({
    this.id,
    required this.title,
    required this.subtitle,
    required this.question,
    required this.answers,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'question': question,
      'answers': answers.map((x) => x.toMap()).toList(),
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'],
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      question: map['question'] ?? '',
      answers: List<AnswerModel>.from((map['answers'] as Map).values.map((x) => AnswerModel.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory QuestionModel.fromJson(String source) => QuestionModel.fromMap(json.decode(source));
}
