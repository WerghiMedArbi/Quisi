import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class LoginController extends ChangeNotifier {
  final AuthService _authService;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isRegister = false;
  String? _errorMessage;

  LoginController(this._authService);

  bool get isLoading => _isLoading;
  bool get isRegister => _isRegister;
  String? get errorMessage => _errorMessage;

  void toggleRegister() {
    _isRegister = !_isRegister;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> login(BuildContext context) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await _authService.signInWithEmail(
        emailController.text,
        passwordController.text,
      );
      
      if (user != null && context.mounted) {
        context.go('/admin');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> signUp(BuildContext context) async {
    if (firstNameController.text.isEmpty || lastNameController.text.isEmpty) {
      _setError("Please enter your first and last name");
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await _authService.signUpWithEmail(
        emailController.text,
        passwordController.text,
        firstName: firstNameController.text,
        lastName: lastNameController.text,
      );
      
      if (user != null && context.mounted) {
        context.go('/admin');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && context.mounted) {
        context.go('/admin');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }
} 