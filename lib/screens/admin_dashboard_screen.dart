import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../utils/app_background.dart';
import '../utils/avatar_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  String _activeSessionId = '';
  bool _isCreatingSession = false;
  
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBackground.buildAppBar(
        title: _activeSessionId.isNotEmpty ? 'Active Session' : 'Your Quiz Library',
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
                        _activeSessionId.isNotEmpty ? 'Active Session' : 'Your Quiz Library',
                        style: AppBackground.headingStyle(),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _activeSessionId.isNotEmpty 
                          ? 'Share this code with your participants'
                          : 'Create and manage your interactive quizzes',
                        style: AppBackground.subheadingStyle(),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _activeSessionId.isEmpty
                      ? _buildQuizzesList(quizzes, isSmallScreen)
                      : _buildActiveSession(),
                ),
                
                if (_activeSessionId.isEmpty)
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
                        context.push('/edit-quiz', extra: quiz.id);
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
  
  Future<void> _createSession(String quizId, String quizTitle) async {
    setState(() => _isCreatingSession = true);
    
    try {
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
      });
      
      setState(() {
        _activeSessionId = sessionRef.id;
        _isCreatingSession = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 16),
              Text('Session created successfully!'),
            ],
          ),
          backgroundColor: AppBackground.successButtonColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating session: $e'),
          backgroundColor: AppBackground.dangerButtonColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
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

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: AppBackground.cardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_activeSessionId.isNotEmpty) QrImageView(
                      data: _activeSessionId,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Session Code',
                      style: AppBackground.subheadingStyle(),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(
                          _activeSessionId,
                          style: AppBackground.headingStyle(),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _activeSessionId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Session code copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .doc(_activeSessionId)
                          .collection('participants')
                          .snapshots(),
                      builder: (context, participantsSnapshot) {
                        if (!participantsSnapshot.hasData) {
                          return CircularProgressIndicator();
                        }

                        final participants = participantsSnapshot.data!.docs;
                        
                        if (participants.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Waiting for participants to join...',
                              style: AppBackground.subheadingStyle().copyWith(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Text(
                              'Participants (${participants.length})',
                              style: AppBackground.subheadingStyle(),
                            ),
                            SizedBox(height: 16),
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: 200,
                                maxWidth: 300,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.all(8),
                                itemCount: participants.length,
                                itemBuilder: (context, index) {
                                  final participant = participants[index].data() as Map<String, dynamic>;
                                  final nickname = participant['name'] ?? 'Anonymous';
                                  final avatarStyle = participant['avatarStyle'];
                                  final avatarSeed = participant['avatarSeed'];
                                  final avatarBgColorHex = participant['avatarBgColor'];
                                  
                                  Color backgroundColor = Colors.blue.shade100;
                                  try {
                                    if (avatarBgColorHex != null) {
                                      backgroundColor = Color(int.parse('0xFF${avatarBgColorHex.substring(1)}'));
                                    }
                                  } catch (e) {
                                    // Use default color if parsing fails
                                  }

                                  return ListTile(
                                    leading: AvatarProvider.buildCachedAvatar(
                                      imageUrl: '',  // Empty string as we're using seed-based avatars
                                      seed: avatarSeed,
                                      style: avatarStyle,
                                      backgroundColor: backgroundColor,
                                      fallbackText: nickname[0].toUpperCase(),
                                      width: 40,
                                      height: 40,
                                    ),
                                    title: Text(
                                      nickname,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
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
                        setState(() => _activeSessionId = '');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSession(bool currentlyActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId)
          .update({
        'active': !currentlyActive,
        'startedAt': !currentlyActive ? FieldValue.serverTimestamp() : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyActive ? 'Session ended' : 'Session started'),
          backgroundColor: currentlyActive 
              ? AppBackground.dangerButtonColor 
              : AppBackground.successButtonColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating session: $e'),
          backgroundColor: AppBackground.dangerButtonColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}