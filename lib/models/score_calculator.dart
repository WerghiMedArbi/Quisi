import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreCalculator {
  static const int maxScore = 100;
  static const int maxTime = 10;

  static int calculateScore(bool isCorrect, int timeRemaining) {
    if (!isCorrect) return 0;
    return (maxScore * timeRemaining / maxTime).round();
  }

  static Future<void> updateParticipantScore({
    required String sessionId,
    required String participantId,
    required bool isCorrect,
    required int timeRemaining,
  }) async {
    final score = calculateScore(isCorrect, timeRemaining);
    
    final participantRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('participants')
        .doc(participantId);

    final participantDoc = await participantRef.get();
    final currentScore = (participantDoc.data()?['score'] ?? 0) as int;

    await participantRef.update({
      'score': currentScore + score,
      'answeredCurrentQuestion': true,
      'currentAnswer': isCorrect,
      'lastAnswerScore': score,
      'lastAnswerTime': timeRemaining,
    });
  }
} 