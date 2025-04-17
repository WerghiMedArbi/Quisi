import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/app_background.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import './quiz_results_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class QuizStartSessionScreen extends StatefulWidget {
  final String quizId;
  final String sessionId;
  final String quizTitle;

  const QuizStartSessionScreen({
    Key? key,
    required this.quizId,
    required this.sessionId,
    required this.quizTitle,
  }) : super(key: key);

  @override
  _QuizStartSessionScreenState createState() => _QuizStartSessionScreenState();
}

class _QuizStartSessionScreenState extends State<QuizStartSessionScreen> {
  Timer? _questionTimer;
  final ValueNotifier<int> _timeRemaining = ValueNotifier<int>(10);
  bool _isActive = false;

  @override
  void dispose() {
    _questionTimer?.cancel();
    _timeRemaining.dispose();
    super.dispose();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _timeRemaining.value = 10;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timeRemaining.value > 0) {
        _timeRemaining.value--;
      } else {
        timer.cancel();
        await _moveToNextQuestion();
      }
    });
  }

  Future<void> _calculateScore(String participantId, bool isCorrect, int timeRemaining) async {
    // Score formula: max 100 points for immediate correct answer
    // Score decreases linearly with time
    // Wrong answers get 0 points
    final maxScore = 100;
    final maxTime = 10; // maximum time in seconds
    
    int score = 0;
    if (isCorrect) {
      // Calculate score based on remaining time
      // score = maxScore * (timeRemaining / maxTime)
      score = (maxScore * timeRemaining / maxTime).round();
    }

    // Get the participant's reference
    final participantRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('participants')
        .doc(participantId);

    // Get current score
    final participantDoc = await participantRef.get();
    final currentScore = (participantDoc.data()?['score'] ?? 0) as int;

    // Update participant's score
    await participantRef.update({
      'score': currentScore + score,
      'answeredCurrentQuestion': true,
      'currentAnswer': isCorrect,
      'lastAnswerScore': score,
      'lastAnswerTime': timeRemaining,
    });
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
        // Last question completed
        await sessionRef.update({
          'completed': true,
          'active': false,
          'sessionEnded': true,
          'sessionEndedAt': FieldValue.serverTimestamp(),
        });
        _questionTimer?.cancel();
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QuizResultsScreen(
                sessionId: widget.sessionId,
                quizTitle: widget.quizTitle,
              ),
            ),
          );
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
      
      // Start timer for next question
      _startQuestionTimer();
      
    } catch (e) {
      print('Error moving to next question: $e');
    }
  }

  Future<void> _toggleSession() async {
    try {
      if (!_isActive) {
        final participantsSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('participants')
            .get();
            
        if (participantsSnapshot.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot start session without participants'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        _startQuestionTimer();
        
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .update({
          'active': true,
          'sessionEnded': false,
          'startedAt': FieldValue.serverTimestamp(),
          'questionStartTime': FieldValue.serverTimestamp(),
          'timerStartedAt': FieldValue.serverTimestamp(),
          'timerDurationSeconds': 10,
          'currentQuestionIndex': 0,
          'showingTransition': false,
        });

        setState(() => _isActive = true);
      } else {
        _questionTimer?.cancel();
        
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .update({
          'active': false,
          'sessionEnded': true,
          'sessionEndedAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isActive = false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QuizResultsScreen(
                sessionId: widget.sessionId,
                quizTitle: widget.quizTitle,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Clean up the session
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .update({
          'active': false,
          'sessionEnded': true,
          'sessionEndedAt': FieldValue.serverTimestamp(),
        });
        
        // Navigate back to admin
        if (context.mounted) {
          context.go('/admin');
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBackground.buildAppBar(
          title: widget.quizTitle,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              // Clean up the session
              await FirebaseFirestore.instance
                  .collection('sessions')
                  .doc(widget.sessionId)
                  .update({
                'active': false,
                'sessionEnded': true,
                'sessionEndedAt': FieldValue.serverTimestamp(),
              });
              
              // Navigate back to admin
              if (context.mounted) {
                context.go('/admin');
              }
            },
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.close, color: AppBackground.dangerButtonColor),
              label: Text(
                'END SESSION',
                style: TextStyle(color: AppBackground.dangerButtonColor),
              ),
              onPressed: () async {
                // Clean up the session
                await FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(widget.sessionId)
                    .update({
                  'active': false,
                  'sessionEnded': true,
                  'sessionEndedAt': FieldValue.serverTimestamp(),
                });
                
                // Navigate back to admin
                if (context.mounted) {
                  context.go('/admin');
                }
              },
            ),
            SizedBox(width: 16),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .doc(widget.sessionId)
              .snapshots(),
          builder: (context, sessionSnapshot) {
            if (!sessionSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final sessionData = sessionSnapshot.data!.data() as Map<String, dynamic>;
            final isActive = sessionData['active'] ?? false;
            final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;

            return Row(
              children: [
                // Left panel - Session info and participants
                Container(
                  width: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Session info
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.blue.shade100),
                          ),
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: widget.sessionId,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Session Code',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SelectableText(
                                    widget.sessionId,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: widget.sessionId),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Session code copied'),
                                        ),
                                      );
                                    },
                                    tooltip: 'Copy session code',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Participants list
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('sessions')
                              .doc(widget.sessionId)
                              .collection('participants')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(child: CircularProgressIndicator());
                            }

                            final participants = snapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              // Consider participant active if removed is null or false
                              return data['removed'] != true;
                            }).toList();

                            return Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Participants',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${participants.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: participants.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.groups_outlined,
                                                size: 48,
                                                color: Colors.grey[400],
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Waiting for participants...',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: participants.length,
                                          separatorBuilder: (context, index) =>
                                              Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final participant =
                                                participants[index].data()
                                                    as Map<String, dynamic>;
                                            final participantId =
                                                participants[index].id;
                                            final hasAnswered =
                                                participant['answeredCurrentQuestion'] ??
                                                    false;

                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.transparent,
                                                child: participant['avatarUrl'] != null
                                                    ? Image.network(
                                                        participant['avatarUrl'],
                                                        width: 40,
                                                        height: 40,
                                                        errorBuilder: (context, error, stackTrace) => Icon(
                                                          Icons.person,
                                                          color: Colors.grey,
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.person,
                                                        color: Colors.grey,
                                                      ),
                                              ),
                                              title: Text(
                                                participant['name'] ?? 'Anonymous',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              subtitle: hasAnswered 
                                                ? Text(
                                                    'Answered',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  )
                                                : null,
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'Score: ${participant['score'] ?? 0}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.remove_circle_outline,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () async {
                                                      final confirm =
                                                          await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title:
                                                              Text('Remove Participant'),
                                                          content: Text(
                                                              'Remove ${participant['name']}?'),
                                                          actions: [
                                                            TextButton(
                                                              child: Text('Cancel'),
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context, false),
                                                            ),
                                                            TextButton(
                                                              child: Text('Remove'),
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context, true),
                                                              style: TextButton.styleFrom(
                                                                  foregroundColor:
                                                                      Colors.red),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                      if (confirm == true) {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection('sessions')
                                                            .doc(widget.sessionId)
                                                            .collection(
                                                                'participants')
                                                            .doc(participantId)
                                                            .update({
                                                          'removed': true,
                                                          'removedAt': FieldValue
                                                              .serverTimestamp(),
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Right panel - Quiz content
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    child: !isActive
                        ? Center(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('sessions')
                                  .doc(widget.sessionId)
                                  .collection('participants')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Center(child: CircularProgressIndicator());
                                }

                                final participantCount = snapshot.data!.docs.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  // Consider participant active if removed is null or false
                                  return data['removed'] != true;
                                }).length;
                                
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      participantCount > 0 ? Icons.groups : Icons.play_circle_outline,
                                      size: 64,
                                      color: participantCount > 0 ? Colors.green : Colors.blue,
                                    ),
                                    SizedBox(height: 24),
                                    Text(
                                      participantCount > 0 
                                          ? 'Ready to Begin' 
                                          : 'Waiting for Participants',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      participantCount > 0
                                          ? '$participantCount ${participantCount == 1 ? 'participant has' : 'participants have'} joined'
                                          : 'Share the QR code or session code with participants',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 32),
                                    ElevatedButton.icon(
                                      icon: Icon(Icons.play_arrow),
                                      label: Text('START SESSION'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: participantCount > 0 ? Colors.green : Colors.grey,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        textStyle: TextStyle(fontSize: 18),
                                      ),
                                      onPressed: participantCount > 0 ? _toggleSession : null,
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('quizzes')
                                .doc(widget.quizId)
                                .snapshots(),
                            builder: (context, quizSnapshot) {
                              if (!quizSnapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }

                              final quizData = quizSnapshot.data!.data()
                                  as Map<String, dynamic>;
                              final questions = List<Map<String, dynamic>>.from(
                                  quizData['questions'] ?? []);

                              if (currentQuestionIndex >= questions.length) {
                                return Center(
                                  child: Text('Quiz completed!'),
                                );
                              }

                              // Check if showing transition
                              final showingTransition = sessionData['showingTransition'] ?? false;
                              if (showingTransition) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 64,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(height: 24),
                                      Text(
                                        'Next Question',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Question ${currentQuestionIndex + 2}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 32),
                                      CircularProgressIndicator(),
                                    ],
                                  ),
                                );
                              }

                              final currentQuestion = questions[currentQuestionIndex];
                              final options =
                                  List<String>.from(currentQuestion['options'] ?? []);
                              final correctOptionIndex =
                                  currentQuestion['correctOptionIndex'] ?? 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Question ${currentQuestionIndex + 1}/${questions.length}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.timer,
                                                color: Colors.blue.shade700),
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
                                  SizedBox(height: 32),
                                  Text(
                                    currentQuestion['text'] ?? '',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('sessions')
                                        .doc(widget.sessionId)
                                        .collection('participants')
                                        .where('removed', isEqualTo: false)
                                        .snapshots(),
                                    builder: (context, participantsSnapshot) {
                                      if (!participantsSnapshot.hasData) {
                                        return SizedBox();
                                      }

                                      final participants = participantsSnapshot.data!.docs;
                                      final answeredCount = participants
                                          .where((doc) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            return data['answeredCurrentQuestion'] == true;
                                          })
                                          .length;

                                      return Container(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            Text(
                                              '$answeredCount/${participants.length} participants answered',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            answeredCount > 0
                                                ? Icon(Icons.check_circle, color: Colors.green, size: 16)
                                                : SizedBox(),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final isCorrect =
                                            index == correctOptionIndex;

                                        return Container(
                                          margin: EdgeInsets.only(bottom: 16),
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isCorrect
                                                ? Colors.green.shade50
                                                : Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isCorrect
                                                  ? Colors.green.shade200
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: isCorrect
                                                      ? Colors.green.shade100
                                                      : Colors.grey.shade200,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  String.fromCharCode(65 + index),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCorrect
                                                        ? Colors.green.shade700
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              Expanded(
                                                child: Text(
                                                  options[index],
                                                  style: TextStyle(fontSize: 16),
                                                ),
                                              ),
                                              if (isCorrect)
                                                Icon(Icons.check_circle,
                                                    color: Colors.green),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 