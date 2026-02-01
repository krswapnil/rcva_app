import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/report_model.dart';
import 'report_detail_screen.dart';

class CreateReportScreen extends StatefulWidget {
  static const routeName = '/create-report';

  final String? reportId; // if present = edit
  const CreateReportScreen({super.key, this.reportId});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final fs = FirestoreService();

  final _nameC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initIfEdit();
  }

  Future<void> _initIfEdit() async {
    if (widget.reportId == null) return;

    setState(() => _loading = true);
    try {
      final r = await fs.getReport(widget.reportId!);
      if (r == null) return;

      _nameC.text = r.name;
      _start = r.startDate;
      _end = r.endDate;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  Future<void> _submit() async {
    final isEdit = widget.reportId != null;

    // Form validation
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final name = _nameC.text.trim();

    setState(() => _loading = true);
    try {
      if (isEdit) {
        final updated = ReportModel(
          id: widget.reportId!,
          name: name,
          startDate: _start,
          endDate: _end,
        );
        await fs.updateReport(widget.reportId!, updated);

        if (!mounted) return;
        Navigator.pop(context); // back to report detail
      } else {
        final created = ReportModel(
          id: '',
          name: name,
          startDate: _start,
          endDate: _end,
        );

        final id = await fs.createReport(created);

        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          ReportDetailScreen.routeName,
          arguments: id, // main.dart route expects String reportId
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.reportId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Project' : 'Create Project'),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Project Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameC,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Project / Corridor Name',
                                hintText: 'e.g., NH-548D (Talegaon–Chakan–Shikrapur)',
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return 'Please enter project/corridor name';
                                if (t.length < 3) return 'Name is too short';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Audit Dates',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _DateRow(
                              label: 'Start Date',
                              value: _fmt(_start),
                              onPick: () => _pickDate(isStart: true),
                            ),
                            const SizedBox(height: 10),
                            _DateRow(
                              label: 'End Date',
                              value: _fmt(_end),
                              onPick: () => _pickDate(isStart: false),
                            ),

                            const SizedBox(height: 8),
                            Text(
                              'Duration: ${_end.difference(_start).inDays + 1} day(s)',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: Icon(isEdit ? Icons.save : Icons.add),
                      label: Text(isEdit ? 'Save Changes' : 'Create Project'),
                    ),

                    if (!isEdit) ...[
                      const SizedBox(height: 8),
                      Text(
                        'After creating, you can add locations and photos inside the project.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.08),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onPick;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: onPick,
          child: const Text('Pick'),
        ),
      ],
    );
  }
}
