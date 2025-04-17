import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_background.dart';
import 'package:go_router/go_router.dart';

class QuizResultsScreen extends StatelessWidget {
  final String sessionId;
  final String quizTitle;

  const QuizResultsScreen({
    Key? key,
    required this.sessionId,
    required this.quizTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackground.buildAppBar(title: 'Quiz Results'),
      body: AppBackground.buildBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .doc(sessionId)
              .collection('participants')
              .orderBy('score', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final participants = snapshot.data!.docs;
            
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: AppBackground.cardDecoration(),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events, size: 64, color: Colors.amber),
                          SizedBox(height: 16),
                          Text(
                            'Quiz Complete!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            quizTitle,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 32),
                          Text(
                            'Final Standings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              final participant = participants[index].data() as Map<String, dynamic>;
                              final isTop3 = index < 3;
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isTop3 ? Colors.blue.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isTop3 ? Colors.blue.shade200 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isTop3 ? Colors.blue.shade100 : Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isTop3 ? Colors.blue.shade700 : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        participant['name'] ?? 'Anonymous',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Score: ${participant['score'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isTop3 ? Colors.blue.shade700 : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/admin'),
                      style: AppBackground.primaryButtonStyle(),
                      child: Text('Return to Dashboard'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
