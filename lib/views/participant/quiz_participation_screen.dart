import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../utils/app_background.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../quiz/quiz_results_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

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

      if (sessionEnded || completed) {
        _timer?.cancel();
        _transitionTimer?.cancel();
        
        try {
          final participantDoc = await FirebaseFirestore.instance
              .collection('sessions')
              .doc(widget.sessionId)
              .collection('participants')
              .doc(widget.participantId)
              .get();
              
          if (participantDoc.exists && mounted) {
            final participantData = participantDoc.data() as Map<String, dynamic>;
        setState(() {
              _score = participantData['score'] ?? 0;
              _status = 'Quiz completed!';
          _isLoading = false;
          _currentQuestion = null;
              _sessionEnded = true;
        });
          }
        } catch (e) {
          print('Error getting final score: $e');
        if (mounted) {
            setState(() {
              _status = 'Error getting results';
              _isLoading = false;
            });
          }
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
    setState(() {
      _selectedOption = optionIndex;
      _hasAnswered = true;
    });
    try {
      // Fetch session to get timerStartedAt
      final sessionSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();
      if (!sessionSnapshot.exists) {
        print('Session not found');
        return;
      }
      final sessionDataSnap = sessionSnapshot.data() as Map<String, dynamic>;
      final Timestamp? timerStartedAtTs = sessionDataSnap['timerStartedAt'];
      final int maxTime = sessionDataSnap['timerDurationSeconds'] ?? 10;
      DateTime? timerStartedAt;
      if (timerStartedAtTs != null) {
        timerStartedAt = timerStartedAtTs.toDate().toUtc();
      }
      final nowUtc = DateTime.now().toUtc();
      int elapsed = 0;
      if (timerStartedAt != null) {
        elapsed = nowUtc.difference(timerStartedAt).inSeconds;
      }
      int timeRemaining = math.max(0, maxTime - elapsed);
      // Fetch participant
      final participantRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .doc(widget.participantId);
      final participantDoc = await participantRef.get();
      final participantData = participantDoc.data() as Map<String, dynamic>;
      int score = participantData['score'] ?? 0;
      if (isCorrect) {
        final maxScore = 100;
        final questionScore = (maxScore * (1 - elapsed / maxTime)).round();
        score += questionScore;
      }
      await participantRef.update({
        'currentAnswer': optionIndex,
        'answeredCurrentQuestion': true,
        'lastAnsweredAt': FieldValue.serverTimestamp(),
        'lastAnswerTime': timeRemaining,
        'lastAnswerScore': score - (participantData['score'] ?? 0),
        'score': score,
        'isCorrect': isCorrect,
      });

      // Check if this was the last question
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();
      
      if (!sessionDoc.exists) {
        print('Session not found');
        return;
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
      
      final quizDoc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .get();
      
      if (!quizDoc.exists) {
        print('Quiz not found');
        return;
      }

      final quizData = quizDoc.data() as Map<String, dynamic>;
      final questions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);
      
      if (currentQuestionIndex >= questions.length - 1) {
        // This was the last question, update session state
        try {
          await FirebaseFirestore.instance
              .collection('sessions')
              .doc(widget.sessionId)
              .update({
                'completed': true,
                'active': false,
                'sessionEnded': true,
                'sessionEndedAt': FieldValue.serverTimestamp(),
              });
              
          if (mounted) {
            setState(() {
              _status = 'Quiz completed!';
              _sessionEnded = true;
              _score = score;
            });
          }
        } catch (e) {
          print('Error updating session state: $e');
          // Even if session update fails, show results to the user
          if (mounted) {
            setState(() {
              _status = 'Quiz completed!';
              _sessionEnded = true;
              _score = score;
            });
          }
        }
      }
      
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
      
      setState(() {
        _hasAnswered = false;
        _selectedOption = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record answer: ${e.toString()}'),
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // QUISI Logo
              Row(
                children: [
                  Text(
                    "QU",
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    "ISI",
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppBackground.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              // QUISI Logo
              Row(
                    children: [
                      Text(
                    "QU",
                    style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                      color: Colors.black,
                        ),
                      ),
                      Text(
                    "ISI",
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppBackground.primaryColor,
                        ),
                      ),
                    ],
                ),
              ],
            ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => context.go('/scan'),
          ),
        ),
        body: AppBackground.buildBackground(
          child: _buildResultsView(),
        ),
      );
    }
    
    // Show waiting screen if no question is available
    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // QUISI Logo
              Row(
                children: [
                  Text(
                    "QU",
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    "ISI",
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppBackground.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
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
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 100,
                        child: Lottie.asset(
                          'assets/animations/loader_cat.json',
                          repeat: true,
                          animate: true,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _status,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppBackground.primaryColor,
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
                Icon(Icons.arrow_forward, size: 64, color: Colors.blue.shade700),
                SizedBox(height: 24),
                Text(
                  'Next Question',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Question ${_currentQuestionIndex + 2}',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 32),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // QUISI Logo
            Row(
              children: [
                Text(
                  "Question  ",
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "${_currentQuestionIndex + 1}/$_totalQuestions",
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppBackground.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
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
                        color:  Colors.blue.shade900,
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
                            Icon(Icons.timer, 
                            color: Colors.blue.shade700, 
                            size: 18),
                            SizedBox(width: 8),
                            ValueListenableBuilder<int>(
                              valueListenable: _timeRemaining,
                              builder: (context, timeValue, _) {
                                return Text(
                                  '$timeValue s',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
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
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question['text'] ?? 'No question text',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
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
                                          ? Colors.green.shade50
                                          : isWrong 
                                              ? Colors.red.shade50
                                              : isSelected 
                                                  ? Colors.blue.shade50
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
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
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

  Future<void> _moveToNextQuestion() async {
    if (!mounted) return;
    
    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId);
      
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) return;
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
      
      final quizDoc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .get();
          
      if (!quizDoc.exists) return;
      
      final quizData = quizDoc.data() as Map<String, dynamic>;
      final questions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);
      
      if (currentQuestionIndex >= questions.length - 1) {
        // Last question completed - update session state
        await sessionRef.update({
          'completed': true,
          'active': false,
          'sessionEnded': true,
          'sessionEndedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          setState(() {
            _status = 'Quiz completed!';
            _sessionEnded = true;
          });
        }
        return;
      }

      // Show transition screen
      await sessionRef.update({
        'showingTransition': true,
        'transitionStartTime': FieldValue.serverTimestamp(),
      });
      
      // Wait for transition
      await Future.delayed(Duration(seconds: 3));
      
      if (!mounted) return;
      
      // Move to next question
      await sessionRef.update({
        'currentQuestionIndex': currentQuestionIndex + 1,
        'questionStartTime': FieldValue.serverTimestamp(),
        'timerStartedAt': FieldValue.serverTimestamp(),
        'timerDurationSeconds': 10,
        'everyoneAnswered': false,
        'showingTransition': false,
      });
      
      // Reset participant answers
      final batch = FirebaseFirestore.instance.batch();
      final participantsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
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
      
      if (mounted) {
        setState(() {
          _hasAnswered = false;
          _selectedOption = null;
          _showResults = false;
          _currentQuestionIndex = currentQuestionIndex + 1;
        });
      }
      
      // Start timer for next question
      _startTimer();
      
    } catch (e) {
      print('Error moving to next question: $e');
    }
  }

  Widget _buildResultsView() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('participants')
          .get()
          .then((snapshot) {
            print('Debug: Querying session ${widget.sessionId}');
            print('Debug: Current participant ID: ${widget.participantId}');
            print('Debug: Total documents found: ${snapshot.docs.length}');
            
            for (var doc in snapshot.docs) {
              print('Debug: Found participant ${doc.id}');
              print('Debug: Participant data: ${doc.data()}');
            }
            
            return snapshot;
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Calculating final results...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error loading results: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading results: ${snapshot.error}',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                  ),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('No results found. Session ID: ${widget.sessionId}');
          print('Has data: ${snapshot.hasData}');
          print('Docs length: ${snapshot.data?.docs.length ?? 0}');
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'No results available yet.\nPlease wait a moment...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppBackground.primaryColor,
                  ),
                  child: Text('Refresh'),
                ),
              ],
            ),
          );
        }

        final participants = snapshot.data!.docs;
        print('Found ${participants.length} participants');
        int userRank = 0;
        Map<String, dynamic>? userData;

        for (int i = 0; i < participants.length; i++) {
          final participant = participants[i].data() as Map<String, dynamic>;
          if (participants[i].id == widget.participantId) {
            userRank = i + 1;
            userData = participant;
            break;
          }
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    if (userRank > 0 && userData != null) ...[
                      Text(
                        'Your Results',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Rank: #$userRank',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Score: ${userData['score']}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      if (userRank <= 3) ...[
                        SizedBox(height: 16),
                        Container(
                          height: 200,
                          child: Lottie.asset(
                            'assets/animations/celebration.json',
                            repeat: true,
                            animate: true,
                          ),
                        ),
                        Text(
                          userRank == 1
                              ? 'Congratulations! You won! 🎉'
                              : userRank == 2
                                  ? 'Amazing! Second place! 🥈'
                                  : 'Great job! Third place! 🥉',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ] else ...[
                        SizedBox(height: 16),
                        Container(
                          height: 150,
                          child: Lottie.asset(
                            'assets/animations/confetti.json',
                            repeat: true,
                            animate: true,
                          ),
                        ),
                        Text(
                          'Thanks for participating! 🌟',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                    SizedBox(height: 32),
                    Text(
                      'Top 3 Players',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    ...participants.take(3).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final rank = participants.indexOf(doc) + 1;
                      final isCurrentUser = doc.id == widget.participantId;
                      
                      return ListTile(
                        leading: Icon(
                          Icons.emoji_events,
                          color: rank == 1
                              ? Colors.amber
                              : rank == 2
                                  ? Colors.grey[400]
                                  : Colors.brown,
                        ),
                        title: Text(
                          data['name'] ?? 'Unknown Player',
                          style: TextStyle(
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                        trailing: Text(
                          'Score: ${data['score']}',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  context.go('/scan');
                },
                child: Text('Return to Home'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}