import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/quiz_model.dart';
import '../../utils/app_background.dart';

class EditQuizScreen extends StatefulWidget {
  final String quizId;
  
  const EditQuizScreen({Key? key, required this.quizId}) : super(key: key);
  
  @override
  _EditQuizScreenState createState() => _EditQuizScreenState();
}

class _EditQuizScreenState extends State<EditQuizScreen> {
  final TextEditingController titleController = TextEditingController();
  List<Question> questions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }
  
  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .get();
          
      if (!docSnapshot.exists) {
        setState(() {
          _errorMessage = 'Quiz not found';
          _isLoading = false;
        });
        return;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      
      titleController.text = data['title'] ?? '';
      
      // Load questions
      final questionsData = data['questions'] as List<dynamic>? ?? [];
      List<Question> loadedQuestions = [];
      
      for (var q in questionsData) {
        final questionData = q as Map<String, dynamic>;
        loadedQuestions.add(Question(
          text: questionData['text'] ?? '',
          options: List<String>.from(questionData['options'] ?? []),
          correctOptionIndex: questionData['correctOptionIndex'] ?? 0,
        ));
      }
      
      setState(() {
        questions = loadedQuestions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading quiz: $e');
      setState(() {
        _errorMessage = 'Error loading quiz: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBackground.buildAppBar(title: 'Edit Quiz'),
        body: AppBackground.buildBackground(
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBackground.buildAppBar(title: 'Edit Quiz'),
        body: AppBackground.buildBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(_errorMessage!, 
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                        ),
                        child: Text('Go Back'),
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
    
    return Scaffold(
      backgroundColor: AppBackground.backgroundColor,
      appBar: AppBackground.buildAppBar(
        title: 'Edit Quiz',
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: AppBackground.buildBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz title
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quiz Title', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // Questions list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Questions', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text('Total: ${questions.length}', 
                      style: TextStyle(color: Colors.black)),
                ],
              ),
              SizedBox(height: 10),
              
              if (questions.isEmpty)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 20),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.quiz_outlined, size: 48, color: Colors.blue.shade300),
                        SizedBox(height: 8),
                        Text(
                          'No questions added yet',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              ...questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                
                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Question ${index+1}: ${question.text}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _editQuestion(index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _deleteQuestion(index),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ...question.options.asMap().entries.map((optEntry) {
                          final optIndex = optEntry.key;
                          final option = optEntry.value;
                          final isCorrect = optIndex == question.correctOptionIndex;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.circle_outlined,
                                  color: isCorrect ? Colors.green : Colors.grey,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(option),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.add, color: Colors.white),
                label: Text('Add Question', style: TextStyle(color: Colors.white)),
                
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  
                  backgroundColor: AppBackground.primaryColor,
                ),
                onPressed: _addQuestion,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _addQuestion() async {
    final result = await _showQuestionDialog();
    if (result != null) {
      setState(() {
        questions.add(result);
      });
    }
  }
  
  void _editQuestion(int index) async {
    final result = await _showQuestionDialog(questions[index]);
    if (result != null) {
      setState(() {
        questions[index] = result;
        _isSaving = true;
      });

      try {
        // Convert questions to a format that Firestore can store
        List<Map<String, dynamic>> questionsData = questions.map((q) => {
          'text': q.text,
          'options': q.options,
          'correctOptionIndex': q.correctOptionIndex,
        }).toList();
        
        // Update quiz document
        await FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId).update({
          'questions': questionsData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Text('Question updated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Error updating question: $e');
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Error updating question: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }
  
  void _deleteQuestion(int index) async {
    setState(() {
      questions.removeAt(index);
    });

    try {
      // Update the quiz document in Firestore
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .update({
        'questions': questions.map((q) => q.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting question: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting question: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<Question?> _showQuestionDialog([Question? existingQuestion]) async {
    final TextEditingController questionController = TextEditingController();
    final List<TextEditingController> optionControllers = List.generate(
      4, (_) => TextEditingController()
    );
    int selectedOptionIndex = 0;
    
    // Pre-fill with existing question data if editing
    if (existingQuestion != null) {
      questionController.text = existingQuestion.text;
      for (int i = 0; i < existingQuestion.options.length && i < 4; i++) {
        optionControllers[i].text = existingQuestion.options[i];
      }
      selectedOptionIndex = existingQuestion.correctOptionIndex;
    }
    
    return showDialog<Question?>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 16,
              titlePadding: EdgeInsets.fromLTRB(32, 32, 32, 0),
              contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 0),
              actionsPadding: EdgeInsets.fromLTRB(24, 16, 24, 24),
              title: Text(
                existingQuestion == null ? 'Add Question' : 'Edit Question',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Question Text', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800])),
                    SizedBox(height: 6),
                    TextField(
                      controller: questionController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      ),
                      maxLines: 2,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 18),
                    ...List.generate(4, (index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: selectedOptionIndex,
                              onChanged: (value) {
                                setState(() {
                                  selectedOptionIndex = value!;
                                });
                              },
                              activeColor: Colors.blue.shade700,
                            ),
                            Expanded(
                              child: TextField(
                                controller: optionControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Option ${index + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: index == selectedOptionIndex 
                                    ? Colors.green.shade50 
                                    : Colors.grey.shade50,
                                  suffixIcon: index == selectedOptionIndex
                                    ? Icon(Icons.check_circle, color: Colors.green)
                                    : null,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                ),
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 150),
                          
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (questionController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a question'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          bool hasEmptyOption = false;
                          List<String> options = [];
                          for (var controller in optionControllers) {
                            if (controller.text.isEmpty) {
                              hasEmptyOption = true;
                            }
                            options.add(controller.text);
                          }
                          if (hasEmptyOption) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all options'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (Navigator.of(context).canPop()) {
                            Question newQuestion = Question(
                              text: questionController.text,
                              options: options,
                              correctOptionIndex: selectedOptionIndex,
                            );
                            Navigator.of(context).pop(newQuestion);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<void> _saveQuiz() async {
    // Validate inputs
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a quiz title'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      // Convert questions to a format that Firestore can store
      List<Map<String, dynamic>> questionsData = questions.map((q) => {
        'text': q.text,
        'options': q.options,
        'correctOptionIndex': q.correctOptionIndex,
      }).toList();
      
      // Update quiz document
      await FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId).update({
        'title': titleController.text,
        'questions': questionsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 16),
              Text('Quiz updated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      print('Error updating quiz: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 16),
              Expanded(
                child: Text('Error updating quiz: $e'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}