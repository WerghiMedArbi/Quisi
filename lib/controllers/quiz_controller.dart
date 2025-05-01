import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz_model.dart';
import '../models/session_model.dart';

class QuizController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get quizzes for a user
  Stream<List<Quiz>> getUserQuizzes(String userId) {
    return _firestore
        .collection('quizzes')
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Quiz.fromFirestore(doc))
            .toList());
  }

  // Get a single quiz
  Future<Quiz?> getQuiz(String quizId) async {
    try {
      final doc = await _firestore.collection('quizzes').doc(quizId).get();
      return doc.exists ? Quiz.fromFirestore(doc) : null;
    } catch (e) {
      print('Error getting quiz: $e');
      return null;
    }
  }

  // Create a new quiz
  Future<String> createQuiz(Quiz quiz) async {
    try {
      final docRef = await _firestore.collection('quizzes').add(quiz.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating quiz: $e');
      rethrow;
    }
  }

  // Update an existing quiz
  Future<void> updateQuiz(String quizId, Quiz quiz) async {
    try {
      await _firestore.collection('quizzes').doc(quizId).update(quiz.toMap());
    } catch (e) {
      print('Error updating quiz: $e');
      rethrow;
    }
  }

  // Delete a quiz
  Future<void> deleteQuiz(String quizId) async {
    try {
      // Check for active sessions
      final sessionsQuery = await _firestore
          .collection('sessions')
          .where('quizId', isEqualTo: quizId)
          .where('active', isEqualTo: true)
          .get();

      if (sessionsQuery.docs.isNotEmpty) {
        throw Exception('Cannot delete quiz with active sessions');
      }

      await _firestore.collection('quizzes').doc(quizId).delete();
    } catch (e) {
      print('Error deleting quiz: $e');
      rethrow;
    }
  }

  // Create a new session
  Future<String> createSession(String quizId, String quizTitle) async {
    try {
      final session = QuizSession(
        id: '',  // Will be set by Firestore
        quizId: quizId,
        quizTitle: quizTitle,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('sessions').add(session.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating session: $e');
      rethrow;
    }
  }

  // Get session data
  Stream<QuizSession?> getSessionStream(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? QuizSession.fromFirestore(doc) : null);
  }

  // Update session state
  Future<void> updateSessionState(String sessionId, {
    bool? active,
    bool? completed,
    int? currentQuestionIndex,
    bool? everyoneAnswered,
    bool? sessionEnded,
  }) async {
    try {
      final updates = <String, dynamic>{
        if (active != null) 'active': active,
        if (completed != null) 'completed': completed,
        if (currentQuestionIndex != null) 'currentQuestionIndex': currentQuestionIndex,
        if (everyoneAnswered != null) 'everyoneAnswered': everyoneAnswered,
        if (sessionEnded != null) 'sessionEnded': sessionEnded,
        if (active == true) 'startedAt': FieldValue.serverTimestamp(),
        if (sessionEnded == true) 'sessionEndedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('sessions').doc(sessionId).update(updates);
    } catch (e) {
      print('Error updating session state: $e');
      rethrow;
    }
  }

  // Get session participants
  Stream<List<Participant>> getSessionParticipants(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('participants')
        .where('removed', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Participant.fromFirestore(doc))
            .toList());
  }

  // Add participant to session
  Future<String> addParticipant(String sessionId, String name) async {
    try {
      final participant = Participant(
        id: '',  // Will be set by Firestore
        name: name,
      );

      final docRef = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('participants')
          .add(participant.toMap());

      return docRef.id;
    } catch (e) {
      print('Error adding participant: $e');
      rethrow;
    }
  }

  // Remove participant from session
  Future<void> removeParticipant(String sessionId, String participantId) async {
    try {
      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('participants')
          .doc(participantId)
          .update({
        'removed': true,
        'removedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error removing participant: $e');
      rethrow;
    }
  }

  // Submit answer
  Future<void> submitAnswer(String sessionId, String participantId, int answer) async {
    try {
      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('participants')
          .doc(participantId)
          .update({
        'answeredCurrentQuestion': true,
        'currentAnswer': answer,
      });
    } catch (e) {
      print('Error submitting answer: $e');
      rethrow;
    }
  }

  // Update participant score
  Future<void> updateParticipantScore(String sessionId, String participantId, int newScore) async {
    try {
      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('participants')
          .doc(participantId)
          .update({
        'score': newScore,
      });
    } catch (e) {
      print('Error updating participant score: $e');
      rethrow;
    }
  }
} 