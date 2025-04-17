import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui; // Use this for web-based platform view handling.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async'; // Add this import for StreamSubscription
// Import screens
import 'screens/scan_qr_screen.dart';
import 'screens/manual_code_entry_screen.dart';
import 'screens/nickname_entry_screen.dart';
import 'screens/quiz_participation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/create_quiz_screen.dart';
import 'screens/edit_quiz_screen.dart';
import 'screens/quiz_start_session_screen.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'utils/app_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the FirebaseOptions (from firebase_options.dart).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    
    _router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: kIsWeb ? '/login' : '/scan',
      refreshListenable: GoRouterRefreshStream(_authService.user),
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = _authService.currentUser != null;
        final isAnonymous = _authService.isAnonymous;
        final isAdminRoute = state.matchedLocation.startsWith('/admin') || 
                            state.matchedLocation == '/login' ||
                            state.matchedLocation == '/create-quiz' ||
                            state.matchedLocation.startsWith('/edit/') ||
                            state.matchedLocation.startsWith('/session/');
        
        // Web Platform Rules
        if (kIsWeb) {
          // Web users must be logged in for any route except login
          if (!isLoggedIn && state.matchedLocation != '/login') {
            return '/login';
          }
          
          // Logged in but anonymous users should be redirected to login
          if (isLoggedIn && isAnonymous) {
            return '/login';
          }
          
          // Authenticated web users trying to access participant routes should be redirected to admin
          if (isLoggedIn && !isAnonymous && !isAdminRoute) {
            return '/admin';
          }
          
          // Logged in users shouldn't see the login page
          if (isLoggedIn && !isAnonymous && state.matchedLocation == '/login') {
            return '/admin';
          }
        }
        
        // Mobile Platform Rules
        else {
          // Mobile users cannot access admin routes
          if (isAdminRoute && state.matchedLocation != '/login') {
            return '/scan';
          }
          
          // Even if somehow logged in on mobile, restrict to participant routes
          if (isLoggedIn && isAdminRoute) {
            return '/scan';
          }
        }
        
        // Allow the navigation if no redirects were triggered
        return null;
      },
      routes: [
        // Public routes
        GoRoute(
          path: '/scan',
          builder: (context, state) => ScanQRScreen(),
        ),
        GoRoute(
          path: '/manual-code',
          builder: (context, state) => ManualCodeEntryScreen(),
        ),
        GoRoute(
          path: '/nickname-entry/:sessionId',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId'] ?? '';
            return NicknameEntryScreen(sessionId: sessionId);
          },
        ),
        GoRoute(
          path: '/quiz-participation',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final quizId = extra['quizId'] ?? '';
            final sessionId = extra['sessionId'] ?? '';
            final participantId = extra['participantId'] ?? '';
            return QuizParticipationScreen(
              quizId: quizId, 
              sessionId: sessionId,
              participantId: participantId,
            );
          },
        ),
        
        // Admin routes
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => AdminDashboard(),
        ),
        GoRoute(
          path: '/create-quiz',
          builder: (context, state) => CreateQuizScreen(),
        ),
        GoRoute(
          path: '/edit/:quizId',
          builder: (context, state) {
            final quizId = state.pathParameters['quizId'] ?? '';
            return EditQuizScreen(quizId: quizId);
          },
        ),
        GoRoute(
          path: '/session/:sessionId',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId'] ?? '';
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return QuizStartSessionScreen(
              quizId: extra['quizId'] ?? '',
              sessionId: sessionId,
              quizTitle: extra['quizTitle'] ?? '',
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QUISI',
      theme: ThemeData(
        primaryColor: AppBackground.primaryColor,
        scaffoldBackgroundColor: AppBackground.backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppBackground.textColor),
          titleTextStyle: TextStyle(
            color: AppBackground.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppBackground.primaryButtonStyle(),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppBackground.primaryColor,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppBackground.primaryColor),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      routerConfig: _router,
    );
  }
}

// Helper class to listen to Firebase Auth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}