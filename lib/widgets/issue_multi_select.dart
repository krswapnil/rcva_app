import 'package:flutter/material.dart';
import '../models/issue_model.dart';

class IssueMultiSelect extends StatefulWidget {
  final String title;
  final List<IssueModel> allIssues; // already filtered by caller
  final List<String> selectedIds;   // initial / external value
  final ValueChanged<List<String>> onChanged;
  final VoidCallback? onAddNewIssue;

  const IssueMultiSelect({
    super.key,
    required this.title,
    required this.allIssues,
    required this.selectedIds,
    required this.onChanged,
    this.onAddNewIssue,
  });

  @override
  State<IssueMultiSelect> createState() => _IssueMultiSelectState();
}

class _IssueMultiSelectState extends State<IssueMultiSelect> {
  final searchC = TextEditingController();
  String query = '';

  // ✅ local selection state (fixes multi-select everywhere)
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIds.toSet();
  }

  @override
  void didUpdateWidget(covariant IssueMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If parent provides a new list (e.g., loading existing location),
    // sync local state.
    if (!_listEquals(oldWidget.selectedIds, widget.selectedIds)) {
      _selected = widget.selectedIds.toSet();
    }
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<IssueModel> _filtered() {
    var filtered = widget.allIssues;

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((i) => i.title.toLowerCase().contains(q)).toList();
    }

    filtered.sort((a, b) => a.title.compareTo(b.title));
    return filtered;
  }

  void _toggle(String id, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });

    // emit to parent
    widget.onChanged(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
            if (widget.onAddNewIssue != null)
              TextButton.icon(
                onPressed: widget.onAddNewIssue,
                icon: const Icon(Icons.add),
                label: const Text('Add new'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Search
        TextField(
          controller: searchC,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search issues',
          ),
          onChanged: (v) => setState(() => query = v.trim()),
        ),
        const SizedBox(height: 10),

        // List
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'No issues found',
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final issue = items[i];
                final checked = _selected.contains(issue.id);

                return CheckboxListTile(
                  value: checked,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => _toggle(issue.id, v == true),
                  title: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      issue.recommendation,
                      style: TextStyle(color: Colors.black.withOpacity(0.7), height: 1.25),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
