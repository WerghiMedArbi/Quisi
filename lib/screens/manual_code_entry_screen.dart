import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data'; // Add this import for Uint8List
import '../utils/app_background.dart';

class ManualCodeEntryScreen extends StatefulWidget {
  @override
  _ManualCodeEntryScreenState createState() => _ManualCodeEntryScreenState();
}

class _ManualCodeEntryScreenState extends State<ManualCodeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackground.buildAppBar(title: "Enter Session Code"),
      body: AppBackground.buildBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Enter the session code to join",
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 24.0),
                          TextFormField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'Session Code',
                              hintText: 'Enter the code provided by your teacher',
                              prefixIcon: Icon(Icons.pin),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the session code';
                              }
                              return null;
                            },
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20.0,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 24.0),
                          ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                context.go('/nickname-entry/${_codeController.text}');
                              }
                            },
                            style: AppBackground.secondaryButtonStyle(),
                            child: const Text(
                              'JOIN SESSION',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add this method to handle image loading with fallback
  ImageProvider _buildBackgroundImage() {
    try {
      return AssetImage('assets/images/bg.png');
    } catch (e) {
      print('Failed to load background image: $e');
      // Return a transparent image as fallback
      return MemoryImage(Uint8List.fromList([0, 0, 0, 0]));
    }
  }
}