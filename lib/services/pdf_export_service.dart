import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_model.dart';
import '../models/location_model.dart';
import '../models/issue_model.dart';

class PdfExportService {
  Future<File> exportReportAsPdf({
    required ReportModel report,
    required List<LocationModel> locations,
    required List<IssueModel> allIssues,
  }) async {
    final idToIssue = {for (final i in allIssues) i.id: i};

    int locNoAsInt(String s) => int.tryParse(s.trim()) ?? 999999;
    final sortedLocations = [...locations]
      ..sort((a, b) => locNoAsInt(a.locationNo).compareTo(locNoAsInt(b.locationNo)));

    final doc = pw.Document();

    pw.TextStyle h1 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
    pw.TextStyle h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
    pw.TextStyle normal = const pw.TextStyle(fontSize: 10);

    String safe(String s) => s.trim().isEmpty ? '-' : s.trim();

    List<List<String>> buildRows(List<String> ids, String category) {
      final rows = <List<String>>[];
      for (final id in ids) {
        final it = idToIssue[id];
        if (it == null) continue;
        if (it.category.trim().toUpperCase() != category) continue;

        rows.add([
          safe(it.title),
          safe(it.recommendation),
        ]);
      }
      if (rows.isEmpty) {
        rows.add(['-', '-']);
      }
      return rows;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(report.name.trim().isEmpty ? 'RCVA Report' : report.name, style: h1),
          pw.SizedBox(height: 6),
          pw.Text(
            'Report Period: ${_fmt(report.startDate)} → ${_fmt(report.endDate)}',
            style: normal,
          ),
          pw.SizedBox(height: 12),

          for (final loc in sortedLocations) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${safe(loc.locationNo)}. ${safe(loc.locationName)}', style: h2),
                  pw.SizedBox(height: 6),
                  pw.Text('Agency: ${safe(loc.agency.isEmpty ? "NHAI" : loc.agency)}', style: normal),
                  pw.Text(
                    'GPS: ${(loc.lat != null && loc.lng != null) ? "${loc.lat!.toStringAsFixed(6)}, ${loc.lng!.toStringAsFixed(6)}" : "-"}',
                    style: normal,
                  ),
                  pw.Text('Police Station: ${safe(loc.policeStation)}', style: normal),
                  pw.SizedBox(height: 10),

                  pw.Text('Engineering Issues', style: h2),
                  pw.SizedBox(height: 4),
                  pw.TableHelper.fromTextArray(
                    headers: const ['Issue', 'Recommendation'],
                    data: buildRows(loc.engineeringIssueIds, 'ENGINEERING'),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    cellAlignment: pw.Alignment.topLeft,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(1),
                    },
                  ),
                  pw.SizedBox(height: 10),

                  pw.Text('Enforcement Issues', style: h2),
                  pw.SizedBox(height: 4),
                  pw.TableHelper.fromTextArray(
                    headers: const ['Issue', 'Recommendation'],
                    data: buildRows(loc.enforcementIssueIds, 'ENFORCEMENT'),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    cellAlignment: pw.Alignment.topLeft,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(1),
                    },
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ]
        ],
      ),
    );

    final bytes = await doc.save();

    final dir = await getApplicationDocumentsDirectory();
    final safeName = _fileSafe(report.name.isNotEmpty ? report.name : 'RCVA_Report');
    final outFile = File(p.join(dir.path, '$safeName.pdf'));
    await outFile.writeAsBytes(bytes, flush: true);

    return outFile;
  }

  String _fileSafe(String s) {
    final x = s.trim().isEmpty ? 'RCVA_Report' : s.trim();
    return x.replaceAll(RegExp(r'[^a-zA-Z0-9-_]+'), '_');
  }

  String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }
}
