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
              .where('removed', isEqualTo: false)
              .orderBy('score', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final participants = snapshot.data!.docs;
            
            // Calculate statistics
            int highestScore = 0;
            double averageScore = 0;
            
            if (participants.isNotEmpty) {
              highestScore = (participants.first.data() as Map<String, dynamic>)['score'] ?? 0;
              averageScore = participants
                  .map<int>((doc) => (doc.data() as Map<String, dynamic>)['score'] ?? 0)
                  .reduce((a, b) => a + b) / participants.length;
            }
            
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
                          SizedBox(height: 24),
                          // Statistics row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatCard(
                                'Highest Score',
                                '$highestScore',
                                Icons.star,
                                Colors.amber,
                              ),
                              _buildStatCard(
                                'Average Score',
                                '${averageScore.round()}',
                                Icons.analytics,
                                Colors.blue,
                              ),
                              _buildStatCard(
                                'Participants',
                                '${participants.length}',
                                Icons.groups,
                                Colors.green,
                              ),
                            ],
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
                              final score = participant['score'] ?? 0;
                              final percentage = highestScore > 0 
                                  ? (score / highestScore * 100).round() 
                                  : 0;
                              
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
                                    _buildRankBadge(index),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            participant['name'] ?? 'Anonymous',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: percentage / 100,
                                              backgroundColor: Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isTop3 ? Colors.blue : Colors.grey,
                                              ),
                                              minHeight: 8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      '$score pts',
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int index) {
    final isTop3 = index < 3;
    final colors = [
      Colors.amber, // Gold
      Colors.grey.shade400, // Silver
      Colors.brown.shade300, // Bronze
    ];
    
    if (isTop3) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colors[index].withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.emoji_events,
          color: colors[index],
          size: 20,
        ),
      );
    }
    
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
