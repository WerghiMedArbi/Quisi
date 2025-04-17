import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../models/quiz_model.dart';
import '../utils/app_background.dart';

class CreateQuizScreen extends StatefulWidget {
  @override
  _CreateQuizScreenState createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = false;

  Future<String> _getNextQuizId() async {
    try {
      // Get all existing quizzes
      final querySnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('id', isGreaterThan: 'quizId')
          .orderBy('id', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'quizId1';
      }

      // Extract the number from the last quiz ID
      final lastId = querySnapshot.docs.first.data()['id'] as String;
      final lastNumber = int.parse(lastId.replaceAll('quizId', ''));
      return 'quizId${lastNumber + 1}';
    } catch (e) {
      print('Error getting next quiz ID: $e');
      return 'quizId1';
    }
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newQuizId = await _getNextQuizId();
      
      // Create the quiz document
      final quizRef = FirebaseFirestore.instance.collection('quizzes').doc();
      await quizRef.set({
        'id': newQuizId,
        'title': _titleController.text,
        'questions': _questions,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/admin');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quiz created successfully')),
        );
      }
    } catch (e) {
      print('Error saving quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating quiz: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'title': 'Question ${_questions.length + 1}',
        'text': '',
        'options': ['', '', '', ''],
        'correctOptionIndex': 0,
      });
    });
  }

  void _updateQuestion(int index, Map<String, dynamic> question) {
    setState(() {
      _questions[index] = question;
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      // Update question titles
      for (var i = 0; i < _questions.length; i++) {
        _questions[i]['title'] = 'Question ${i + 1}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackground.buildAppBar(
        title: 'Create Quiz',
      ),
      body: AppBackground.buildBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Quiz Title',
                          border: OutlineInputBorder(),
                          ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      ..._questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        return _buildQuestionCard(index, question);
                      }),
                      SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _addQuestion,
                          icon: Icon(Icons.add),
                          label: Text('ADD QUESTION'),
                          style: AppBackground.primaryButtonStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveQuiz,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('CREATE QUIZ'),
                style: AppBackground.primaryButtonStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _removeQuestion(index),
                  color: Colors.red,
          ),
        ],
      ),
            SizedBox(height: 8),
            TextFormField(
              initialValue: question['text'] as String,
              decoration: InputDecoration(
                labelText: 'Question Text',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                question['text'] = value;
                _updateQuestion(index, question);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the question';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Text('Options:'),
            SizedBox(height: 8),
            ...(question['options'] as List).asMap().entries.map((entry) {
              final optionIndex = entry.key;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(
                      value: optionIndex,
                      groupValue: question['correctOptionIndex'] as int,
                      onChanged: (value) {
                        question['correctOptionIndex'] = value;
                        _updateQuestion(index, question);
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: entry.value as String,
                      decoration: InputDecoration(
                          labelText: 'Option ${optionIndex + 1}',
                          border: OutlineInputBorder(),
                        ),
                              onChanged: (value) {
                          (question['options'] as List)[optionIndex] = value;
                          _updateQuestion(index, question);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the option';
                          }
                          return null;
                        },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
    );
  }
}