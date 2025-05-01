import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String quizId;
  final String quizTitle;
  bool isActive;
  bool isCompleted;
  int currentQuestionIndex;
  bool showingTransition;
  DateTime? startedAt;
  DateTime? endedAt;

  Session({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    this.isActive = false,
    this.isCompleted = false,
    this.currentQuestionIndex = 0,
    this.showingTransition = false,
    this.startedAt,
    this.endedAt,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      quizId: data['quizId'] ?? '',
      quizTitle: data['quizTitle'] ?? '',
      isActive: data['active'] ?? false,
      isCompleted: data['completed'] ?? false,
      currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
      showingTransition: data['showingTransition'] ?? false,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<void> start() async {
    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(id)
        .collection('participants')
        .get();
        
    if (participantsSnapshot.docs.isEmpty) {
      throw Exception('Cannot start session without participants');
    }

    await FirebaseFirestore.instance.collection('sessions').doc(id).update({
      'active': true,
      'sessionEnded': false,
      'startedAt': FieldValue.serverTimestamp(),
      'questionStartTime': FieldValue.serverTimestamp(),
      'timerStartedAt': FieldValue.serverTimestamp(),
      'timerDurationSeconds': 10,
      'currentQuestionIndex': 0,
      'showingTransition': false,
    });

    isActive = true;
  }

  Future<void> end() async {
    await FirebaseFirestore.instance.collection('sessions').doc(id).update({
      'active': false,
      'sessionEnded': true,
      'sessionEndedAt': FieldValue.serverTimestamp(),
    });

    isActive = false;
    isCompleted = true;
    endedAt = DateTime.now();
  }

  Future<void> moveToNextQuestion() async {
    final quizDoc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();
        
    if (!quizDoc.exists) return;
    
    final quizData = quizDoc.data() as Map<String, dynamic>;
    final questions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);
    
    if (currentQuestionIndex >= questions.length - 1) {
      await end();
      return;
    }

    await FirebaseFirestore.instance.collection('sessions').doc(id).update({
      'showingTransition': true,
      'transitionStartTime': FieldValue.serverTimestamp(),
    });
    
    await Future.delayed(const Duration(seconds: 3));
    
    await FirebaseFirestore.instance.collection('sessions').doc(id).update({
      'currentQuestionIndex': currentQuestionIndex + 1,
      'questionStartTime': FieldValue.serverTimestamp(),
      'timerStartedAt': FieldValue.serverTimestamp(),
      'timerDurationSeconds': 10,
      'everyoneAnswered': false,
      'showingTransition': false,
    });
    
    currentQuestionIndex++;
    
    // Reset participant answers
    final batch = FirebaseFirestore.instance.batch();
    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(id)
        .collection('participants')
        .where('removed', isEqualTo: false)
        .get();
        
    for (var participant in participantsSnapshot.docs) {
      batch.update(participant.reference, {
        'answeredCurrentQuestion': false,
        'currentAnswer': null,
      });
    }
    
    await batch.commit();
  }
} 