import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../utils/app_background.dart';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRegister = false;

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var user = await _authService.signInWithEmail(
        emailController.text, 
        passwordController.text
      );
      
      if (user != null) {
        print("Login successful");
        // Explicitly navigate to admin dashboard
        if (mounted) {
          context.go('/admin');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print("Login failed: $e");
    }
  }

  void _signUp() async {
    if (firstNameController.text.isEmpty || lastNameController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your first and last name";
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var user = await _authService.signUpWithEmail(
        emailController.text, 
        passwordController.text,
        firstName: firstNameController.text,
        lastName: lastNameController.text,
      );
      
      if (user != null) {
        print("Signup successful");
        // Explicitly navigate to admin dashboard
        if (mounted) {
          context.go('/admin');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print("Signup failed: $e");
    }
  }

  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var user = await _authService.signInWithGoogle();
      if (user != null) {
        print("Google signin successful");
        // Explicitly navigate to admin dashboard
        if (mounted) {
          context.go('/admin');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print("Google signin failed: $e");
    }
  }

  void _toggleRegister() {
    setState(() {
      _isRegister = !_isRegister;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground.buildBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Text(
                          "QUISI",
                          style: GoogleFonts.montserrat(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3F51B5),
                          ),
                        ),
                        Text(
                          _isRegister ? "Create Your Account" : "Welcome Back",
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // Form fields
                        if (_isRegister) ...[
                          TextField(
                            controller: firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        
                        if (_errorMessage != null)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 24),
                        
                        // Primary button
                        if (_isLoading)
                          CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _isRegister ? _signUp : _login,
                            child: Text(
                              _isRegister ? "SIGN UP" : "LOGIN",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 16),
                        
                        // Toggle between login and register
                        TextButton(
                          onPressed: _toggleRegister,
                          child: Text(
                            _isRegister 
                              ? "Already have an account? Login" 
                              : "Don't have an account? Register now",
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ),
                        
                        Divider(height: 32),
                        
                        // Alternative sign-in methods text
                        Text(
                          "Or continue with",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 16),
                        
                        // Google sign in button
                        ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: FaIcon(FontAwesomeIcons.google, color: Colors.black87, size: 18),
                          label: Text(
                            "Google",
                            style: TextStyle(color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}