// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/firestore_service.dart';
import 'seed/issues_seed.dart';

import 'screens/reports_home_screen.dart';
import 'screens/issues_master_screen.dart';
import 'screens/create_report_screen.dart';
import 'screens/report_detail_screen.dart';
import 'screens/location_edit_screen.dart';
import 'screens/login_screen.dart';

import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ seed on startup (only if empty)
  final fs = FirestoreService();
  await fs.seedIfEmpty(issuesSeed);
  await fs.debugCountIssues();

  runApp(const RCVAApp());
}

class RCVAApp extends StatelessWidget {
  const RCVAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RCVA Field',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),

      // ✅ Auth gate here (no initialRoute, no "/" route in routes)
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snap.data;
          if (user == null) {
            return const LoginScreen();
          }

          return const ReportsHomeScreen();
        },
      ),

      // ✅ IMPORTANT:
      // Do NOT include ReportsHomeScreen.routeName if it's "/" (defaultRouteName),
      // because home is already set.
      routes: {
        IssuesMasterScreen.routeName: (_) => const IssuesMasterScreen(),
        CreateReportScreen.routeName: (_) => const CreateReportScreen(),

        ReportDetailScreen.routeName: (ctx) {
          final reportId = ModalRoute.of(ctx)!.settings.arguments as String;
          return ReportDetailScreen(reportId: reportId);
        },

        LocationEditScreen.routeName: (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as LocationEditArgs;
          return LocationEditScreen(args: args);
        },
      },
    );
  }
}
