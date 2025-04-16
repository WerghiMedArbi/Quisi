import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/app_background.dart';

class QuizParticipationScreen extends StatefulWidget {
  final String quizId;
  final String sessionId;
  final String participantId;
  
  const QuizParticipationScreen({
    Key? key, 
    required this.quizId, 
    required this.sessionId,
    required this.participantId,
  }) : super(key: key);
  
  @override
  _QuizParticipationScreenState createState() => _QuizParticipationScreenState();
}

class _QuizParticipationScreenState extends State<QuizParticipationScreen> {
  bool _isLoading = true;
  String _status = 'Waiting for quiz to start...';
  Map<String, dynamic>? _currentQuestion;
  int? _selectedOption;
  bool _hasAnswered = false;
  bool _showResults = false;
  int _correctOptionIndex = -1;
  bool _readyForNext = false;
  int _score = 0;
  int _currentQuestionIndex = 0;
  int _totalQuestions = 0;
  
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _participantSubscription;
  
  @override
  void initState() {
    super.initState();
    _listenToSession();
    _listenToParticipant();
  }
  
  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _participantSubscription?.cancel();
    super.dispose();
  }
  
  void _listenToSession() {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId);
    
    _sessionSubscription = sessionRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        setState(() {
          _status = 'Session not found';
          _isLoading = false;
        });
        return;
      }
      
      final sessionData = snapshot.data() as Map<String, dynamic>;
      final bool active = sessionData['active'] ?? false;
      final bool completed = sessionData['completed'] ?? false;
      
      if (completed) {
        setState(() {
          _status = 'Quiz completed!';
          _isLoading = false;
        });
        
        // Get final score
        final participantDoc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('participants')
            .doc(widget.participantId)
            .get();
            
        if (participantDoc.exists) {
          final participantData = participantDoc.data() as Map<String, dynamic>;
          setState(() {
            _score = participantData['score'] ?? 0;
          });
        }
        
        return;
      }
      
      if (!active) {
        setState(() {
          _status = 'Waiting for quiz to start...';
          _isLoading = false;
        });
        return;
      }
      
      // Active quiz, get current question
      final int currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
      
      // Fetch quiz details to get the question
      try {
        final quizDoc = await FirebaseFirestore.instance
            .collection('quizzes')
            .doc(widget.quizId)
            .get();
            
        if (!quizDoc.exists) {
          setState(() {
            _status = 'Quiz not found';
            _isLoading = false;
          });
          return;
        }
        
        final quizData = quizDoc.data() as Map<String, dynamic>;
        final questions = quizData['questions'] as List<dynamic>;
        
        if (currentQuestionIndex >= questions.length) {
          setState(() {
            _status = 'Waiting for results...';
            _isLoading = false;
          });
          return;
        }
        
        final questionData = questions[currentQuestionIndex] as Map<String, dynamic>;
        
        // Check if user already answered this question
        final participantDoc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('participants')
            .doc(widget.participantId)
            .get();
            
        final participantData = participantDoc.data() as Map<String, dynamic>;
        final answeredQuestions = List<dynamic>.from(participantData['answeredQuestions'] ?? []);
        
        final bool alreadyAnswered = answeredQuestions.contains(currentQuestionIndex);
        final bool everyoneAnswered = sessionData['everyoneAnswered'] ?? false;
        
        setState(() {
          _currentQuestion = questionData;
          _correctOptionIndex = questionData['correctOptionIndex'] ?? 0;
          _hasAnswered = alreadyAnswered;
          _showResults = everyoneAnswered;
          _readyForNext = participantData['readyForNextQuestion'] ?? false;
          _score = participantData['score'] ?? 0;
          _currentQuestionIndex = currentQuestionIndex;
          _totalQuestions = questions.length;
          _isLoading = false;
        });
        
      } catch (e) {
        print('Error fetching quiz data: $e');
        setState(() {
          _status = 'Error: $e';
          _isLoading = false;
        });
      }
    });
  }
  
  void _listenToParticipant() {
    _participantSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('participants')
        .doc(widget.participantId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _score = data['score'] ?? 0;
      });
    });
  }
  
  Future<void> _submitAnswer(int optionIndex) async {
    if (_hasAnswered) return;
    
    setState(() {
      _selectedOption = optionIndex;
      _hasAnswered = true;
    });
    
    try {
      // Get current question index
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
      
      // Mark this question as answered
      final participantRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .doc(widget.participantId);
          
      final participantDoc = await participantRef.get();
      final participantData = participantDoc.data() as Map<String, dynamic>;
      
      List<dynamic> answeredQuestions = List<dynamic>.from(participantData['answeredQuestions'] ?? []);
      answeredQuestions.add(currentQuestionIndex);
      
      // Calculate score
      int score = participantData['score'] ?? 0;
      if (optionIndex == _correctOptionIndex) {
        // Correct answer, add points
        score += 10;
      }
      
      await participantRef.update({
        'answeredQuestions': answeredQuestions,
        'score': score,
        'lastAnsweredAt': FieldValue.serverTimestamp(),
      });
      
      // Show snackbar for feedback
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            optionIndex == _correctOptionIndex 
              ? 'Correct! +10 points' 
              : 'Incorrect! The correct answer was option ${_correctOptionIndex + 1}',
          ),
          backgroundColor: optionIndex == _correctOptionIndex ? Colors.green : Colors.red,
        ),
      );
      
    } catch (e) {
      print('Error submitting answer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting answer: $e')),
      );
    }
  }
  
  Future<void> _markReadyForNextQuestion() async {
    if (!_hasAnswered || _readyForNext) return;
    
    setState(() {
      _readyForNext = true;
    });
    
    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .doc(widget.participantId)
          .update({
            'readyForNextQuestion': true,
          });
    } catch (e) {
      print('Error marking ready: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking as ready: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBackground.buildAppBar(title: 'Quiz'),
        body: AppBackground.buildBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 24),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show quiz completed screen
    if (_status == 'Quiz completed!') {
      return Scaffold(
        appBar: AppBackground.buildAppBar(title: 'Quiz Complete'),
        body: AppBackground.buildBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  margin: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.celebration, size: 80, color: Colors.amber),
                      SizedBox(height: 16),
                      Text(
                        'Quiz Completed!', 
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your final score: $_score', 
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: AppBackground.primaryButtonStyle(),
                        child: Text(
                          'Return to Home',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show waiting screen if no question is available
    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBackground.buildAppBar(title: 'Quiz'),
        body: AppBackground.buildBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  margin: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        size: 64,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _status,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show the current question
    final question = _currentQuestion!;
    final options = List<String>.from(question['options'] ?? []);
    
    return Scaffold(
      appBar: AppBackground.buildAppBar(
        title: 'Question ${_currentQuestionIndex + 1}/$_totalQuestions',
      ),
      body: AppBackground.buildBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Score indicator
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $_score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_hasAnswered && !_showResults)
                      Text(
                        'Waiting for others...',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Question card
              Expanded(
                child: Card(
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question text
                        Text(
                          question['text'] ?? 'No question text',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 24),
                        
                        // Options list
                        Expanded(
                          child: ListView.builder(
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedOption == index;
                              final isCorrect = _showResults && index == _correctOptionIndex;
                              final isWrong = _showResults && isSelected && index != _correctOptionIndex;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: _hasAnswered ? null : () => _submitAnswer(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isCorrect 
                                          ? Colors.green.shade100 
                                          : isWrong 
                                              ? Colors.red.shade100 
                                              : isSelected 
                                                  ? Colors.blue.shade100 
                                                  : Colors.grey.shade50,
                                      border: Border.all(
                                        color: isCorrect 
                                            ? Colors.green 
                                            : isWrong 
                                                ? Colors.red
                                                : isSelected 
                                                    ? Colors.blue 
                                                    : Colors.grey.shade300,
                                        width: isSelected || isCorrect || isWrong ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isCorrect 
                                                ? Colors.green 
                                                : isWrong 
                                                    ? Colors.red 
                                                    : isSelected 
                                                        ? Colors.blue 
                                                        : Colors.grey.shade300,
                                          ),
                                          child: Text(
                                            String.fromCharCode(65 + index), // A, B, C, D...
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            options[index],
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                        if (isCorrect)
                                          Icon(Icons.check_circle, color: Colors.green)
                                        else if (isWrong)
                                          Icon(Icons.cancel, color: Colors.red),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Ready for next question button
                        if (_showResults && !_readyForNext)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _markReadyForNextQuestion,
                                style: AppBackground.secondaryButtonStyle(),
                                child: Text(
                                  'READY FOR NEXT QUESTION',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          
                        if (_readyForNext)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text(
                                    'Waiting for next question...',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}