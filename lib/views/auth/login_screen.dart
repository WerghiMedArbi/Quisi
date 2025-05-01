import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../utils/app_background.dart';
import '../../controllers/auth/login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginController(
        Provider.of(context, listen: false),
      ),
      child: const _LoginScreenContent(),
    );
  }
}

class _LoginScreenContent extends StatelessWidget {
  const _LoginScreenContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LoginController>();
    
    return Scaffold(
      body: AppBackground.buildBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.1,
                  vertical: 24,
                ),
                child: Card(
                  color: AppBackground.backgroundColor,
                  elevation: 18,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.05,
                      vertical: 50,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 500,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // QUISI Logo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "QU",
                                style: GoogleFonts.montserrat(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                "ISI",
                                style: GoogleFonts.montserrat(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: AppBackground.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            controller.isRegister ? "Create Your Account" : "Welcome Back",
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Form fields
                          if (controller.isRegister) ...[
                            TextField(
                              controller: controller.firstNameController,
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                border: OutlineInputBorder(),
                                fillColor: AppBackground.backgroundColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: controller.lastNameController,
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                border: OutlineInputBorder(),
                                fillColor: AppBackground.backgroundColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: controller.emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              fillColor: AppBackground.backgroundColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller.passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              fillColor: AppBackground.backgroundColor,
                            ),
                          ),
                          
                          if (controller.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Text(
                                  controller.errorMessage!,
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Primary button
                          if (controller.isLoading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton(
                              onPressed: controller.isRegister 
                                ? () => controller.signUp(context)
                                : () => controller.login(context),
                              child: Text(
                                controller.isRegister ? "SIGN UP" : "LOGIN",
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppBackground.primaryColor,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Toggle between login and register
                          TextButton(
                            onPressed: controller.toggleRegister,
                            child: Text(
                              controller.isRegister 
                                ? "Already have an account? Login" 
                                : "Don't have an account? Register now",
                              style: TextStyle(color: AppBackground.primaryColor),
                            ),
                          ),
                          
                          const Divider(height: 32),
                          
                          // Alternative sign-in methods text
                          Text(
                            "Or continue with",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          
                          // Google sign in button
                          ElevatedButton.icon(
                            onPressed: () => controller.signInWithGoogle(context),
                            icon: FaIcon(FontAwesomeIcons.google, 
                              color: AppBackground.primaryColor, 
                              size: 18
                            ),
                            label: Text(
                              "Google",
                              style: TextStyle(color: AppBackground.primaryColor),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppBackground.backgroundColor,
                              minimumSize: const Size(double.infinity, 50),
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
      ),
    );
  }
}