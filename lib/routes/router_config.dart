import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../views/participant/scan_qr_screen.dart';
import '../views/participant/manual_code_entry_screen.dart';
import '../views/participant/nickname_entry_screen.dart';
import '../views/participant/quiz_participation_screen.dart';
import '../views/auth/login_screen.dart';
import '../views/admin/admin_dashboard_screen.dart';
import '../views/quiz/create_quiz_screen.dart';
import '../views/quiz/edit_quiz_screen.dart';
import '../views/session/quiz_start_session_screen.dart';
import '../services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class RouterConfig {
  static GoRouter getRouter(AuthService authService) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: kIsWeb ? '/login' : '/scan',
      refreshListenable: GoRouterRefreshStream(authService.user),
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authService.currentUser != null;
        final isAnonymous = authService.isAnonymous;
        final isAdminRoute = state.matchedLocation.startsWith('/admin') || 
                          state.matchedLocation == '/login' ||
                          state.matchedLocation == '/create-quiz' ||
                          state.matchedLocation.startsWith('/edit/') ||
                          state.matchedLocation.startsWith('/session/');
        
        // Web Platform Rules
        if (kIsWeb) {
          if (!isLoggedIn && state.matchedLocation != '/login') {
            return '/login';
          }
          
          if (isLoggedIn && isAnonymous) {
            return '/login';
          }
          
          if (isLoggedIn && !isAnonymous && !isAdminRoute) {
            return '/admin';
          }
          
          if (isLoggedIn && !isAnonymous && state.matchedLocation == '/login') {
            return '/admin';
          }
        }
        // Mobile Platform Rules
        else {
          if (isAdminRoute && state.matchedLocation != '/login') {
            return '/scan';
          }
          
          if (isLoggedIn && isAdminRoute) {
            return '/scan';
          }
        }
        
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
}

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