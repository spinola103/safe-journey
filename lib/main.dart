import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart'; 
 // add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(           // uncomment this
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Firebase apps = ${Firebase.apps.length}");
  print("Firebase app = ${Firebase.app().name}");
  runApp(const ProviderScope(child: SafeJourneyApp()));
}

class SafeJourneyApp extends StatelessWidget {
  const SafeJourneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SafeJourney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
