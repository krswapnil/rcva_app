import 'dart:io';
import 'dart:typed_data';

import 'package:cleartec_docx_template/cleartec_docx_template.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/issue_model.dart';
import '../models/location_model.dart';
import '../models/report_model.dart';

class DocxExportService {
  Future<File> exportReportAsDocx({
    required ReportModel report,
    required List<LocationModel> locations,
    required List<IssueModel> allIssues,
  }) async {
    final idToIssue = {for (final i in allIssues) i.id: i};

    // Load template
    final data = await rootBundle.load('assets/templates/rcva_template.docx');
    final template = await DocxTemplate.fromBytes(data.buffer.asUint8List());

    // Sort locations by locationNo numeric-safe
    int _locNoAsInt(String s) => int.tryParse(s.trim()) ?? 999999;
    final sortedLocations = [...locations]
      ..sort((a, b) => _locNoAsInt(a.locationNo).compareTo(_locNoAsInt(b.locationNo)));

    final locationContents = <Content>[];

    for (final loc in sortedLocations) {
      final c = Content();

      // --------------------
      // Header fields
      // --------------------
      c.add(TextContent('LOCATION_NO', loc.locationNo.trim()));
      c.add(TextContent('LOCATION_NAME', loc.locationName.trim()));
      c.add(TextContent('ROAD_AGENCY', loc.agency.trim().isEmpty ? 'NHAI' : loc.agency.trim()));
      c.add(TextContent(
        'GPS_COORDINATES',
        (loc.lat != null && loc.lng != null)
            ? '${loc.lat!.toStringAsFixed(6)}, ${loc.lng!.toStringAsFixed(6)}'
            : '-',
      ));
      c.add(TextContent(
        'POLICE_STATION',
        loc.policeStation.trim().isEmpty ? '-' : loc.policeStation.trim(),
      ));

      // --------------------
      // Photo captions (IMG1_ISSUES ... IMG4_ISSUES)
      // (Engineering only / or all titles if you want)
      // --------------------
      for (int i = 0; i < 4; i++) {
        final ids = loc.imageIssueIdsMap['$i'] ?? <String>[];
        final titles = ids
            .map((id) => idToIssue[id])
            .whereType<IssueModel>()
            .map((it) => it.title.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        c.add(TextContent('IMG${i + 1}_ISSUES', titles.isEmpty ? '-' : titles.join(', ')));
      }

      // --------------------
      // Images (ensure all 4 tags exist)
      // --------------------
      for (int i = 0; i < 4; i++) {
        final p = (i < loc.imagePaths.length) ? loc.imagePaths[i].trim() : '';

        // Important: always add something for each image tag
        // If missing, leave empty bytes (library will skip)
        if (p.isEmpty) continue;

        final bytes = await _readImageBytes(p);
        if (bytes == null) continue;

        c.add(ImageContent('IMG_${i + 1}', bytes));
      }

      // --------------------
      // ENGINEERING TABLE (ENG_TABLE) ✅ TableContent + RowContent
      // --------------------
      final engRowContents = <RowContent>[];

      for (final id in loc.engineeringIssueIds) {
        final issue = idToIssue[id];
        if (issue == null) continue;
        if (issue.category.trim().toUpperCase() != 'ENGINEERING') continue;

        engRowContents.add(
          RowContent()
            ..add(TextContent('ENG_ISSUE', issue.title.trim().isEmpty ? '-' : issue.title.trim()))
            ..add(TextContent('ENG_RECO',
                issue.recommendation.trim().isEmpty ? '-' : issue.recommendation.trim())),
        );
      }

      if (engRowContents.isEmpty) {
        engRowContents.add(
          RowContent()
            ..add(TextContent('ENG_ISSUE', 'No engineering issues selected'))
            ..add(TextContent('ENG_RECO', '-')),
        );
      }

      c.add(TableContent('ENG_TABLE', engRowContents));

      // --------------------
      // ENFORCEMENT TABLE (ENF_TABLE) ✅ TableContent + RowContent
      // --------------------
      final enfRowContents = <RowContent>[];

      for (final id in loc.enforcementIssueIds) {
        final issue = idToIssue[id];
        if (issue == null) continue;
        if (issue.category.trim().toUpperCase() != 'ENFORCEMENT') continue;

        enfRowContents.add(
          RowContent()
            ..add(TextContent('ENF_ISSUE', issue.title.trim().isNotEmpty ? issue.title.trim() : '-'))
            ..add(TextContent('ENF_RECO', issue.recommendation.trim().isNotEmpty
                ? issue.recommendation.trim()
                : '-')),
        );
      }

      if (enfRowContents.isEmpty) {
        enfRowContents.add(
          RowContent()
            ..add(TextContent('ENF_ISSUE', 'No enforcement issues selected'))
            ..add(TextContent('ENF_RECO', '-')),
        );
      }

      c.add(TableContent('ENF_TABLE', enfRowContents));

      // Add this location block
      locationContents.add(c);
    }

    // --------------------
    // ROOT CONTENT
    // --------------------
    final root = Content();

    // Safe even if template doesn't have REPORT_TITLE
    root.add(TextContent(
      'REPORT_TITLE',
      report.name.isNotEmpty ? report.name : 'RCVA Report',
    ));

    root.add(ListContent('LOCATIONS', locationContents));

    final generated = await template.generate(root);
    if (generated == null) {
      throw Exception('DOCX generation failed (template.generate returned null)');
    }

    final dir = await getApplicationDocumentsDirectory();
    final safeName = _fileSafe(report.name.isNotEmpty ? report.name : 'RCVA_Report');
    final out = File('${dir.path}/$safeName.docx');
    await out.writeAsBytes(generated, flush: true);

    return out;
  }

  Future<Uint8List?> _readImageBytes(String pathOrUrl) async {
    // http(s) URL
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(pathOrUrl));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return res.bodyBytes;
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    // Local file
    try {
      final f = File(pathOrUrl);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String _fileSafe(String s) {
    final x = s.trim().isEmpty ? 'RCVA_Report' : s.trim();
    return x.replaceAll(RegExp(r'[^a-zA-Z0-9-_]+'), '_');
  }
}
