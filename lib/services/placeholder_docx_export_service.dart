import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/issue_model.dart';
import '../models/location_model.dart';
import '../models/report_model.dart';

class PlaceholderDocxExportService {
  static const _uuid = Uuid();

  /// ✅ Turn on while debugging
  final bool debugDocx = true;

  /// Ensures unique wp:docPr ids across the whole document.
  int _docPrCounter = 1;

  Future<File> exportReportAsDocx({
    required ReportModel report,
    required List<LocationModel> locations,
    required List<IssueModel> allIssues,
  }) async {
    _log('🟦 exportReportAsDocx START');

    try {
      // Map id -> IssueModel
      final idToIssue = {for (final i in allIssues) i.id: i};

      // ------------------------------------------------------------
      // Load template
      // ------------------------------------------------------------
      _log('🟦 Loading template...');
      final data =
          await rootBundle.load('assets/templates/rcva_templatev1.docx');
      final templateBytes = data.buffer.asUint8List();
      _log('🟦 TEMPLATE LEN: ${templateBytes.length}');

      // ------------------------------------------------------------
      // Decode ZIP
      // ------------------------------------------------------------
      _log('🟦 Decoding ZIP...');
      final originalArchive = ZipDecoder().decodeBytes(templateBytes);

      // document.xml
      _log('🟦 Reading word/document.xml...');
      final docFile = originalArchive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () =>
            throw Exception('word/document.xml not found in template'),
      );
      var documentXml = utf8.decode(_asBytes(docFile.content));

      if (debugDocx) {
        _log('🧪 TEMPLATE raw contains:');
        _log(
            '  LOCATION_BLOCK_START: ${documentXml.contains("{{LOCATION_BLOCK_START}}")}');
        _log(
            '  LOCATION_BLOCK_END  : ${documentXml.contains("{{LOCATION_BLOCK_END}}")}');
        _log(
            '  ENG_TABLE_ROWS      : ${documentXml.contains("{{ENG_TABLE_ROWS}}")}');
        _log(
            '  ENF_TABLE_ROWS      : ${documentXml.contains("{{ENF_TABLE_ROWS}}")}');

        // If markers are split across runs, these will be false. So we also do a "loose" check:
        _log('🧪 TEMPLATE loose contains (may detect split markers):');
        _log(
            '  loose ENG_TABLE_ROWS: ${_looseContainsPlaceholder(documentXml, "ENG_TABLE_ROWS")}');
        _log(
            '  loose ENF_TABLE_ROWS: ${_looseContainsPlaceholder(documentXml, "ENF_TABLE_ROWS")}');
      }

      final hasStart = documentXml.contains('{{LOCATION_BLOCK_START}}');
      final hasEnd = documentXml.contains('{{LOCATION_BLOCK_END}}');
      _log('🟦 HAS START: $hasStart');
      _log('🟦 HAS END: $hasEnd');
      if (!hasStart || !hasEnd) {
        throw Exception(
          'Template markers not found.\n'
          'Make sure the EXACT text {{LOCATION_BLOCK_START}} and {{LOCATION_BLOCK_END}} exists in the template.',
        );
      }

      // ✅ Auto-fix: merge placeholders broken across multiple <w:t>
      if (debugDocx) {
        _log('🛠️ Normalizing split placeholders (if any)...');
      }
      documentXml = _normalizeSplitPlaceholders(documentXml);

      if (debugDocx) {
        _log('🧪 AFTER normalize:');
        _log('  ENG_TABLE_ROWS: ${documentXml.contains("{{ENG_TABLE_ROWS}}")}');
        _log('  ENF_TABLE_ROWS: ${documentXml.contains("{{ENF_TABLE_ROWS}}")}');
      }

      // rels
      _log('🟦 Reading word/_rels/document.xml.rels...');
      final relsFile = originalArchive.files.firstWhere(
        (f) => f.name == 'word/_rels/document.xml.rels',
        orElse: () => throw Exception(
            'word/_rels/document.xml.rels not found in template'),
      );
      var relsXml = utf8.decode(_asBytes(relsFile.content));

      // content types
      _log('🟦 Reading [Content_Types].xml...');
      final ctFile = originalArchive.files.firstWhere(
        (f) => f.name == '[Content_Types].xml',
        orElse: () =>
            throw Exception('[Content_Types].xml not found in template'),
      );
      var contentTypesXml = utf8.decode(_asBytes(ctFile.content));

      // ------------------------------------------------------------
      // Sort locations
      // ------------------------------------------------------------
      int locNoAsInt(String s) => int.tryParse(s.trim()) ?? 999999;
      final sortedLocations = [...locations]
        ..sort((a, b) =>
            locNoAsInt(a.locationNo).compareTo(locNoAsInt(b.locationNo)));
      _log('🟦 Locations: ${sortedLocations.length}');

      // ------------------------------------------------------------
      // Extract location block template
      // ------------------------------------------------------------
      _log('🟦 Extracting LOCATION BLOCK...');
      final block = _extractBetween(
          documentXml, '{{LOCATION_BLOCK_START}}', '{{LOCATION_BLOCK_END}}');
      if (block == null) {
        throw Exception('Template missing LOCATION block markers.');
      }

      final blockTemplate = block.inner;
      final beforeBlock = block.before;
      final afterBlock = block.after;

      final builtBlocks = StringBuffer();
      final extraMediaFiles = <ArchiveFile>[];
      final usedImageExts = <String>{};

      // ------------------------------------------------------------
      // Build each location block
      // ------------------------------------------------------------
      for (int li = 0; li < sortedLocations.length; li++) {
        final loc = sortedLocations[li];
        _log(
            '🟩 Building location ${li + 1}/${sortedLocations.length}: ${loc.locationNo}');

        var b = blockTemplate;

        // ✅ Normalize inside block too (some templates break markers inside the block)
        b = _normalizeSplitPlaceholders(b);

        // (1) Simple placeholders
        b = _replaceAll(b, {
          '{{REPORT_TITLE}}': report.name.isNotEmpty ? report.name : 'RCVA Report',
          '{{LOCATION_NO}}': loc.locationNo.trim(),
          '{{LOCATION_NAME}}': loc.locationName.trim(),
          '{{ROAD_AGENCY}}': loc.agency.trim().isEmpty ? 'NHAI' : loc.agency.trim(),
          '{{GPS_COORDINATES}}': (loc.lat != null && loc.lng != null)
              ? '${loc.lat!.toStringAsFixed(6)}, ${loc.lng!.toStringAsFixed(6)}'
              : '-',
          '{{POLICE_STATION}}':
              loc.policeStation.trim().isEmpty ? '-' : loc.policeStation.trim(),
        });

        // (2) Photo captions
        for (int i = 0; i < 4; i++) {
          final ids = loc.imageIssueIdsMap['$i'] ?? <String>[];
          final titles = ids
              .map((id) => idToIssue[id])
              .whereType<IssueModel>()
              .map((it) => it.title.trim())
              .where((t) => t.isNotEmpty)
              .toList();

          final value = titles.isEmpty ? '-' : titles.join(', ');
          b = b.replaceAll('{{IMG${i + 1}_ISSUES}}', _xmlEscape(value));
          b = b.replaceAll('{{IMG${i + 1}ISSUES}}', _xmlEscape(value));
        }

        // (3) Engineering rows
        final engPairs = _buildIssuePairs(
          issueIds: loc.engineeringIssueIds,
          idToIssue: idToIssue,
          category: 'ENGINEERING',
        );

        if (debugDocx) {
          _log(
              '🧪 LOC ${loc.locationNo} ENG: marker present=${b.contains("{{ENG_TABLE_ROWS}}")}, issuePairs=${engPairs.length}');
          _logMarkerContext(b, '{{ENG_TABLE_ROWS}}');
        }

        b = _expandMarkerRowInTwoColumnTable(
          blockXml: b,
          marker: '{{ENG_TABLE_ROWS}}',
          issueKey: '{{ENG_ISSUE}}',
          recoKey: '{{ENG_RECO}}',
          rows: engPairs,
          emptyIssue: 'No engineering issues selected',
          emptyReco: '-',
        );

        if (debugDocx) {
          _log(
              '🧪 LOC ${loc.locationNo} ENG after expand: markerLeft=${b.contains("{{ENG_TABLE_ROWS}}")} ENG_ISSUE left=${b.contains("{{ENG_ISSUE}}")} ENG_RECO left=${b.contains("{{ENG_RECO}}")}');
        }

        // (4) Enforcement rows
        final enfPairs = _buildIssuePairs(
          issueIds: loc.enforcementIssueIds,
          idToIssue: idToIssue,
          category: 'ENFORCEMENT',
        );

        if (debugDocx) {
          _log(
              '🧪 LOC ${loc.locationNo} ENF: marker present=${b.contains("{{ENF_TABLE_ROWS}}")}, issuePairs=${enfPairs.length}');
          _logMarkerContext(b, '{{ENF_TABLE_ROWS}}');
        }

        b = _expandMarkerRowInTwoColumnTable(
          blockXml: b,
          marker: '{{ENF_TABLE_ROWS}}',
          issueKey: '{{ENF_ISSUE}}',
          recoKey: '{{ENF_RECO}}',
          rows: enfPairs,
          emptyIssue: 'No enforcement issues selected',
          emptyReco: '-',
        );

        if (debugDocx) {
          _log(
              '🧪 LOC ${loc.locationNo} ENF after expand: markerLeft=${b.contains("{{ENF_TABLE_ROWS}}")} ENF_ISSUE left=${b.contains("{{ENF_ISSUE}}")} ENF_RECO left=${b.contains("{{ENF_RECO}}")}');
        }

        // (5) Images
        for (int i = 0; i < 4; i++) {
          final placeholder = '{{IMG_${i + 1}}}';
          final alt2 = '{{IMG${i + 1}}}';

          final pathOrUrl =
              (i < loc.imagePaths.length) ? loc.imagePaths[i].trim() : '';
          if (pathOrUrl.isEmpty) {
            b = _removePlaceholderTextSafely(b, placeholder);
            b = _removePlaceholderTextSafely(b, alt2);
            continue;
          }

          _log('🟨 Reading image ${i + 1} for loc ${loc.locationNo}...');
          final imgBytes = await _readImageBytes(pathOrUrl);
          if (imgBytes == null) {
            _log('🟥 Image read failed, removing placeholder: $pathOrUrl');
            b = _removePlaceholderTextSafely(b, placeholder);
            b = _removePlaceholderTextSafely(b, alt2);
            continue;
          }

          final ext = _guessImageExt(pathOrUrl, imgBytes);
          if (ext == 'webp') {
            _log('🟥 WEBP not supported in DOCX. Skipping image: $pathOrUrl');
            b = _removePlaceholderTextSafely(b, placeholder);
            b = _removePlaceholderTextSafely(b, alt2);
            continue;
          }

          usedImageExts.add(ext);

          final fileName = 'img_${_uuid.v4()}.$ext';
          final mediaPath = 'word/media/$fileName';
          extraMediaFiles.add(
              ArchiveFile(mediaPath, imgBytes.length, imgBytes));

          final relId = 'rId${_uuid.v4().replaceAll('-', '').substring(0, 8)}';
          relsXml = _addImageRelationship(relsXml, relId, 'media/$fileName');

          if (b.contains(placeholder)) {
            b = _replaceImagePlaceholderWithDrawing(
              blockXml: b,
              placeholder: placeholder,
              relId: relId,
              cx: 5000000,
              cy: 3200000,
            );
          } else if (b.contains(alt2)) {
            b = _replaceImagePlaceholderWithDrawing(
              blockXml: b,
              placeholder: alt2,
              relId: relId,
              cx: 5000000,
              cy: 3200000,
            );
          }
        }

        // Cleanup leftovers
        b = b
            .replaceAll('{{ENG_ISSUE}}', '')
            .replaceAll('{{ENG_RECO}}', '')
            .replaceAll('{{ENF_ISSUE}}', '')
            .replaceAll('{{ENF_RECO}}', '')
            .replaceAll('{{ENG_TABLE_ROWS}}', '')
            .replaceAll('{{ENF_TABLE_ROWS}}', '');

        builtBlocks.write(b);
      }

      // Merge back
      _log('🟦 Merging document.xml...');
      documentXml = beforeBlock + builtBlocks.toString() + afterBlock;

      if (debugDocx) {
        _log('🧪 FINAL leftover check:');
        _log(
            '  ENG_TABLE_ROWS leftover: ${documentXml.contains("{{ENG_TABLE_ROWS}}")}');
        _log(
            '  ENF_TABLE_ROWS leftover: ${documentXml.contains("{{ENF_TABLE_ROWS}}")}');
      }

      // Ensure content types
      _log('🟦 Updating [Content_Types].xml for images: $usedImageExts');
      contentTypesXml =
          _ensureImageContentTypes(contentTypesXml, usedImageExts);

      // Build NEW archive
      _log('🟦 Building new archive...');
      final newArchive = Archive();

      for (final f in originalArchive.files) {
        if (f.name == 'word/document.xml') continue;
        if (f.name == 'word/_rels/document.xml.rels') continue;
        if (f.name == '[Content_Types].xml') continue;
        newArchive.addFile(ArchiveFile(f.name, f.size, f.content));
      }

      final docBytes = utf8.encode(documentXml);
      final relsBytes = utf8.encode(relsXml);
      final ctBytes = utf8.encode(contentTypesXml);

      newArchive.addFile(
          ArchiveFile('word/document.xml', docBytes.length, docBytes));
      newArchive.addFile(ArchiveFile('word/_rels/document.xml.rels',
          relsBytes.length, relsBytes));
      newArchive.addFile(
          ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

      for (final mf in extraMediaFiles) {
        newArchive.addFile(mf);
      }

      _log('🟦 Encoding ZIP back to DOCX...');
      final outBytes = ZipEncoder().encode(newArchive);
      if (outBytes == null) throw Exception('Failed to encode output DOCX');

      _log('🟦 Writing output file...');
      final dir = await getApplicationDocumentsDirectory();
      final safeName = _fileSafe(report.name.isNotEmpty ? report.name : 'RCVA_Report');
      final outFile = File(p.join(dir.path, '$safeName.docx'));
      await outFile.writeAsBytes(outBytes, flush: true);

      _log('✅ EXPORT OK: ${outFile.path}');
      _log('🟦 exportReportAsDocx END');
      return outFile;
    } catch (e, st) {
      _log('❌ EXPORT ERROR: $e');
      _log(st.toString());
      rethrow;
    }
  }

  // ============================================================
  // Expand marker row: duplicates the <w:tr> that contains marker
  // ============================================================
  String _expandMarkerRowInTwoColumnTable({
    required String blockXml,
    required String marker,
    required String issueKey,
    required String recoKey,
    required List<_Pair> rows,
    required String emptyIssue,
    required String emptyReco,
  }) {
    final rowTpl = _extractContainingRow(blockXml, marker);
    if (rowTpl == null) {
      _log('🟥 EXPAND FAIL: marker not found in block: $marker');
      if (debugDocx) _logMarkerContext(blockXml, marker);
      return blockXml;
    }

    final tplRowXml = rowTpl.rowXml;
    final effective = rows.isEmpty ? [_Pair(emptyIssue, emptyReco)] : rows;

    _log('🟩 EXPAND OK: $marker found. inserting ${effective.length} rows');

    final built = StringBuffer();
    for (final r in effective) {
      var rowXml = tplRowXml;
      rowXml = rowXml.replaceAll(marker, '');
      rowXml = rowXml.replaceAll(issueKey, _xmlEscape(r.left));
      rowXml = rowXml.replaceAll(recoKey, _xmlEscape(r.right));
      built.write(rowXml);
    }

    final out = rowTpl.before + built.toString() + rowTpl.after;
    if (debugDocx) {
      _log('🧪 EXPAND result marker leftover: ${out.contains(marker)}');
    }
    return out;
  }

  _RowExtract? _extractContainingRow(String xml, String marker) {
    final idx = xml.indexOf(marker);
    if (idx < 0) return null;

    final rowStart = xml.lastIndexOf('<w:tr', idx);
    final rowEnd = xml.indexOf('</w:tr>', idx);
    if (rowStart < 0 || rowEnd < 0) return null;

    final endInclusive = rowEnd + '</w:tr>'.length;
    return _RowExtract(
      before: xml.substring(0, rowStart),
      rowXml: xml.substring(rowStart, endInclusive),
      after: xml.substring(endInclusive),
    );
  }

  // ------------------------------------------------------------
  // ✅ Issue pairs (UPDATED: tolerant category matching)
  // ------------------------------------------------------------

  String _normCat(String? v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s.isEmpty) return '';

    if (s == 'ENGINEERING' || s.contains('ENGINEER')) return 'ENGINEERING';

    if (s == 'ENFORCEMENT' ||
        s.contains('ENFORCE') ||
        s.contains('POLICE') ||
        s.contains('TRAFFIC') ||
        s.contains('RTO') ||
        s.contains('TRANSPORT')) {
      return 'ENFORCEMENT';
    }

    // fallback (some old value)
    return s;
  }

  List<_Pair> _buildIssuePairs({
    required List<String> issueIds,
    required Map<String, IssueModel> idToIssue,
    required String category,
  }) {
    final want = _normCat(category);
    final out = <_Pair>[];

    for (final id in issueIds) {
      final issue = idToIssue[id];
      if (issue == null) continue;

      final got = _normCat(issue.category);

      // If BOTH known and mismatching -> skip
      if (want.isNotEmpty && got.isNotEmpty && got != want) continue;

      out.add(_Pair(
        issue.title.trim().isEmpty ? '-' : issue.title.trim(),
        issue.recommendation.trim().isEmpty ? '-' : issue.recommendation.trim(),
      ));
    }

    if (debugDocx) {
      _log('🧾 _buildIssuePairs($category): ids=${issueIds.length}, out=${out.length}');
      if (issueIds.isNotEmpty && out.isEmpty) {
        _log('🟥 Warning: all issues filtered out. Check IssueModel.category values.');
      }
    }

    return out;
  }

  // ------------------------------------------------------------
  // Relationships + drawing
  // ------------------------------------------------------------
  String _addImageRelationship(String relsXml, String relId, String target) {
    const type =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';
    final relTag =
        '<Relationship Id="$relId" Type="$type" Target="$target"/>';

    if (relsXml.contains('Id="$relId"')) return relsXml;

    final closeTag = '</Relationships>';
    final idx = relsXml.lastIndexOf(closeTag);
    if (idx == -1) throw Exception('Invalid rels XML: missing </Relationships>');

    return relsXml.substring(0, idx) + relTag + relsXml.substring(idx);
  }

  String _removePlaceholderTextSafely(String xml, String placeholder) {
    var out = xml.replaceAll(placeholder, '');
    out = out.replaceAll(
      RegExp(r'(<w:t[^>]*>)\s*' +
          RegExp.escape(placeholder) +
          r'\s*(</w:t>)'),
      r'$1$2',
    );
    return out;
  }

  String _replaceImagePlaceholderWithDrawing({
    required String blockXml,
    required String placeholder,
    required String relId,
    required int cx,
    required int cy,
  }) {
    final drawing = _drawingXml(relId: relId, cx: cx, cy: cy);

    final textPattern = RegExp(
      r'(<w:t[^>]*>)\s*' + RegExp.escape(placeholder) + r'\s*(</w:t>)',
    );

    final match = textPattern.firstMatch(blockXml);
    if (match != null) {
      final afterTextIdx = match.end;
      final closeRunIdx = blockXml.indexOf('</w:r>', afterTextIdx);
      if (closeRunIdx != -1) {
        final before =
            blockXml.substring(0, closeRunIdx).replaceAll(placeholder, '');
        final after = blockXml.substring(closeRunIdx);
        return before + drawing + after;
      }
    }

    // fallback
    final idx = blockXml.indexOf(placeholder);
    if (idx < 0) return blockXml;
    final closeIdx = blockXml.indexOf('</w:r>', idx);
    if (closeIdx < 0) return blockXml.replaceAll(placeholder, '');

    final before =
        blockXml.substring(0, closeIdx).replaceAll(placeholder, '');
    final after = blockXml.substring(closeIdx);
    return before + drawing + after;
  }

  String _drawingXml({required String relId, required int cx, required int cy}) {
    final docPrId = _docPrCounter++;
    return '''
<w:drawing>
  <wp:inline distT="0" distB="0" distL="0" distR="0"
    xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
    xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
    xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    <wp:extent cx="$cx" cy="$cy"/>
    <wp:docPr id="$docPrId" name="Picture $docPrId"/>
    <a:graphic>
      <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:pic>
          <pic:nvPicPr>
            <pic:cNvPr id="0" name="Image"/>
            <pic:cNvPicPr/>
          </pic:nvPicPr>
          <pic:blipFill>
            <a:blip r:embed="$relId"/>
            <a:stretch><a:fillRect/></a:stretch>
          </pic:blipFill>
          <pic:spPr>
            <a:xfrm>
              <a:off x="0" y="0"/>
              <a:ext cx="$cx" cy="$cy"/>
            </a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          </pic:spPr>
        </pic:pic>
      </a:graphicData>
    </a:graphic>
  </wp:inline>
</w:drawing>
''';
  }

  // ------------------------------------------------------------
  // Content Types
  // ------------------------------------------------------------
  String _ensureImageContentTypes(String xml, Set<String> usedExts) {
    final exts = usedExts.map((e) => e.toLowerCase()).toSet();

    String addDefaultIfMissing(String xml, String ext, String contentType) {
      final re = RegExp(r'<Default[^>]+Extension="' +
          RegExp.escape(ext) +
          r'"[^>]*/?>');
      if (re.hasMatch(xml)) return xml;

      final insertTag = '<Default Extension="$ext" ContentType="$contentType"/>';
      final close = '</Types>';
      final idx = xml.lastIndexOf(close);
      if (idx == -1) throw Exception('Invalid [Content_Types].xml: missing </Types>');
      return xml.substring(0, idx) + insertTag + xml.substring(idx);
    }

    if (exts.contains('jpg') || exts.contains('jpeg')) {
      xml = addDefaultIfMissing(xml, 'jpg', 'image/jpeg');
      xml = addDefaultIfMissing(xml, 'jpeg', 'image/jpeg');
    }
    if (exts.contains('png')) {
      xml = addDefaultIfMissing(xml, 'png', 'image/png');
    }
    return xml;
  }

  // ------------------------------------------------------------
  // Images: local OR URL
  // ------------------------------------------------------------
  Future<Uint8List?> _readImageBytes(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      try {
        final res = await http
            .get(Uri.parse(pathOrUrl))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
        return null;
      } catch (e) {
        _log('🟥 http image read failed: $e');
        return null;
      }
    }

    try {
      final f = File(pathOrUrl);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (e) {
      _log('🟥 local image read failed: $e');
      return null;
    }
  }

  String _guessImageExt(String pathOrUrl, Uint8List bytes) {
    final lower = pathOrUrl.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';

    if (bytes.length > 4) {
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return 'jpg';
      }
    }
    return 'jpg';
  }

  // ------------------------------------------------------------
  // XML helpers
  // ------------------------------------------------------------
  _BetweenResult? _extractBetween(String text, String start, String end) {
    final s = text.indexOf(start);
    if (s < 0) return null;
    final e = text.indexOf(end, s + start.length);
    if (e < 0) return null;

    return _BetweenResult(
      before: text.substring(0, s),
      inner: text.substring(s + start.length, e),
      after: text.substring(e + end.length),
    );
  }

  String _replaceAll(String s, Map<String, String> m) {
    var out = s;
    m.forEach((k, v) => out = out.replaceAll(k, _xmlEscape(v)));
    return out;
  }

  String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _fileSafe(String s) {
    final x = s.trim().isEmpty ? 'RCVA_Report' : s.trim();
    return x.replaceAll(RegExp(r'[^a-zA-Z0-9-_]+'), '_');
  }

  Uint8List _asBytes(dynamic content) {
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    try {
      final bytes = (content as dynamic).toUint8List();
      return bytes as Uint8List;
    } catch (_) {
      return Uint8List.fromList(List<int>.from(content as Iterable));
    }
  }

  // ------------------------------------------------------------
  // Debug helpers
  // ------------------------------------------------------------
  void _log(String msg) => print(msg);

  void _logMarkerContext(String xml, String marker) {
    final idx = xml.indexOf(marker);
    if (idx < 0) {
      _log('🧩 Context: marker not found: $marker');
      return;
    }
    final start = (idx - 250).clamp(0, xml.length);
    final end = (idx + 250).clamp(0, xml.length);
    _log('🧩 Context for $marker:\n${xml.substring(start, end)}');
  }

  // ------------------------------------------------------------
  // Detect split placeholders like { { E N G _ ... } }
  // ------------------------------------------------------------
  bool _looseContainsPlaceholder(String xml, String tokenName) {
    final pattern =
        RegExp(r'\{\{\s*' + RegExp.escape(tokenName) + r'\s*\}\}');
    final stripped = xml.replaceAll(RegExp(r'</?w:[^>]+>'), '');
    return pattern.hasMatch(stripped);
  }

  // ------------------------------------------------------------
  // Fix: merge placeholders that got split across multiple runs
  // ------------------------------------------------------------
  String _normalizeSplitPlaceholders(String xml) {
    final tRegex = RegExp(r'(<w:t[^>]*>)([\s\S]*?)(</w:t>)');
    final matches = tRegex.allMatches(xml).toList();
    if (matches.isEmpty) return xml;

    final segments = <_TextSeg>[];
    for (final m in matches) {
      segments.add(_TextSeg(
        start: m.start,
        end: m.end,
        open: m.group(1)!,
        text: m.group(2)!,
        close: m.group(3)!,
      ));
    }

    final allText = segments.map((s) => s.text).join();
    if (!allText.contains('{{')) return xml;

    final out = StringBuffer();
    int cursor = 0;

    bool inPlaceholder = false;
    String bufferOpen = '';
    String bufferText = '';
    String bufferClose = '';

    void flushBuffer() {
      if (bufferOpen.isNotEmpty) {
        out.write(bufferOpen);
        out.write(bufferText);
        out.write(bufferClose);
      }
      bufferOpen = '';
      bufferText = '';
      bufferClose = '';
    }

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];

      out.write(xml.substring(cursor, seg.start));
      cursor = seg.end;

      final txt = seg.text;

      if (bufferOpen.isEmpty) {
        bufferOpen = seg.open;
        bufferText = txt;
        bufferClose = seg.close;
      } else {
        bufferText += txt;
        bufferClose = seg.close;
      }

      if (!inPlaceholder) {
        if (bufferText.contains('{{') && !bufferText.contains('}}')) {
          inPlaceholder = true;
        } else if (bufferText.contains('{{') && bufferText.contains('}}')) {
          inPlaceholder = false;
          flushBuffer();
        } else {
          flushBuffer();
        }
      } else {
        if (bufferText.contains('}}')) {
          inPlaceholder = false;
          flushBuffer();
        } else {
          // keep buffering
        }
      }
    }

    out.write(xml.substring(cursor));
    return out.toString();
  }
}

class _BetweenResult {
  final String before;
  final String inner;
  final String after;
  _BetweenResult({
    required this.before,
    required this.inner,
    required this.after,
  });
}

class _RowExtract {
  final String before;
  final String rowXml;
  final String after;
  _RowExtract({
    required this.before,
    required this.rowXml,
    required this.after,
  });
}

class _Pair {
  final String left;
  final String right;
  _Pair(this.left, this.right);
}

class _TextSeg {
  final int start;
  final int end;
  final String open;
  final String text;
  final String close;
  _TextSeg({
    required this.start,
    required this.end,
    required this.open,
    required this.text,
    required this.close,
  });
}
