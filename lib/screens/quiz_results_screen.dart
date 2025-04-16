import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizResultsScreen extends StatelessWidget {
  final int finalScore;
  final int totalQuestions;

  QuizResultsScreen({required this.finalScore, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quiz Results')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Quiz Completed!', style: TextStyle(fontSize: 24)),
            Text('Your Final Score: $finalScore/$totalQuestions', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            Text('Leaderboard:'),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .doc('yourSessionId')  // Replace with actual sessionId
                  .collection('participants')
                  .orderBy('score', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }

                var leaderboard = snapshot.data!.docs;
                return Column(
                  children: leaderboard.map((doc) {
                    return ListTile(
                      title: Text(doc['name']),
                      subtitle: Text('Score: ${doc['score']}'),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
