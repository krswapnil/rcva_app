import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

import '../services/firestore_service.dart';
import '../services/placeholder_docx_export_service.dart';
import '../services/pdf_export_service.dart';

import '../models/report_model.dart';
import '../models/location_model.dart';
import '../models/issue_model.dart';
import 'location_edit_screen.dart';

class ReportDetailScreen extends StatefulWidget {
  static const routeName = '/report-detail';

  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final fs = FirestoreService();
  final docxService = PlaceholderDocxExportService();
  final pdfService = PdfExportService();

  ReportModel? report;
  bool loadingReport = true;

  bool exporting = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // =========================================================
  // SAFE SNACKBAR
  // =========================================================
  void _snack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // LOAD REPORT
  // =========================================================
  Future<void> _loadReport() async {
    setState(() => loadingReport = true);
    try {
      final r = await fs.getReport(widget.reportId);
      if (!mounted) return;
      setState(() => report = r);
    } finally {
      if (mounted) setState(() => loadingReport = false);
    }
  }

  // =========================================================
  // EXPORT HELPERS
  // =========================================================
  Future<(List<LocationModel>, List<IssueModel>)> _loadExportData() async {
    final locations = await fs.watchLocations(widget.reportId).first;
    final issues = await fs.watchAllIssues().first;
    return (locations, issues);
  }

  // =========================================================
  // EXPORT (DOCX)
  // =========================================================
  Future<File?> _exportDocxFile() async {
    if (report == null) return null;

    final (locations, issues) = await _loadExportData();

    final file = await docxService.exportReportAsDocx(
      report: report!,
      locations: locations,
      allIssues: issues,
    );
    return file;
  }

  Future<void> _exportAndShareDocx() async {
    if (report == null) return;
    if (exporting) return;

    setState(() => exporting = true);
    try {
      final file = await _exportDocxFile();
      if (file == null) return;

      if (!mounted) return;

      final subject = report!.name.isNotEmpty ? report!.name : 'RCVA Report';

      final x = XFile(
        file.path,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        name: '${subject.trim().isEmpty ? "RCVA_Report" : subject}.docx',
      );

      await Share.shareXFiles(
        [x],
        subject: subject,
        text: 'RCVA Report (DOCX)',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('❌ DOCX export/share failed: $e');
      // ignore: avoid_print
      print(st);

      if (!mounted) return;
      _snack('Export/share failed: $e');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _exportOnlyDocx() async {
    if (report == null) return;
    if (exporting) return;

    setState(() => exporting = true);
    try {
      final file = await _exportDocxFile();
      if (file == null) return;

      if (!mounted) return;
      _snack('Exported: ${file.path}');
    } catch (e, st) {
      // ignore: avoid_print
      print('❌ DOCX export failed: $e');
      // ignore: avoid_print
      print(st);

      if (!mounted) return;
      _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  // =========================================================
  // EXPORT (PDF) ✅ FULL IMPLEMENTATION
  // =========================================================
  Future<void> _exportAndSharePdf() async {
    if (report == null) return;
    if (exporting) return;

    setState(() => exporting = true);
    try {
      final (locations, issues) = await _loadExportData();

      final file = await pdfService.exportReportAsPdf(
        report: report!,
        locations: locations,
        allIssues: issues,
      );

      final bytes = await file.readAsBytes();

      // ✅ Best share method for PDF (opens everywhere)
      await Printing.sharePdf(
        bytes: bytes,
        filename: file.uri.pathSegments.last,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('❌ PDF export/share failed: $e');
      // ignore: avoid_print
      print(st);

      if (!mounted) return;
      _snack('PDF export/share failed: $e');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  // =========================================================
  // EDIT REPORT
  // =========================================================
  Future<void> _editReportDialog() async {
    if (report == null) return;

    final nameC = TextEditingController(text: report!.name);
    DateTime start = report!.startDate;
    DateTime end = report!.endDate;

    Future<void> pickDate(bool isStart, void Function(void Function()) setSt) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: isStart ? start : end,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked == null) return;
      if (!mounted) return;

      setSt(() {
        if (isStart) {
          start = picked;
          if (end.isBefore(start)) end = start;
        } else {
          end = picked;
          if (end.isBefore(start)) start = end;
        }
      });
    }

    String fmt(DateTime d) {
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Edit Project'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'Project name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Start: ${fmt(start)}')),
                      TextButton(onPressed: () => pickDate(true, setSt), child: const Text('Pick')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text('End: ${fmt(end)}')),
                      TextButton(onPressed: () => pickDate(false, setSt), child: const Text('Pick')),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final newName = nameC.text.trim();
                  if (newName.isEmpty) return;

                  final updated = ReportModel(
                    id: report!.id,
                    name: newName,
                    startDate: start,
                    endDate: end,
                  );

                  await fs.updateReport(widget.reportId, updated);
                  await _loadReport();

                  if (mounted) Navigator.pop(ctx);
                },
                label: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    nameC.dispose();
  }

  // =========================================================
  // DELETE PROJECT
  // =========================================================
  Future<void> _deleteProjectFlow() async {
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text(
          'You will lose all project data from Firebase.\n\n'
          'Photos on your phone will remain in the app folder.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );

    if (firstOk != true) return;

    final typedC = TextEditingController();
    final secondOk = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm delete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type DELETE to confirm.'),
              const SizedBox(height: 10),
              TextField(
                controller: typedC,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Type DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final ok = typedC.text.trim().toUpperCase() == 'DELETE';
                Navigator.pop(ctx, ok);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    typedC.dispose();

    if (secondOk != true) {
      if (!mounted) return;
      _snack('Delete cancelled');
      return;
    }

    try {
      await fs.deleteReportDeep(widget.reportId);

      if (!mounted) return;
      _snack('Project deleted from Firebase. Photos remain on device.');

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack('Delete failed: $e');
    }
  }

  // =========================================================
  // DELETE LOCATION
  // =========================================================
  Future<void> _confirmDelete(LocationModel loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text('Delete "${loc.locationNo}. ${loc.locationName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      await fs.deleteLocation(widget.reportId, loc.id);
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================
  String _titlesForIds(Map<String, String> idToTitle, List<String> ids) {
    final titles = ids.map((id) => idToTitle[id]).whereType<String>().toList();
    return titles.join(', ');
  }

  Widget _thumb(String? path) {
    if (path == null || path.trim().isEmpty) return _emptyThumb(Icons.image_not_supported);

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _emptyThumb(Icons.cloud);
    }

    final f = File(path);
    if (!f.existsSync()) return _emptyThumb(Icons.broken_image);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(f, fit: BoxFit.cover),
    );
  }

  Widget _emptyThumb(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Center(child: Icon(icon)),
    );
  }

  String _fmt(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final title = loadingReport
        ? 'Loading...'
        : (report?.name.isNotEmpty == true ? report!.name : 'Project');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // ✅ DOCX export/share
          IconButton(
            icon: exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.description_outlined),
            tooltip: 'Export & Share (DOCX)',
            onPressed: (report == null || exporting) ? null : _exportAndShareDocx,
          ),

          // ✅ PDF export/share
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export & Share (PDF)',
            onPressed: (report == null || exporting) ? null : _exportAndSharePdf,
          ),

          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit project',
            onPressed: report == null ? null : _editReportDialog,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) async {
              if (v == 'exportOnly') {
                await _exportOnlyDocx();
              }
              if (v == 'deleteProject') {
                await _deleteProjectFlow();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'exportOnly', child: Text('Export (DOCX)')),
              PopupMenuItem(value: 'deleteProject', child: Text('Delete Project')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            LocationEditScreen.routeName,
            arguments: LocationEditArgs(reportId: widget.reportId),
          );
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Location'),
      ),
      body: StreamBuilder<List<IssueModel>>(
        stream: fs.watchAllIssues(),
        builder: (context, issuesSnap) {
          if (!issuesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final idToTitle = {for (final it in issuesSnap.data!) it.id: it.title};

          return StreamBuilder<List<LocationModel>>(
            stream: fs.watchLocations(widget.reportId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final locations = snap.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.assignment_outlined, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report?.name ?? 'Project',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  report == null
                                      ? ''
                                      : 'Dates: ${_fmt(report!.startDate)}  →  ${_fmt(report!.endDate)}',
                                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Locations: ${locations.length}',
                                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: report == null ? null : _editReportDialog,
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit',
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (locations.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 40,
                              color: Colors.black.withOpacity(0.55),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No locations added yet',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap “Add Location” to start adding photos and issues.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final l in locations) ...[
                    _LocationCard(
                      location: l,
                      thumbBuilder: _thumb,
                      captionBuilder: (idx) {
                        final ids = l.imageIssueIdsMap['$idx'] ?? <String>[];
                        return _titlesForIds(idToTitle, ids);
                      },
                      onOpen: () {
                        Navigator.pushNamed(
                          context,
                          LocationEditScreen.routeName,
                          arguments: LocationEditArgs(
                            reportId: widget.reportId,
                            locationId: l.id,
                          ),
                        );
                      },
                      onDelete: () => _confirmDelete(l),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LocationModel location;
  final Widget Function(String? path) thumbBuilder;
  final String Function(int idx) captionBuilder;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _LocationCard({
    required this.location,
    required this.thumbBuilder,
    required this.captionBuilder,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final paths = List.generate(
      4,
      (idx) => idx < location.imagePaths.length ? location.imagePaths[idx] : '',
    );

    final caps = List.generate(4, (idx) => captionBuilder(idx))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${location.locationNo}. ${location.locationName}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  for (final p in paths) thumbBuilder(p),
                ],
              ),
              const SizedBox(height: 10),
              if (caps.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Photo Captions',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  children: [
                    const SizedBox(height: 6),
                    for (int i = 0; i < 4; i++) ...[
                      if (captionBuilder(i).trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Photo ${i + 1}: ${captionBuilder(i)}',
                            style: TextStyle(color: Colors.black.withOpacity(0.75)),
                          ),
                        ),
                    ],
                  ],
                )
              else
                Text(
                  'No captions selected yet.',
                  style: TextStyle(color: Colors.black.withOpacity(0.65)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
