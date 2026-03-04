// lib/services/placeholder_docx_export_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/issue_model.dart';
import '../models/location_model.dart';
import '../models/report_model.dart';

typedef ExportProgress = void Function(String message, int current, int total);

class PlaceholderDocxExportService {
  static const _uuid = Uuid();

  final bool debugDocx = !kReleaseMode;
  int _docPrCounter = 1;

  static const int _emuPerTwip = 635;
  static const int _padTwipsX = 280;
  static const int _padTwipsY = 180;

  // ✅ SPEED knobs
  static const int _maxDocxImageWidth = 1400;
  static const int _jpegQuality = 82;
  static const int _pngMaxBytes = 1200 * 1024;
  static const int _smallImageBypassBytes = 650 * 1024;

  /// ✅ NEW: chunked export support
  /// [startIndex] = start location index in sorted list (0-based)
  /// [count] = how many locations to export (null = all from startIndex)
  /// [fileSuffix] = added to output filename (e.g. "Part_1")
  Future<File> exportReportAsDocx({
    required ReportModel report,
    required List<LocationModel> locations,
    required List<IssueModel> allIssues,
    ExportProgress? onProgress,

    int startIndex = 0,
    int? count,
    String? fileSuffix,
  }) async {
    void progress(String msg, int cur, int tot) {
      if (onProgress != null) onProgress(msg, cur, tot);
    }

    try {
      final idToIssue = {for (final i in allIssues) i.id: i};

      progress('Loading template…', 0, 1);
      await Future.delayed(Duration.zero);

      final data = await rootBundle.load('assets/templates/rcva_templatev1.docx');
      final templateBytes = data.buffer.asUint8List();
      final originalArchive = ZipDecoder().decodeBytes(templateBytes);

      final docFile = originalArchive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () => throw Exception('word/document.xml not found in template'),
      );
      var documentXml = utf8.decode(_asBytes(docFile.content));

      final relsFile = originalArchive.files.firstWhere(
        (f) => f.name == 'word/_rels/document.xml.rels',
        orElse: () => throw Exception('word/_rels/document.xml.rels not found in template'),
      );
      var relsXml = utf8.decode(_asBytes(relsFile.content));

      final ctFile = originalArchive.files.firstWhere(
        (f) => f.name == '[Content_Types].xml',
        orElse: () => throw Exception('[Content_Types].xml not found in template'),
      );
      var contentTypesXml = utf8.decode(_asBytes(ctFile.content));

      progress('Preparing placeholders…', 0, 1);
      await Future.delayed(Duration.zero);

      // ✅ normalize once (big speed win)
      documentXml = _normalizeSplitPlaceholdersSafe(documentXml);

      if (!documentXml.contains('{{LOCATION_BLOCK_START}}') ||
          !documentXml.contains('{{LOCATION_BLOCK_END}}')) {
        throw Exception(
          'Template markers not found.\n'
          'Ensure EXACT {{LOCATION_BLOCK_START}} and {{LOCATION_BLOCK_END}} exist.',
        );
      }

      int locNoAsInt(String s) => int.tryParse(s.trim()) ?? 999999;
      final sortedLocations = [...locations]
        ..sort((a, b) => locNoAsInt(a.locationNo).compareTo(locNoAsInt(b.locationNo)));

      // ✅ chunk slice
      final safeStart = startIndex < 0 ? 0 : startIndex;
      final safeCount = (count == null || count <= 0) ? (sortedLocations.length - safeStart) : count;
      final slice = sortedLocations.skip(safeStart).take(safeCount).toList();

      if (slice.isEmpty) {
        throw Exception('No locations in this export range (startIndex=$startIndex, count=$count)');
      }

      final block = _extractBetween(
        documentXml,
        '{{LOCATION_BLOCK_START}}',
        '{{LOCATION_BLOCK_END}}',
      );
      if (block == null) throw Exception('Template missing LOCATION block markers.');

      final beforeBlock = block.before;
      final afterBlock = block.after;

      // ✅ normalize block once
      final blockTemplate = _normalizeSplitPlaceholdersSafe(block.inner);

      final builtBlocks = StringBuffer();
      final extraMediaFiles = <ArchiveFile>[];
      final usedImageExts = <String>{};

      final totalLocs = slice.length;
      final totalImages = totalLocs * 4;
      int imageCounter = 0;

      for (int li = 0; li < totalLocs; li++) {
        final loc = slice[li];

        progress('Building location ${li + 1}/$totalLocs…', li + 1, totalLocs);
        await Future.delayed(Duration.zero);

        var b = blockTemplate;

        // ✅ Replace common placeholders (+ DETAILS support)
        b = _replaceAll(b, {
          '{{REPORT_TITLE}}': report.name.isNotEmpty ? report.name : 'RCVA Report',
          '{{LOCATION_NO}}': loc.locationNo.trim(),
          '{{LOCATION_NAME}}': loc.locationName.trim(),
          '{{ROAD_AGENCY}}': loc.agency.trim().isEmpty ? 'NHAI' : loc.agency.trim(),
          '{{GPS_COORDINATES}}': (loc.lat != null && loc.lng != null)
              ? '${loc.lat!.toStringAsFixed(6)}, ${loc.lng!.toStringAsFixed(6)}'
              : '-',
          '{{POLICE_STATION}}': loc.policeStation.trim().isEmpty ? '-' : loc.policeStation.trim(),
          '{{DETAILS}}': loc.details.trim().isEmpty ? '-' : loc.details.trim(),
        });

        // ✅ Image issues text
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

        // Engineering table
        final engPairs = _buildIssuePairs(
          issueIds: loc.engineeringIssueIds,
          idToIssue: idToIssue,
          category: 'ENGINEERING',
        );

        b = _expandMarkerRowInTwoColumnTableStrict(
          blockXml: b,
          marker: '{{ENG_TABLE_ROWS}}',
          issueKey: '{{ENG_ISSUE}}',
          recoKey: '{{ENG_RECO}}',
          rows: engPairs,
          emptyIssue: 'No engineering issues selected',
          emptyReco: '-',
          tag: 'LOC ${loc.locationNo} ENG',
        );

        // Enforcement table
        final enfPairs = _buildIssuePairs(
          issueIds: loc.enforcementIssueIds,
          idToIssue: idToIssue,
          category: 'ENFORCEMENT',
        );

        b = _expandMarkerRowInTwoColumnTableStrict(
          blockXml: b,
          marker: '{{ENF_TABLE_ROWS}}',
          issueKey: '{{ENF_ISSUE}}',
          recoKey: '{{ENF_RECO}}',
          rows: enfPairs,
          emptyIssue: 'No enforcement issues selected',
          emptyReco: '-',
          tag: 'LOC ${loc.locationNo} ENF',
        );

        // ------------------ Images: parallel 4 per location ------------------
        final jobs = <Future<_ImgReady>>[];

        for (int i = 0; i < 4; i++) {
          final placeholder = '{{IMG_${i + 1}}}';
          final alt2 = '{{IMG${i + 1}}}';

          final usedPlaceholder = b.contains(placeholder)
              ? placeholder
              : (b.contains(alt2) ? alt2 : null);

          final pathOrUrl = (i < loc.imagePaths.length) ? loc.imagePaths[i].trim() : '';

          jobs.add(_prepareImageForDocx(
            index: i,
            usedPlaceholder: usedPlaceholder,
            pathOrUrl: pathOrUrl,
          ));
        }

        final prepared = await Future.wait(jobs);

        for (final r in prepared) {
          imageCounter++;
          progress('Processing image $imageCounter/$totalImages…', imageCounter, totalImages);
          await Future.delayed(Duration.zero);

          if (r.usedPlaceholder == null) continue;

          if (r.bytes == null || r.bytes!.isEmpty || r.ext == null) {
            b = _removePlaceholderTextSafely(b, r.usedPlaceholder!);
            continue;
          }

          usedImageExts.add(r.ext!);

          final fileName = 'img_${_uuid.v4()}.${r.ext}';
          extraMediaFiles.add(ArchiveFile('word/media/$fileName', r.bytes!.length, r.bytes!));

          final relId = 'rId${_uuid.v4().replaceAll('-', '').substring(0, 8)}';
          relsXml = _addImageRelationship(relsXml, relId, 'media/$fileName');

          final size = _getCellSizeForPlaceholderTwips(b, r.usedPlaceholder!);
          final cx = _fitCxFromTwips(size.widthTwips);
          final cy = _fitCyFromTwips(size.heightTwips);

          b = _replaceImagePlaceholderWithDrawing(
            blockXml: b,
            placeholder: r.usedPlaceholder!,
            relId: relId,
            cx: cx,
            cy: cy,
          );
        }

        // cleanup leftovers
        b = b
            .replaceAll('{{ENG_ISSUE}}', '')
            .replaceAll('{{ENG_RECO}}', '')
            .replaceAll('{{ENF_ISSUE}}', '')
            .replaceAll('{{ENF_RECO}}', '')
            .replaceAll('{{ENG_TABLE_ROWS}}', '')
            .replaceAll('{{ENF_TABLE_ROWS}}', '');

        builtBlocks.write(b);
      }

      progress('Finalizing DOCX…', 0, 1);
      await Future.delayed(Duration.zero);

      final finalDocXml = beforeBlock + builtBlocks.toString() + afterBlock;
      contentTypesXml = _ensureImageContentTypes(contentTypesXml, usedImageExts);

      final newArchive = Archive();
      for (final f in originalArchive.files) {
        if (f.name == 'word/document.xml') continue;
        if (f.name == 'word/_rels/document.xml.rels') continue;
        if (f.name == '[Content_Types].xml') continue;
        newArchive.addFile(ArchiveFile(f.name, f.size, f.content));
      }

      final docBytes = utf8.encode(finalDocXml);
      final relsBytes = utf8.encode(relsXml);
      final ctBytes = utf8.encode(contentTypesXml);

      newArchive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));
      newArchive.addFile(ArchiveFile('word/_rels/document.xml.rels', relsBytes.length, relsBytes));
      newArchive.addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

      for (final mf in extraMediaFiles) {
        newArchive.addFile(mf);
      }

      final outBytes = ZipEncoder().encode(newArchive);
      if (outBytes == null) throw Exception('Failed to encode output DOCX');

      if (outBytes.length < 2 || outBytes[0] != 0x50 || outBytes[1] != 0x4B) {
        throw Exception('Output is not a valid DOCX ZIP (missing PK header).');
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeName = _fileSafe(report.name.isNotEmpty ? report.name : 'RCVA_Report');

      final suffix = (fileSuffix ?? '').trim().isEmpty ? '' : '_${_fileSafe(fileSuffix!)}';
      final outFile = File(p.join(dir.path, '$safeName$suffix.docx'));
      await outFile.writeAsBytes(outBytes, flush: true);

      progress('Done ✅', 1, 1);
      await Future.delayed(Duration.zero);

      return outFile;
    } catch (e, st) {
      _log('❌ EXPORT ERROR: $e');
      _log(st.toString());
      rethrow;
    }
  }

  // ===================== IMAGE PREP =====================

  Future<_ImgReady> _prepareImageForDocx({
    required int index,
    required String? usedPlaceholder,
    required String pathOrUrl,
  }) async {
    if (usedPlaceholder == null) return _ImgReady.empty(index, null);
    if (pathOrUrl.trim().isEmpty) return _ImgReady.empty(index, usedPlaceholder);

    final rawBytes = await _readImageBytes(pathOrUrl);
    if (rawBytes == null || rawBytes.isEmpty) return _ImgReady.empty(index, usedPlaceholder);

    var ext = _guessImageExt(pathOrUrl, rawBytes);
    if (ext == 'webp') return _ImgReady.empty(index, usedPlaceholder);

    final processed = await compute(
      _processImageInIsolate,
      _ImgJob(
        rawBytes: rawBytes,
        ext: ext,
        maxWidth: _maxDocxImageWidth,
        jpegQuality: _jpegQuality,
        pngMaxBytes: _pngMaxBytes,
        smallBypassBytes: _smallImageBypassBytes,
      ),
    );

    if (processed.bytes.isEmpty) return _ImgReady.empty(index, usedPlaceholder);

    return _ImgReady(
      index: index,
      usedPlaceholder: usedPlaceholder,
      bytes: processed.bytes,
      ext: processed.ext,
    );
  }

  static _ImgProc _processImageInIsolate(_ImgJob job) {
    try {
      final input = job.rawBytes;
      var ext = job.ext.toLowerCase();

      // ✅ fast path
      if (input.length < job.smallBypassBytes) {
        if (ext == 'jpeg') ext = 'jpg';
        return _ImgProc(bytes: input, ext: ext);
      }

      final decoded = img.decodeImage(input);
      if (decoded == null) return _ImgProc(bytes: input, ext: ext);

      img.Image out = decoded;

      if (out.width > job.maxWidth) {
        out = img.copyResize(out, width: job.maxWidth);
      }

      if (ext == 'jpg' || ext == 'jpeg') {
        final b = Uint8List.fromList(img.encodeJpg(out, quality: job.jpegQuality));
        return _ImgProc(bytes: b, ext: 'jpg');
      }

      if (ext == 'png') {
        final pngBytes = Uint8List.fromList(img.encodePng(out, level: 6));
        if (pngBytes.length <= job.pngMaxBytes) {
          return _ImgProc(bytes: pngBytes, ext: 'png');
        }
        final jpgBytes = Uint8List.fromList(img.encodeJpg(out, quality: job.jpegQuality));
        return _ImgProc(bytes: jpgBytes, ext: 'jpg');
      }

      final jpg = Uint8List.fromList(img.encodeJpg(out, quality: job.jpegQuality));
      return _ImgProc(bytes: jpg, ext: 'jpg');
    } catch (_) {
      return _ImgProc(bytes: job.rawBytes, ext: job.ext.toLowerCase());
    }
  }

  // ===================== XML HELPERS =====================

  _CellSizeTwips _getCellSizeForPlaceholderTwips(String xml, String placeholder) {
    final idx = xml.indexOf(placeholder);
    if (idx < 0) return const _CellSizeTwips(widthTwips: 5200, heightTwips: 2600);

    final tcStart = _rfindEither(xml, idx, ['<w:tc>', '<w:tc ']);
    if (tcStart < 0) return const _CellSizeTwips(widthTwips: 5200, heightTwips: 2600);

    final tcEnd = xml.indexOf('</w:tc>', idx);
    if (tcEnd < 0) return const _CellSizeTwips(widthTwips: 5200, heightTwips: 2600);

    final tcXml = xml.substring(tcStart, tcEnd + '</w:tc>'.length);

    int widthTwips = 5200;
    final wMatch = RegExp(r'<w:tcW[^>]*w:w="(\d+)"[^>]*/?>').firstMatch(tcXml);
    if (wMatch != null) widthTwips = int.tryParse(wMatch.group(1)!) ?? widthTwips;

    final trStart = _rfindEither(xml, idx, ['<w:tr>', '<w:tr ']);
    int heightTwips = 2600;
    if (trStart >= 0) {
      final trEnd = xml.indexOf('</w:tr>', idx);
      if (trEnd > trStart) {
        final trXml = xml.substring(trStart, trEnd + '</w:tr>'.length);
        final hMatch = RegExp(r'<w:trHeight[^>]*w:val="(\d+)"[^>]*/?>').firstMatch(trXml);
        if (hMatch != null) heightTwips = int.tryParse(hMatch.group(1)!) ?? heightTwips;
      }
    }

    if (widthTwips < 1500) widthTwips = 1500;
    if (heightTwips < 1200) heightTwips = 1200;

    return _CellSizeTwips(widthTwips: widthTwips, heightTwips: heightTwips);
  }

  int _fitCxFromTwips(int wTw) {
    final usable = (wTw - _padTwipsX);
    final tw = usable < 900 ? 900 : usable;
    return tw * _emuPerTwip;
  }

  int _fitCyFromTwips(int hTw) {
    final usable = (hTw - _padTwipsY);
    final tw = usable < 900 ? 900 : usable;
    return tw * _emuPerTwip;
  }

  int _rfindEither(String s, int before, List<String> needles) {
    int best = -1;
    for (final n in needles) {
      final i = s.lastIndexOf(n, before);
      if (i > best) best = i;
    }
    return best;
  }

  String _expandMarkerRowInTwoColumnTableStrict({
    required String blockXml,
    required String marker,
    required String issueKey,
    required String recoKey,
    required List<_Pair> rows,
    required String emptyIssue,
    required String emptyReco,
    required String tag,
  }) {
    final rowTpl = _extractContainingRowStrict(blockXml, marker, issueKey);
    if (rowTpl == null) return blockXml;

    final tplRowXml = rowTpl.rowXml;
    final effective = rows.isEmpty ? [_Pair(emptyIssue, emptyReco)] : rows;

    final built = StringBuffer();
    for (final r in effective) {
      var rowXml = tplRowXml;
      rowXml = rowXml.replaceAll(marker, '');
      rowXml = rowXml.replaceAll(issueKey, _xmlEscape(r.left));
      rowXml = rowXml.replaceAll(recoKey, _xmlEscape(r.right));
      built.write(rowXml);
    }
    return rowTpl.before + built.toString() + rowTpl.after;
  }

  _RowExtract? _extractContainingRowStrict(String xml, String marker, String issueKey) {
    int searchFrom = 0;
    while (true) {
      final markerIdx = xml.indexOf(marker, searchFrom);
      if (markerIdx < 0) return null;

      final trRegex = RegExp(r'<w:tr\b');
      RegExpMatch? lastTr;
      for (final m in trRegex.allMatches(xml)) {
        if (m.start < markerIdx) {
          lastTr = m;
        } else {
          break;
        }
      }
      if (lastTr == null) return null;

      final rowStart = lastTr.start;
      final rowEnd = xml.indexOf('</w:tr>', markerIdx);
      if (rowEnd < 0) return null;

      final endInclusive = rowEnd + '</w:tr>'.length;
      final rowXml = xml.substring(rowStart, endInclusive);

      if (rowXml.contains(marker) && rowXml.contains(issueKey)) {
        return _RowExtract(
          before: xml.substring(0, rowStart),
          rowXml: rowXml,
          after: xml.substring(endInclusive),
        );
      }
      searchFrom = endInclusive;
    }
  }

  String _normCat(String? v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s.isEmpty) return '';
    if (s == 'ENGINEERING' || s.contains('ENGINEER')) return 'ENGINEERING';
    if (s.contains('ENFORCE') || s.contains('POLICE') || s.contains('TRAFFIC') || s.contains('RTO')) {
      return 'ENFORCEMENT';
    }
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
      if (want.isNotEmpty && got.isNotEmpty && got != want) continue;

      out.add(_Pair(
        issue.title.trim().isEmpty ? '-' : issue.title.trim(),
        issue.recommendation.trim().isEmpty ? '-' : issue.recommendation.trim(),
      ));
    }
    return out;
  }

  String _addImageRelationship(String relsXml, String relId, String target) {
    const type = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';
    final relTag = '<Relationship Id="$relId" Type="$type" Target="$target"/>';
    if (relsXml.contains('Id="$relId"')) return relsXml;

    const closeTag = '</Relationships>';
    final idx = relsXml.lastIndexOf(closeTag);
    if (idx == -1) throw Exception('Invalid rels XML: missing </Relationships>');
    return relsXml.substring(0, idx) + relTag + relsXml.substring(idx);
  }

  String _removePlaceholderTextSafely(String xml, String placeholder) {
    var out = xml.replaceAll(placeholder, '');
    out = out.replaceAll(
      RegExp(r'(<w:t[^>]*>)\s*' + RegExp.escape(placeholder) + r'\s*(</w:t>)'),
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
        final before = blockXml.substring(0, closeRunIdx).replaceAll(placeholder, '');
        final after = blockXml.substring(closeRunIdx);
        return before + drawing + after;
      }
    }

    final idx = blockXml.indexOf(placeholder);
    if (idx < 0) return blockXml;

    final closeIdx = blockXml.indexOf('</w:r>', idx);
    if (closeIdx < 0) return blockXml.replaceAll(placeholder, '');

    final before = blockXml.substring(0, closeIdx).replaceAll(placeholder, '');
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

  String _ensureImageContentTypes(String xml, Set<String> usedExts) {
    final exts = usedExts.map((e) => e.toLowerCase()).toSet();

    String addDefaultIfMissing(String xml, String ext, String contentType) {
      final re = RegExp(r'<Default[^>]+Extension="' + RegExp.escape(ext) + r'"[^>]*/?>');
      if (re.hasMatch(xml)) return xml;

      final insertTag = '<Default Extension="$ext" ContentType="$contentType"/>';
      const close = '</Types>';
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

  Future<Uint8List?> _readImageBytes(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      try {
        final res = await http.get(Uri.parse(pathOrUrl)).timeout(const Duration(seconds: 15));
        if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
        return null;
      } catch (_) {
        return null;
      }
    }

    try {
      final f = File(pathOrUrl);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String _guessImageExt(String pathOrUrl, Uint8List bytes) {
    final lower = pathOrUrl.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    return 'jpg';
  }

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
    return Uint8List.fromList(List<int>.from(content as Iterable));
  }

  void _log(String msg) {
    if (kReleaseMode) return;
    // ignore: avoid_print
    print(msg);
  }

  // ✅ Placeholder normalization (split across multiple <w:t>)
  String _normalizeSplitPlaceholdersSafe(String xml) {
    final pRegex = RegExp(r'(<w:p\b[\s\S]*?</w:p>)');
    return xml.replaceAllMapped(pRegex, (m) {
      final para = m.group(1)!;
      return _normalizeWithinParagraph(para);
    });
  }

  String _normalizeWithinParagraph(String paraXml) {
    final tRegex = RegExp(r'(<w:t[^>]*>)([\s\S]*?)(</w:t>)');
    final matches = tRegex.allMatches(paraXml).toList();
    if (matches.isEmpty) return paraXml;

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
    if (!allText.contains('{{')) return paraXml;

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

    for (final seg in segments) {
      out.write(paraXml.substring(cursor, seg.start));
      cursor = seg.end;

      if (bufferOpen.isEmpty) {
        bufferOpen = seg.open;
        bufferText = seg.text;
        bufferClose = seg.close;
      } else {
        bufferText += seg.text;
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
        }
      }
    }

    out.write(paraXml.substring(cursor));
    return out.toString();
  }
}

// ===================== STRUCTS =====================

class _BetweenResult {
  final String before;
  final String inner;
  final String after;
  _BetweenResult({required this.before, required this.inner, required this.after});
}

class _RowExtract {
  final String before;
  final String rowXml;
  final String after;
  _RowExtract({required this.before, required this.rowXml, required this.after});
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

class _CellSizeTwips {
  final int widthTwips;
  final int heightTwips;
  const _CellSizeTwips({required this.widthTwips, required this.heightTwips});
}

class _ImgProc {
  final Uint8List bytes;
  final String ext;
  const _ImgProc({required this.bytes, required this.ext});
}

class _ImgJob {
  final Uint8List rawBytes;
  final String ext;
  final int maxWidth;
  final int jpegQuality;
  final int pngMaxBytes;
  final int smallBypassBytes;

  const _ImgJob({
    required this.rawBytes,
    required this.ext,
    required this.maxWidth,
    required this.jpegQuality,
    required this.pngMaxBytes,
    required this.smallBypassBytes,
  });
}

class _ImgReady {
  final int index;
  final String? usedPlaceholder;
  final Uint8List? bytes;
  final String? ext;

  _ImgReady({
    required this.index,
    required this.usedPlaceholder,
    required this.bytes,
    required this.ext,
  });

  static _ImgReady empty(int index, String? usedPlaceholder) => _ImgReady(
        index: index,
        usedPlaceholder: usedPlaceholder,
        bytes: null,
        ext: null,
      );
}
