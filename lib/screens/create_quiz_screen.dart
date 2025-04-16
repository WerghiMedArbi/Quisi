import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz_model.dart';
import '../utils/app_background.dart';

class CreateQuizScreen extends StatefulWidget {
  @override
  _CreateQuizScreenState createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final TextEditingController titleController = TextEditingController();
  List<Question> questions = [];
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Create Quiz",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save_rounded),
                  tooltip: 'Save Quiz',
                  onPressed: _saveQuiz,
                ),
        ],
      ),
      body: AppBackground.buildBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz title
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quiz Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Quiz Title',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Questions header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Questions',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${questions.length} total',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Empty state
              if (questions.isEmpty)
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 64,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to add your first question',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Questions list
              ...questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question header
                        Container(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  question.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Question',
                                onPressed: () => _editQuestion(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete Question',
                                color: Colors.red[400],
                                onPressed: () => _deleteQuestion(index),
                              ),
                            ],
                          ),
                        ),
                        // Options
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: question.options.asMap().entries.map((optEntry) {
                              final optIndex = optEntry.key;
                              final option = optEntry.value;
                              final isCorrect = optIndex == question.correctOptionIndex;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? Colors.green[50]
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCorrect
                                        ? Colors.green[300]!
                                        : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCorrect
                                            ? Colors.green[100]
                                            : Colors.grey[200],
                                      ),
                                      child: Center(
                                        child: Text(
                                          String.fromCharCode(65 + optIndex), // A, B, C, D
                                          style: TextStyle(
                                            color: isCorrect
                                                ? Colors.green[800]
                                                : Colors.grey[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          color: isCorrect
                                              ? Colors.green[800]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    if (isCorrect)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green[600],
                                        size: 20,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              // Add Question Button
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('ADD NEW QUESTION'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _addQuestion,
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: questions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _saveQuiz,
              icon: const Icon(Icons.save_rounded),
              label: const Text('SAVE QUIZ'),
              elevation: 4,
            )
          : null,
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
      });
    }
  }
  
  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                questions.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existingQuestion == null ? 'Add New Question' : 'Edit Question',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question Text',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: questionController,
                      decoration: InputDecoration(
                        hintText: 'Enter your question here',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Answer Options',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select the correct answer with the radio button',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(4, (index) {
                      final optionLabel = String.fromCharCode(65 + index); // A, B, C, D
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: index == selectedOptionIndex
                              ? Colors.green[50]
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index == selectedOptionIndex
                                ? Colors.green[300]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: selectedOptionIndex,
                              activeColor: Colors.green[700],
                              onChanged: (value) {
                                setState(() {
                                  selectedOptionIndex = value!;
                                });
                              },
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == selectedOptionIndex
                                    ? Colors.green[100]
                                    : Colors.grey[200],
                              ),
                              child: Center(
                                child: Text(
                                  optionLabel,
                                  style: TextStyle(
                                    color: index == selectedOptionIndex
                                        ? Colors.green[800]
                                        : Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: TextField(
                                  controller: optionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Option $optionLabel',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate inputs
                    if (questionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a question')),
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
                        const SnackBar(content: Text('Please fill all options')),
                      );
                      return;
                    }
                    
                    // Create question object
                    Question newQuestion = Question(
                      text: questionController.text,
                      options: options,
                      correctOptionIndex: selectedOptionIndex,
                    );
                    
                    Navigator.pop(context, newQuestion);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('SAVE'),
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
        ),
      );
      return;
    }
    
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question'),
          behavior: SnackBarBehavior.floating,
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
      
      // Create quiz document
      await FirebaseFirestore.instance.collection('quizzes').add({
        'title': titleController.text,
        'questions': questionsData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 16),
              Text('Quiz saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving quiz: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}