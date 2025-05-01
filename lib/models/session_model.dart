import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String id;
  final String name;
  final bool answeredCurrentQuestion;
  final int? currentAnswer;
  final int score;
  final bool removed;
  final DateTime? removedAt;

  Participant({
    required this.id,
    required this.name,
    this.answeredCurrentQuestion = false,
    this.currentAnswer,
    this.score = 0,
    this.removed = false,
    this.removedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'answeredCurrentQuestion': answeredCurrentQuestion,
      'currentAnswer': currentAnswer,
      'score': score,
      'removed': removed,
      'removedAt': removedAt != null ? Timestamp.fromDate(removedAt!) : null,
    };
  }

  factory Participant.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Participant(
      id: doc.id,
      name: data['name'] ?? '',
      answeredCurrentQuestion: data['answeredCurrentQuestion'] ?? false,
      currentAnswer: data['currentAnswer'],
      score: data['score'] ?? 0,
      removed: data['removed'] ?? false,
      removedAt: (data['removedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class QuizSession {
  final String id;
  final String quizId;
  final String quizTitle;
  final bool active;
  final bool completed;
  final int currentQuestionIndex;
  final bool everyoneAnswered;
  final DateTime? startedAt;
  final DateTime createdAt;
  final bool sessionEnded;
  final DateTime? sessionEndedAt;
  final bool showingTransition;
  final DateTime? transitionStartTime;
  final List<Participant> participants;

  QuizSession({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    this.active = false,
    this.completed = false,
    this.currentQuestionIndex = 0,
    this.everyoneAnswered = false,
    this.startedAt,
    required this.createdAt,
    this.sessionEnded = false,
    this.sessionEndedAt,
    this.showingTransition = false,
    this.transitionStartTime,
    this.participants = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'quizTitle': quizTitle,
      'active': active,
      'completed': completed,
      'currentQuestionIndex': currentQuestionIndex,
      'everyoneAnswered': everyoneAnswered,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'sessionEnded': sessionEnded,
      'sessionEndedAt': sessionEndedAt != null ? Timestamp.fromDate(sessionEndedAt!) : null,
      'showingTransition': showingTransition,
      'transitionStartTime': transitionStartTime != null ? Timestamp.fromDate(transitionStartTime!) : null,
    };
  }

  factory QuizSession.fromFirestore(DocumentSnapshot doc, {List<Participant> participants = const []}) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return QuizSession(
      id: doc.id,
      quizId: data['quizId'] ?? '',
      quizTitle: data['quizTitle'] ?? '',
      active: data['active'] ?? false,
      completed: data['completed'] ?? false,
      currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
      everyoneAnswered: data['everyoneAnswered'] ?? false,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sessionEnded: data['sessionEnded'] ?? false,
      sessionEndedAt: (data['sessionEndedAt'] as Timestamp?)?.toDate(),
      showingTransition: data['showingTransition'] ?? false,
      transitionStartTime: (data['transitionStartTime'] as Timestamp?)?.toDate(),
      participants: participants,
    );
  }
} 