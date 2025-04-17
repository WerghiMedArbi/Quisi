import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../utils/app_background.dart';
import '../utils/avatar_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import './quiz_results_screen.dart';
import './quiz_start_session_screen.dart';
import './edit_quiz_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  String _activeSessionId = '';
  bool _isCreatingSession = false;
  Timer? _questionTimer;
  final ValueNotifier<int> _timeRemaining = ValueNotifier<int>(10);
  final ValueNotifier<Map<String, dynamic>> _questionStats = ValueNotifier<Map<String, dynamic>>({});
  
  @override
  void initState() {
    super.initState();
    _cleanupAllSessions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeListeners();
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _timeRemaining.dispose();
    _questionStats.dispose();
    super.dispose();
  }

  void _initializeListeners() {
    if (_activeSessionId.isEmpty) return;
    
    // Listen to participant updates in a separate isolate
    FirebaseFirestore.instance
        .collection('sessions')
        .doc(_activeSessionId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      final stats = {
        'totalParticipants': snapshot.docs.length,
        'answeredCount': snapshot.docs.where((doc) {
          final data = doc.data();
          return data['answeredCurrentQuestion'] ?? false;
        }).length,
      };
      
      _questionStats.value = stats;
    });
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _timeRemaining.value = 10;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timeRemaining.value > 0) {
        _timeRemaining.value--;
      } else {
        timer.cancel();
        _moveToNextQuestion();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBackground.buildAppBar(
        title: 'Your Quiz Library',
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: Icon(Icons.logout, color: AppBackground.primaryColor),
            label: Text(
              'Logout',
              style: TextStyle(
                color: AppBackground.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: AppBackground.buildBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('quizzes').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 80,
                      color: AppBackground.primaryColor.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No quizzes available',
                      style: AppBackground.headingStyle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first quiz to get started',
                      style: AppBackground.subheadingStyle(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Quiz'),
                      style: AppBackground.primaryButtonStyle(),
                      onPressed: () => context.push('/create-quiz'),
                    ),
                  ],
                ),
              );
            }
            
            final quizzes = snapshot.data!.docs;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Quiz Library',
                        style: AppBackground.headingStyle(),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create and manage your interactive quizzes',
                        style: AppBackground.subheadingStyle(),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _buildQuizzesList(quizzes, isSmallScreen),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('CREATE NEW QUIZ'),
                    style: AppBackground.primaryButtonStyle(),
                    onPressed: () => context.push('/create-quiz'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildQuizzesList(List<QueryDocumentSnapshot> quizzes, bool isSmallScreen) {
    return GridView.builder(
      padding: EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 1 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 24,
        mainAxisExtent: 120,
      ),
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        final quizData = quiz.data() as Map<String, dynamic>;
        final questionCount = (quizData['questions'] as List?)?.length ?? 0;
        
        return Container(
          decoration: AppBackground.cardDecoration(),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppBackground.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.quiz,
                    color: AppBackground.primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        quizData['title'] ?? 'Untitled Quiz',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$questionCount ${questionCount == 1 ? 'question' : 'questions'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        context.go('/edit/${quiz.id}');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppBackground.primaryColor,
                        side: BorderSide(color: AppBackground.primaryColor),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size(60, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('EDIT', style: TextStyle(fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isCreatingSession 
                        ? null 
                        : () => _createSession(quiz.id, quizData['title']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppBackground.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size(60, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('START', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _cleanupAllSessions() async {
    if (_activeSessionId.isEmpty) return;
    
    try {
      // Get the current session
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId);
      
      // Get and delete all participants
      final participantsQuery = await sessionRef
          .collection('participants')
          .get();
          
      // Create a batch operation
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete all participants
      for (var participantDoc in participantsQuery.docs) {
        batch.delete(participantDoc.reference);
      }
      
      // Delete the session
      batch.delete(sessionRef);
      
      // Execute the batch
      await batch.commit();
      
      setState(() {
        _activeSessionId = '';
      });
      
    } catch (e) {
      print('Error cleaning up session: $e');
      // Silently fail - we don't want to bother the user with cleanup errors
    }
  }
  
  Future<void> _createSession(String quizId, String quizTitle) async {
    setState(() => _isCreatingSession = true);
    
    try {
      // Create new session
      final sessionRef = FirebaseFirestore.instance.collection('sessions').doc();
      
      await sessionRef.set({
        'quizId': quizId,
        'quizTitle': quizTitle,
        'active': false,
        'completed': false,
        'currentQuestionIndex': 0,
        'everyoneAnswered': false,
        'startedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'sessionEnded': false,
      });

      if (mounted) {
        // Use context.go to update the URL and navigate
        context.go('/session/${sessionRef.id}', extra: {
          'quizId': quizId,
          'quizTitle': quizTitle,
        });
      }
      
    } catch (e) {
      print('Error creating session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCreatingSession = false);
    }
  }

  Widget _buildActiveSession() {
    if (_activeSessionId.isEmpty) {
      return Center(
        child: Text(
          'No active session',
          style: AppBackground.headingStyle(),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final sessionData = snapshot.data!.data() as Map<String, dynamic>;
        final isActive = sessionData['active'] ?? false;
        final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;

        return Column(
          children: [
            if (!isActive)
              // Show QR code and session info before starting
              _buildSessionSetup(sessionData)
            else
              // Show quiz interface after starting
              _buildQuizInterface(sessionData, currentQuestionIndex),
            
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
                    label: Text(isActive ? 'END SESSION' : 'START SESSION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive 
                          ? AppBackground.dangerButtonColor
                          : AppBackground.successButtonColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      minimumSize: Size(160, 48),
                    ),
                    onPressed: () => _toggleSession(isActive),
                  ),
                ),
                if (!isActive) ...[
                  SizedBox(width: 16),
                  SizedBox(
                    width: 140,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.close),
                      label: Text('CLOSE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        minimumSize: Size(120, 48),
                      ),
                      onPressed: () {
                        _questionTimer?.cancel();
                        setState(() => _activeSessionId = '');
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionSetup(Map<String, dynamic> sessionData) {
    return Container(
      constraints: BoxConstraints(maxWidth: 800),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_activeSessionId.isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: EdgeInsets.all(24),
                        child: QrImageView(
                          data: _activeSessionId,
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Session Code',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              _activeSessionId,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(width: 12),
                            IconButton(
                              icon: Icon(Icons.copy, color: Colors.blue.shade700),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _activeSessionId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Session code copied')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 32),
                    Container(
                      constraints: BoxConstraints(maxHeight: 400),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: _buildParticipantsList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizInterface(Map<String, dynamic> sessionData, int currentQuestionIndex) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('quizzes')
          .doc(sessionData['quizId'])
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final quizData = snapshot.data!.data() as Map<String, dynamic>;
        final questions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);
        
        if (currentQuestionIndex >= questions.length) {
          return _buildResultsScreen(sessionData);
        }

        final currentQuestion = questions[currentQuestionIndex];
        
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuestionHeader(currentQuestionIndex, questions.length),
                const SizedBox(height: 24),
                Text(
                  currentQuestion['text'] ?? '',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                _buildAnswerStats(currentQuestion),
                const SizedBox(height: 16),
                _buildParticipantsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsScreen(Map<String, dynamic> sessionData) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => QuizResultsScreen(
          sessionId: _activeSessionId,
          quizTitle: sessionData['quizTitle'] ?? 'Quiz Results',
        ),
      ),
    );
  }

  Widget _buildQuestionHeader(int currentIndex, int totalQuestions) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Question ${currentIndex + 1}/$totalQuestions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppBackground.primaryColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppBackground.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, color: AppBackground.primaryColor),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: _timeRemaining,
                builder: (context, timeValue, _) {
                  return Text(
                    '$timeValue s',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppBackground.primaryColor,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerStats(Map<String, dynamic> question) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: _questionStats,
      builder: (context, stats, _) {
        final totalParticipants = stats['totalParticipants'] ?? 0;
        final answeredCount = stats['answeredCount'] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responses: $answeredCount/$totalParticipants',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            ..._buildOptionsList(question),
          ],
        );
      },
    );
  }

  List<Widget> _buildOptionsList(Map<String, dynamic> question) {
    final options = List<String>.from(question['options'] ?? []);
    final correctOptionIndex = question['correctOptionIndex'] ?? 0;

    return options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isCorrect = index == correctOptionIndex;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isCorrect ? Colors.green.shade200 : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              '${String.fromCharCode(65 + index)}.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(option),
            ),
            if (isCorrect)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildParticipantsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId)
          .collection('participants')
          .where('removed', isEqualTo: false)
          .snapshots(),
      builder: (context, participantsSnapshot) {
        if (!participantsSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final participants = participantsSnapshot.data!.docs;
        
        if (participants.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'Waiting for participants to join...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

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
                      color: Colors.grey[800],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8),
                itemCount: participants.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final participant = participants[index].data() as Map<String, dynamic>;
                  final participantId = participants[index].id;
                  final nickname = participant['name'] ?? 'Anonymous';
                  final hasAnswered = participant['answeredCurrentQuestion'] ?? false;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: hasAnswered ? Colors.green.shade100 : Colors.grey.shade100,
                      child: Icon(
                        hasAnswered ? Icons.check : Icons.hourglass_empty,
                        color: hasAnswered ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text(
                      nickname,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Score: ${participant['score'] ?? 0}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeParticipant(participantId, nickname),
                          tooltip: 'Remove participant',
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
    );
  }

  Future<void> _toggleSession(bool currentlyActive) async {
    try {
      if (!currentlyActive) {
        // Check if there are any participants
        final participantsSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_activeSessionId)
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
        
        // Starting session
        _startQuestionTimer();
        
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_activeSessionId)
            .update({
          'active': true,
          'sessionEnded': false,
          'startedAt': FieldValue.serverTimestamp(),
          'questionStartTime': FieldValue.serverTimestamp(),
        });
      } else {
        // Ending session
        _questionTimer?.cancel();
        
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_activeSessionId)
            .update({
          'active': false,
          'sessionEnded': true,
          'sessionEndedAt': FieldValue.serverTimestamp(),
        });

        // Clean up participants
        final participantsSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_activeSessionId)
            .collection('participants')
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in participantsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        
        // Clean up the session and reset state
        await _cleanupAllSessions();
        
        // Navigate back to admin dashboard
        if (mounted) {
          context.go('/admin');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyActive ? 'Session ended' : 'Session started'),
          backgroundColor: currentlyActive 
              ? AppBackground.dangerButtonColor 
              : AppBackground.successButtonColor,
        ),
      );
    } catch (e) {
      print('Error toggling session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating session: $e'),
          backgroundColor: AppBackground.dangerButtonColor,
        ),
      );
    }
  }

  Future<void> _moveToNextQuestion() async {
    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId);
      
      // Get current session data
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) return;
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final currentQuestionIndex = sessionData['currentQuestionIndex'] ?? 0;
      
      // Get quiz data to check total questions
      final quizDoc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(sessionData['quizId'])
          .get();
          
      if (!quizDoc.exists) return;
      
      final quizData = quizDoc.data() as Map<String, dynamic>;
      final questions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);
      
      if (currentQuestionIndex >= questions.length - 1) {
        // End session if this was the last question
        await sessionRef.update({
          'completed': true,
          'active': false,
          'sessionEnded': true,
          'sessionEndedAt': FieldValue.serverTimestamp(),
        });
        _questionTimer?.cancel();
        return;
      }

      // First update to show transition message
      await sessionRef.update({
        'showingTransition': true,
        'transitionStartTime': FieldValue.serverTimestamp(),
      });
      
      // Wait 5 seconds
      await Future.delayed(Duration(seconds: 5));
      
      // Then move to next question
      await sessionRef.update({
        'currentQuestionIndex': currentQuestionIndex + 1,
        'questionStartTime': FieldValue.serverTimestamp(),
        'everyoneAnswered': false,
        'showingTransition': false,
      });
      
      // Reset participant states
      final batch = FirebaseFirestore.instance.batch();
      final participantsSnapshot = await sessionRef
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
      
      // Restart timer
      _startQuestionTimer();
      
    } catch (e) {
      print('Error moving to next question: $e');
    }
  }

  Future<void> _removeParticipant(String participantId, String participantName) async {
    try {
      // Show confirmation dialog
      final shouldRemove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove Participant'),
          content: Text('Are you sure you want to remove $participantName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('REMOVE'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      );

      if (shouldRemove != true) return;

      // Update participant document instead of deleting it
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId)
          .collection('participants')
          .doc(participantId)
          .update({
        'removed': true,
        'removedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $participantName from session'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error removing participant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing participant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}