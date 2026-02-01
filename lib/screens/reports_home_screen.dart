// lib/screens/reports_home_screen.dart
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import 'create_report_screen.dart';
import 'issues_master_screen.dart';
import 'report_detail_screen.dart';

class ReportsHomeScreen extends StatelessWidget {
  static const routeName = '/';
  const ReportsHomeScreen({super.key});

  String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will be signed out from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // ✅ Full logout (Google + Firebase) so chooser appears next login
    await AuthService().signOut();

    // main.dart authStateChanges will auto send user to LoginScreen
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RCVA'),
        actions: [
          IconButton(
            tooltip: 'Master Issues',
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.pushNamed(context, IssuesMasterScreen.routeName),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: fs.watchReports(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final reports = snap.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            children: [
              // Top actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reports Dashboard',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a project, add locations, capture photos, and tag issues.',
                        style: TextStyle(color: Colors.black.withOpacity(0.70)),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, CreateReportScreen.routeName),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Project'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, IssuesMasterScreen.routeName),
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Open Master Issues'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Section header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Projects',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      '${reports.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (reports.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 44, color: Colors.black.withOpacity(0.55)),
                        const SizedBox(height: 10),
                        const Text(
                          'No projects yet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap “Create Project” to start.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black.withOpacity(0.70)),
                        ),
                      ],
                    ),
                  ),
                ),

              for (final r in reports) ...[
                _ReportCard(
                  name: r.name,
                  subtitle: 'Audit: ${_fmt(r.startDate)} → ${_fmt(r.endDate)}',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      ReportDetailScreen.routeName,
                      arguments: r.id,
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportCard({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Icon(Icons.description_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.black.withOpacity(0.70)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.55)),
            ],
          ),
        ),
      ),
    );
  }
}
