import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:media_store_plus/media_store_plus.dart';

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

  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
  }

  final fs = FirestoreService();

  // ✅ Prefer the newer, safe initializer (handles category/source migrations)
  await fs.ensureIssuesReady(issuesSeed);

  // ✅ Debug prints only in debug mode (won't break release builds)
  if (kDebugMode) {
    await fs.debugCategoryCounts(); // this exists in the updated service
  }

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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snap.data;
          if (user == null) return const LoginScreen();
          return const ReportsHomeScreen();
        },
      ),
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
