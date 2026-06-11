import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/journey_planner/screens/home_screen.dart';
import '../features/journey_planner/screens/route_results_screen.dart';
import '../features/journey_editor/screens/editor_screen.dart';
import '../features/checkpoint/screens/active_journey_screen.dart';
import '../features/guardian/screens/guardian_screen.dart';
import '../core/models/journey_plan.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',          builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login',     builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home',      builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/results',
      builder: (_, state) {
        final plans = state.extra as List<JourneyPlan>;
        return RouteResultsScreen(plans: plans);
      },
    ),
    GoRoute(
      path: '/editor',
      builder: (_, state) {
        final plan = state.extra as JourneyPlan;
        return EditorScreen(plan: plan);
      },
    ),
    GoRoute(
      path: '/journey',
      builder: (_, state) {
        final plan = state.extra as JourneyPlan;
        return ActiveJourneyScreen(plan: plan);
      },
    ),
    GoRoute(
      path: '/guardian/:journeyId',
      builder: (_, state) {
        final id = state.pathParameters['journeyId']!;
        return GuardianScreen(journeyId: id);
      },
    ),
  ],
);
