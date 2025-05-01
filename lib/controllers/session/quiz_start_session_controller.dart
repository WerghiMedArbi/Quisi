import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/session.dart';
import '../../models/question_timer.dart';
import '../../models/score_calculator.dart';

class QuizStartSessionController extends ChangeNotifier {
  final String quizId;
  final String sessionId;
  final String quizTitle;
  
  late Session _session;
  late QuestionTimer _questionTimer;
  bool _isActive = false;

  QuizStartSessionController({
    required this.quizId,
    required this.sessionId,
    required this.quizTitle,
  }) {
    _session = Session(
      id: sessionId,
      quizId: quizId,
      quizTitle: quizTitle,
    );
    _questionTimer = QuestionTimer(
      onTimeUp: _moveToNextQuestion,
    );
  }

  bool get isActive => _isActive;
  ValueNotifier<int> get timeRemaining => _questionTimer.timeRemaining;

  Future<void> startSession() async {
    try {
      await _session.start();
      _questionTimer.start();
      _isActive = true;
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('Cannot start session without participants')) {
        rethrow;
      }
      print('Error starting session: $e');
    }
  }

  Future<void> endSession() async {
    try {
      _questionTimer.stop();
      await _session.end();
      _isActive = false;
      notifyListeners();
    } catch (e) {
      print('Error ending session: $e');
    }
  }

  Future<void> _moveToNextQuestion() async {
    try {
      await _session.moveToNextQuestion();
      
      if (_session.isCompleted) {
        return;
      }
      
      _questionTimer.start();
    } catch (e) {
      print('Error moving to next question: $e');
    }
  }

  Future<void> removeParticipant(String participantId) async {
    try {
      await FirebaseFirestore.instance
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
    }
  }

  Future<void> cleanupSession() async {
    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({
        'active': false,
        'sessionEnded': true,
        'sessionEndedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error cleaning up session: $e');
    }
  }

  @override
  void dispose() {
    _questionTimer.dispose();
    super.dispose();
  }
} 