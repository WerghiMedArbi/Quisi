import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/app_background.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import './quiz_results_screen.dart';

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
  ValueNotifier<int> _timeRemaining = ValueNotifier<int>(10);
  Timer? _timer;
  bool _sessionEnded = false;
  DateTime? _questionStartTime;
  bool _showingTransition = false;
  int _transitionTimeRemaining = 5;
  Timer? _transitionTimer;
  
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _participantSubscription;
  
  @override
  void initState() {
    super.initState();
    _listenToSession();
    _setupParticipantListener();
  }
  
  void _setupParticipantListener() {
    // Listen for participant document changes
    _participantSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('participants')
        .doc(widget.participantId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || (snapshot.data()?['removed'] ?? false)) {
        // Participant was removed
        _handleRemoval();
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _score = data['score'] ?? 0;
      });
    });
  }
  
  void _handleRemoval() {
    // Cancel any existing subscriptions
    _participantSubscription?.cancel();
    _sessionSubscription?.cancel();
    _timer?.cancel();
    _transitionTimer?.cancel();

    // Show removal dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Session Ended'),
        content: Text('You have been removed from this session by the admin.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/scan');
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _transitionTimer?.cancel();
    _timeRemaining.dispose();
    _sessionSubscription?.cancel();
    _participantSubscription?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    _timer?.cancel();
    
    if (!mounted || _hasAnswered || _sessionEnded) return;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _hasAnswered || _sessionEnded) {
        timer.cancel();
        return;
      }
      
      if (_timeRemaining.value <= 0) {
        timer.cancel();
        _handleTimeExpired();
        return;
      }
      
      _timeRemaining.value--;
    });
  }
  
  void _listenToSession() {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId);
    
    _sessionSubscription = sessionRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || !mounted) {
        setState(() {
          _status = 'Session not found';
          _isLoading = false;
        });
        return;
      }
      
      final sessionData = snapshot.data() as Map<String, dynamic>;
      final bool active = sessionData['active'] ?? false;
      final bool completed = sessionData['completed'] ?? false;
      final bool sessionEnded = sessionData['sessionEnded'] ?? false;
      final questionStartTime = sessionData['questionStartTime']?.toDate();
      final timerStartedAt = sessionData['timerStartedAt']?.toDate();
      final timerDurationSeconds = sessionData['timerDurationSeconds'] ?? 10;
      final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
      final showingTransition = sessionData['showingTransition'] ?? false;
      
      // Handle question transitions
      if ((currentQuestionIndex != _currentQuestionIndex || showingTransition != _showingTransition) && active && !sessionEnded) {
        if (showingTransition) {
          _showTransitionMessage();
        }
      }
      
      // Update timer based on server time
      if (timerStartedAt != null && active && !sessionEnded && !showingTransition && !_hasAnswered) {
        final now = DateTime.now();
        final elapsed = now.difference(timerStartedAt).inSeconds;
        final remaining = math.max<int>(0, timerDurationSeconds - elapsed);
        _timeRemaining.value = remaining;
        
        if (remaining > 0 && !_hasAnswered) {
          _startTimer();
        } else if (remaining <= 0 && !_hasAnswered) {
          _handleTimeExpired();
        }
      }

      setState(() {
        _sessionEnded = sessionEnded;
        _questionStartTime = questionStartTime;
        _showingTransition = showingTransition;
      });

      if (sessionEnded) {
        _timer?.cancel();
        _transitionTimer?.cancel();
        setState(() {
          _status = 'Session ended by admin';
          _isLoading = false;
          _currentQuestion = null;
        });
        
        // Navigate to results screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QuizResultsScreen(
                sessionId: widget.sessionId,
                quizTitle: sessionData['quizTitle'] ?? 'Quiz Results',
              ),
            ),
          );
        }
        return;
      }
      
      // Handle question changes
      if (currentQuestionIndex != _currentQuestionIndex) {
        setState(() {
          _hasAnswered = false;
          _selectedOption = null;
          _showResults = false;
          _currentQuestionIndex = currentQuestionIndex;
        });
      }
      
      if (completed) {
        setState(() {
          _status = 'Quiz completed!';
          _isLoading = false;
        });
        return;
      }
      
      if (!active) {
        setState(() {
          _status = 'Waiting for quiz to start...';
          _isLoading = false;
        });
        return;
      }

      // Get current question
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
        
        setState(() {
          _currentQuestion = questionData;
          _correctOptionIndex = questionData['correctOptionIndex'] ?? 0;
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
  
  void _showTransitionMessage() {
    setState(() {
      _showingTransition = true;
      _transitionTimeRemaining = 5;
      _hasAnswered = false;
      _selectedOption = null;
    });

    _transitionTimer?.cancel();
    _transitionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_transitionTimeRemaining > 0) {
        setState(() {
          _transitionTimeRemaining--;
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _showingTransition = false;
          });
        }
      }
    });
  }
  
  Future<void> _submitAnswer(int optionIndex) async {
    if (_hasAnswered) return;
    
    _timer?.cancel();
    
    final isCorrect = optionIndex == _correctOptionIndex;
    final timeRemaining = _timeRemaining.value;
    
    setState(() {
      _selectedOption = optionIndex;
      _hasAnswered = true;
    });
    
    try {
      // Get current score
      final participantRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .doc(widget.participantId);
          
      final participantDoc = await participantRef.get();
      final participantData = participantDoc.data() as Map<String, dynamic>;
      
      // Calculate score based on response time
      int score = participantData['score'] ?? 0;
      if (isCorrect) {
        // Max 100 points for immediate correct answer
        // Score decreases linearly with time
        // The faster you answer, the more points you get
        final maxScore = 100;
        final maxTime = 10; // maximum time in seconds
        final timeElapsed = maxTime - timeRemaining;
        
        // Calculate score: maxScore * (1 - timeElapsed/maxTime)
        // This gives more points for faster answers
        final questionScore = (maxScore * (1 - timeElapsed/maxTime)).round();
        score += questionScore;
      }
      
      // Update participant record
      await participantRef.update({
        'currentAnswer': optionIndex,
        'answeredCurrentQuestion': true,
        'lastAnsweredAt': FieldValue.serverTimestamp(),
        'lastAnswerTime': timeRemaining,
        'lastAnswerScore': score - (participantData['score'] ?? 0),
        'score': score,
        'isCorrect': isCorrect,
      });
      
      if (!mounted) return;

      // Show correct/wrong answer feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct! +${score - (participantData['score'] ?? 0)} points' : 'Wrong answer',
              ),
            ],
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.red,
        ),
      );
      
    } catch (e) {
      print('Error recording answer: $e');
      if (!mounted) return;
      
      // Reset state if update fails
      setState(() {
        _hasAnswered = false;
        _selectedOption = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record answer. Please try again.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () => _submitAnswer(optionIndex),
          ),
        ),
      );
    }
  }
  
  void _handleTimeExpired() {
    if (!_hasAnswered) {
      _submitAnswer(-1); // Submit no answer
      
      // Show time expired message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.timer_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Time\'s up! The correct answer was option ${String.fromCharCode(65 + _correctOptionIndex)}'),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
        appBar: AppBar(
          title: Text('Quiz'),
          backgroundColor: AppBackground.primaryColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.go('/scan'),
          ),
        ),
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
    if (_status == 'Quiz completed!' || _sessionEnded) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Quiz Complete'),
          backgroundColor: AppBackground.primaryColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.go('/scan'),
          ),
        ),
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
                        _sessionEnded ? 'Session Ended' : 'Quiz Completed!',
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
                        onPressed: () => context.go('/scan'),
                        style: AppBackground.primaryButtonStyle(),
                        child: Text(
                          'Return to Scanner',
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
        appBar: AppBar(
          title: Text('Quiz'),
          backgroundColor: AppBackground.primaryColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.go('/scan'),
          ),
        ),
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
    
    // Show transition screen
    if (_showingTransition) {
      return Scaffold(
        body: AppBackground.buildBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward, size: 64, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Get Ready!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Next question in $_transitionTimeRemaining seconds...',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
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
      appBar: AppBar(
        title: Text('Question ${_currentQuestionIndex + 1}/$_totalQuestions'),
        backgroundColor: AppBackground.primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/scan'),
        ),
      ),
      body: AppBackground.buildBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Score and timer indicator
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
                    if (!_hasAnswered && !_showResults)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            ValueListenableBuilder<int>(
                              valueListenable: _timeRemaining,
                              builder: (context, timeValue, _) {
                                return Text(
                                  '$timeValue s',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ],
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
                        Text(
                          question['text'] ?? 'No question text',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 24),
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
                                            String.fromCharCode(65 + index),
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
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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