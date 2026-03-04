// lib/screens/issues_master_screen.dart
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../models/issue_model.dart';
import '../seed/issues_seed.dart';

class IssuesMasterScreen extends StatefulWidget {
  static const routeName = '/issues-master';
  const IssuesMasterScreen({super.key});

  @override
  State<IssuesMasterScreen> createState() => _IssuesMasterScreenState();
}

class _IssuesMasterScreenState extends State<IssuesMasterScreen> {
  final fs = FirestoreService();

  final search = TextEditingController();
  String query = '';
  String categoryFilter = 'ALL'; // ALL / ENGINEERING / ENFORCEMENT

  bool _cleaning = false;
  bool _reseeding = false;

  @override
  void initState() {
    super.initState();

    // ✅ Seed/migrate silently (no UI spam)
    Future.microtask(() async {
      try {
        await fs.ensureIssuesReady(issuesSeed);
      } catch (e) {
        // ignore: avoid_print
        print('ensureIssuesReady failed: $e');
      }
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _categoryColor(String c) {
    switch (c) {
      case 'ENFORCEMENT':
        return Colors.deepPurple;
      case 'ENGINEERING':
      default:
        return Colors.teal;
    }
  }

  String _prettyCategory(String c) {
    final v = c.trim().toUpperCase();
    if (v == 'ENFORCEMENT') return 'Enforcement';
    return 'Engineering';
  }

  Future<void> _openEditor({IssueModel? issue}) async {
    final titleC = TextEditingController(text: issue?.title ?? '');
    final recC = TextEditingController(text: issue?.recommendation ?? '');
    String category = (issue?.category ?? 'ENGINEERING').toUpperCase();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                issue == null ? 'Add Issue' : 'Edit Issue',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleC,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Issue',
                  hintText: 'e.g., Wrong side driving',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: recC,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Recommendation',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                items: const [
                  DropdownMenuItem(value: 'ENGINEERING', child: Text('ENGINEERING')),
                  DropdownMenuItem(value: 'ENFORCEMENT', child: Text('ENFORCEMENT')),
                ],
                onChanged: (v) => category = (v ?? 'ENGINEERING'),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      onPressed: () async {
                        final t = titleC.text.trim();
                        final r = recC.text.trim();

                        if (t.isEmpty || r.isEmpty) {
                          _snack('Issue & recommendation required');
                          return;
                        }

                        try {
                          await fs.upsertIssue(
                            id: issue?.id,
                            title: t,
                            recommendation: r,
                            category: category,
                          );
                          if (mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _snack('Save failed: $e');
                        }
                      },
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    titleC.dispose();
    recC.dispose();
  }

  Widget _filterChips() {
    Widget chip(String value, String label) {
      final selected = categoryFilter == value;
      return ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => setState(() => categoryFilter = value),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('ALL', 'All'),
        chip('ENGINEERING', 'Engineering'),
        chip('ENFORCEMENT', 'Enforcement'),
      ],
    );
  }

  Future<void> _runDuplicateCleanup() async {
    if (_cleaning) return;

    setState(() => _cleaning = true);

    try {
      final removed = await fs.cleanupAndCanonicalizeIssues();
      _snack(removed == 0 ? 'No duplicates found ✅' : 'Removed $removed duplicate issue(s) ✅');
    } catch (e) {
      _snack('Cleanup failed: $e');
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  Future<void> _reseedFromSeedDart() async {
    if (_reseeding) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update seed.dart to Firebase?'),
        content: const Text(
          'This will DELETE old SEED issues from Firebase and upload the latest seed.dart.\n\n'
          '✅ User-added issues will NOT be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _reseeding = true);
    try {
      await fs.reseedFromApp(issuesSeed);
      _snack('✅ Seed updated in Firebase');
    } catch (e) {
      _snack('Reseed failed: $e');
    } finally {
      if (mounted) setState(() => _reseeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Issues (A–Z)'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'dedupe') {
                await _runDuplicateCleanup();
              } else if (v == 'reseed') {
                await _reseedFromSeedDart();
              } else if (v == 'debug') {
                await fs.debugCategoryCounts();
                _snack('Debug printed in console');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reseed',
                enabled: !_reseeding,
                child: Row(
                  children: [
                    const Icon(Icons.sync, size: 18),
                    const SizedBox(width: 10),
                    Text(_reseeding ? 'Updating seed...' : 'Update seed.dart to Firebase'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'dedupe',
                enabled: !_cleaning,
                child: Row(
                  children: [
                    const Icon(Icons.cleaning_services, size: 18),
                    const SizedBox(width: 10),
                    Text(_cleaning ? 'Removing duplicates...' : 'Remove duplicate issues'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 18),
                    SizedBox(width: 10),
                    Text('Debug category counts'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add issue',
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search issues',
                      ),
                      onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _filterChips(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<IssueModel>>(
              stream: fs.watchAllIssues(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Load error:\n${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var items = snapshot.data!;

                if (query.isNotEmpty) {
                  items = items.where((e) => e.title.toLowerCase().contains(query)).toList();
                }
                if (categoryFilter != 'ALL') {
                  items = items.where((e) => e.category.toUpperCase() == categoryFilter).toList();
                }

                if (items.isEmpty) {
                  return const Center(child: Text('No issues found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final cat = it.category.toUpperCase();
                    final badgeColor = _categoryColor(cat);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    it.title,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _prettyCategory(cat),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      await _openEditor(issue: it);
                                    } else if (v == 'disable') {
                                      await fs.setIssueActive(it.id, false);
                                      _snack('Disabled');
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'disable', child: Text('Disable')),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              it.recommendation,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.72),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
