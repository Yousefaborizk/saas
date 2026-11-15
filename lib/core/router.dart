import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import 'supabase_client.dart';

/// Notifier بيخلي GoRouter يعيد التقييم لما حالة الـ Auth تتغير
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    supabase.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final GoRouter router = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final path = state.matchedLocation;
    final isAuthRoute = path.startsWith('/auth');

    // 1. غير مسجل دخول
    if (session == null) {
      return isAuthRoute ? null : '/auth/login';
    }

    // 2. مسجل بس لسه ماعندوش شركة
    final orgId = session.user.appMetadata['organization_id'] as String?;
    final hasOrg = orgId != null && orgId.isNotEmpty;

    if (!hasOrg) {
      return path == '/onboarding' ? null : '/onboarding';
    }

    // 3. مسجل وعنده شركة — ممنوع يروح لصفحات auth أو onboarding
    if (isAuthRoute || path == '/onboarding' || path == '/') {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/signup', builder: (_, __) => const SignupScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
  ],
);
