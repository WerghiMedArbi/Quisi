
import 'package:cloud_firestore/cloud_firestore.dart'; 

class Question {
  final String text;
  final List<String> options;
  final int correctOptionIndex;

  Question({
    required this.text,
    required this.options,
    required this.correctOptionIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      text: map['text'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final List<Question> questions;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.title,
    required this.questions,
    required this.createdAt,
  });

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Quiz(
      id: doc.id,
      title: data['title'] ?? '',
      questions: (data['questions'] as List?)
          ?.map((q) => Question.fromMap(q as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}