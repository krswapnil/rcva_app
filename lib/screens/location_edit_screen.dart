// lib/screens/location_edit_screen.dart

import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ✅ save to phone gallery + permissions
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/issue_model.dart';
import '../models/location_model.dart';
import '../services/firestore_service.dart';
import '../widgets/issue_multi_select.dart';
import 'issues_master_screen.dart';
import 'timestamp_camera_aw.dart';

class LocationEditArgs {
  final String reportId;
  final String? locationId;

  LocationEditArgs({required this.reportId, this.locationId});
}

class LocationEditScreen extends StatefulWidget {
  static const routeName = '/location-edit';
  final LocationEditArgs args;

  const LocationEditScreen({super.key, required this.args});

  @override
  State<LocationEditScreen> createState() => _LocationEditScreenState();
}

class _LocationEditScreenState extends State<LocationEditScreen>
    with SingleTickerProviderStateMixin {
  final fs = FirestoreService();
  final picker = ImagePicker();

  late final TabController _tab;
  final _formKey = GlobalKey<FormState>();

  final locationNoC = TextEditingController();
  final locationNameC = TextEditingController();
  final policeC = TextEditingController();

  String agency = 'NHAI';
  double? lat;
  double? lng;

  String? resolvedAddress;

  final List<File?> imageFiles = List<File?>.filled(4, null);
  List<String> imagePaths = List<String>.filled(4, '');

  final Map<int, bool> _isStamping = {0: false, 1: false, 2: false, 3: false};

  Map<String, List<String>> imageIssueIdsMap = {
    '0': <String>[],
    '1': <String>[],
    '2': <String>[],
    '3': <String>[],
  };

  List<String> engineeringIssueIds = <String>[];
  List<String> enforcementIssueIds = <String>[];

  bool loading = false;
  bool saving = false;

  late final String _draftKey;

  // ✅ cache logo bytes once
  Uint8List? _logoBytes;

  // ✅ prevent “stuck” while opening Issue Picker
  bool _issuePickerOpen = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _draftKey = 'draft_${DateTime.now().millisecondsSinceEpoch}';
    _warmLogoBytes();
    if (widget.args.locationId != null) _loadExisting();
  }

  Future<void> _warmLogoBytes() async {
    try {
      final bd = await rootBundle.load('assets/branding/logo_savelife.png');
      _logoBytes = bd.buffer.asUint8List();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    locationNoC.dispose();
    locationNameC.dispose();
    policeC.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _currentLocationKey() => widget.args.locationId ?? _draftKey;

  String _monthName(int m) {
    const names = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return names[m - 1];
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$h:$mm:$ss $ampm';
  }

  Future<void> _resolveAddress() async {
    if (lat == null || lng == null) return;

    try {
      final places = await placemarkFromCoordinates(lat!, lng!);
      if (places.isEmpty) return;

      final pm = places.first;

      final parts = <String>[
        (pm.subLocality ?? '').trim(),
        (pm.locality ?? '').trim(),
        (pm.subAdministrativeArea ?? '').trim(),
        (pm.administrativeArea ?? '').trim(),
      ].where((s) => s.isNotEmpty).toList();

      final addr = parts.isEmpty ? null : parts.join(', ');

      if (!mounted) return;
      setState(() => resolvedAddress = addr);
    } catch (_) {}
  }

  Future<Directory> _ensurePhotoDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(
        base.path,
        'rcva',
        'photos',
        widget.args.reportId,
        _currentLocationKey(),
      ),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _copyPhotoToAppFolder({
    required String sourcePath,
    required int index,
  }) async {
    final dir = await _ensurePhotoDir();
    final dstPath = p.join(dir.path, 'photo_${index + 1}.jpg');
    return File(sourcePath).copy(dstPath);
  }

  Future<File> _copyExtraToTemp({required String sourcePath}) async {
    final tmp = await getTemporaryDirectory();
    final outDir = await Directory('${tmp.path}/rcva_extras').create(recursive: true);
    final outPath = '${outDir.path}/extra_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(sourcePath).copy(outPath);
  }

  Future<void> _loadExisting() async {
    setState(() => loading = true);
    try {
      final loc = await fs.getLocation(widget.args.reportId, widget.args.locationId!);
      if (loc == null) return;

      locationNoC.text = loc.locationNo;
      locationNameC.text = loc.locationName;
      policeC.text = loc.policeStation;

      agency = loc.agency;
      lat = loc.lat;
      lng = loc.lng;

      imagePaths = List<String>.from(loc.imagePaths);
      imageIssueIdsMap = {
        '0': List<String>.from(loc.imageIssueIdsMap['0'] ?? []),
        '1': List<String>.from(loc.imageIssueIdsMap['1'] ?? []),
        '2': List<String>.from(loc.imageIssueIdsMap['2'] ?? []),
        '3': List<String>.from(loc.imageIssueIdsMap['3'] ?? []),
      };

      engineeringIssueIds = List<String>.from(loc.engineeringIssueIds);
      enforcementIssueIds = List<String>.from(loc.enforcementIssueIds);

      for (int i = 0; i < 4; i++) {
        final path = imagePaths[i].trim();
        if (path.isEmpty) {
          imageFiles[i] = null;
          continue;
        }
        final f = File(path);
        imageFiles[i] = await f.exists() ? f : null;
      }

      await _resolveAddress();
      setState(() {});
    } catch (e) {
      _snack('Load failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Position?> _getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _snack('Please enable location services');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _snack('Location permission denied');
      return null;
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _captureGpsFast() async {
    final pos = await _getCurrentPosition();
    if (pos == null) return;

    if (!mounted) return;
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
    });

    _resolveAddress();
  }

  Future<void> _saveImageToGallery(File file) async {
    try {
      if (Platform.isAndroid) {
        final photos = await Permission.photos.request();
        final storage = await Permission.storage.request();
        if (!photos.isGranted && !storage.isGranted) {
          _snack('Gallery permission denied');
          return;
        }
      }

      final bytes = await file.readAsBytes();
      await ImageGallerySaver.saveImage(
        bytes,
        quality: 90,
        name: 'RCVA_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {
      _snack('Failed to save to gallery');
    }
  }

  // ------------------ STAMP LINES ------------------
  Map<String, String> _buildStampLines() {
    final now = DateTime.now();
    final line1 =
        '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)} ${now.year}, ${_formatTime(now)}';

    final line2 = (lat != null && lng != null)
        ? 'Lat: ${lat!.toStringAsFixed(6)}, Lng: ${lng!.toStringAsFixed(6)}'
        : 'Lat: -, Lng: -';

    final fallbackParts = <String>[
      locationNameC.text.trim(),
      policeC.text.trim(),
    ].where((e) => e.isNotEmpty).toList();

    final line3 = (resolvedAddress != null && resolvedAddress!.trim().isNotEmpty)
        ? resolvedAddress!.trim()
        : (fallbackParts.isEmpty ? '-' : fallbackParts.join(', '));

    return {'l1': line1, 'l2': line2, 'l3': line3};
  }

  // ------------------ ONE STAMP IMPLEMENTATION (gallery-style) ------------------
  /// ✅ Stamps `filePath` in-place using Canvas drawRRect (same look as gallery)
  Future<void> _stampUiAndOverwriteFile({
    required String filePath,
    required String line1,
    required String line2,
    required String line3,
  }) async {
    final src = File(filePath);
    final bytes = await src.readAsBytes();

    // ✅ downscale decode for speed/memory
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 2200, // adjust 1800–2600
    );
    final frame = await codec.getNextFrame();
    final ui.Image base = frame.image;

    _logoBytes ??=
        (await rootBundle.load('assets/branding/logo_savelife.png')).buffer.asUint8List();

    final logoCodec = await ui.instantiateImageCodec(_logoBytes!);
    final logoFrame = await logoCodec.getNextFrame();
    final ui.Image logo = logoFrame.image;

    final w = base.width.toDouble();
    final h = base.height.toDouble();

    TextStyle textStyle(double size, {bool bold = false}) {
      return TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        height: 1.15,
        shadows: const [
          Shadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black),
        ],
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(base, Offset.zero, Paint());

    final boxPad = w * 0.015;
    final lineGap = w * 0.006;

    final fontSize = (w * 0.030).clamp(14.0, 32.0).toDouble();
    final smallFont = (fontSize * 0.85).clamp(12.0, 28.0).toDouble();

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: line1, style: textStyle(fontSize, bold: true)),
          const TextSpan(text: '\n'),
          TextSpan(text: line2, style: textStyle(smallFont)),
          const TextSpan(text: '\n'),
          TextSpan(text: line3, style: textStyle(fontSize, bold: true)),
        ],
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.78);

    final logoTargetH = (w * 0.0725).clamp(35.0, 70.0).toDouble();
    final logoTargetW = logoTargetH * (logo.width / logo.height);

    final boxW = (tp.width + boxPad * 2).clamp(0.0, w * 0.88).toDouble();
    final boxH = (tp.height + boxPad * 2 + lineGap + logoTargetH).toDouble();

    final right = w - (w * 0.035);
    final bottom = h - (h * 0.045);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(right - boxW, bottom - boxH, boxW, boxH),
      Radius.circular((w * 0.02).toDouble()),
    );

    // ✅ slight transparent background
    canvas.drawRRect(rect, Paint()..color = const Color(0x66000000));

    tp.paint(canvas, Offset(rect.left + boxPad, rect.top + boxPad));

    final logoX = rect.right - boxPad - logoTargetW;
    final logoY = rect.bottom - boxPad - logoTargetH;
    final dst = Rect.fromLTWH(logoX, logoY, logoTargetW, logoTargetH);
    final srcRect = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());
    canvas.drawImageRect(logo, srcRect, dst, Paint());

    final picture = recorder.endRecording();
    final ui.Image stampedUi = await picture.toImage(base.width, base.height);

    final byteData = await stampedUi.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final decoded = img.decodePng(pngBytes);
    final jpgBytes = img.encodeJpg(decoded!, quality: 85);

    await File(filePath).writeAsBytes(jpgBytes, flush: true);
  }

  /// ✅ stamps savedPath and updates UI flags
  Future<void> _stampSavedPhotoWithUi({
    required int index,
    required String savedPath,
    required String line1,
    required String line2,
    required String line3,
  }) async {
    try {
      await _stampUiAndOverwriteFile(
        filePath: savedPath,
        line1: line1,
        line2: line2,
        line3: line3,
      );

      // ✅ force refresh if Image.file cached old bytes
      await FileImage(File(savedPath)).evict();

      if (!mounted) return;

      void applyUiUpdate() {
        if (!mounted) return;
        setState(() {
          imageFiles[index] = File(savedPath);
          imagePaths[index] = savedPath;
          _isStamping[index] = false;
        });
      }

      if (_issuePickerOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 220), applyUiUpdate);
        });
      } else {
        applyUiUpdate();
      }

      await _saveImageToGallery(File(savedPath));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStamping[index] = false);
    }
  }

  // ------------------ photos ------------------
  Future<void> _takePhoto(int index) async {
    _captureGpsFast(); // fire and forget
    final lines = _buildStampLines();

    final Map<String, String>? result = await Navigator.push<Map<String, String>?>(
      context,
      MaterialPageRoute(
        builder: (_) => TimestampCameraAwScreen(
          overlayLine1: lines['l1']!,
          overlayLine2: lines['l2']!,
          overlayLine3: lines['l3']!,
        ),
      ),
    );

    if (result == null) return;

    final rawPath = (result['rawPath'] ?? '').trim();
    if (rawPath.isEmpty) return;

    try {
      final savedFile = await _copyPhotoToAppFolder(
        sourcePath: rawPath,
        index: index,
      );

      // ✅ instant preview
      if (!mounted) return;
      setState(() {
        imageFiles[index] = savedFile;
        imagePaths[index] = savedFile.path;
        _isStamping[index] = true;
      });

      // ✅ stamp in background (do NOT await)
      unawaited(_stampSavedPhotoWithUi(
        index: index,
        savedPath: savedFile.path,
        line1: lines['l1']!,
        line2: lines['l2']!,
        line3: lines['l3']!,
      ));
    } catch (e) {
      _snack('Failed to save photo: $e');
    }
  }

  // ✅ Gallery pick WITH stamp (instant preview + background stamp)
  Future<void> _pickFromGalleryWithStamp(int index) async {
    _captureGpsFast();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    final lines = _buildStampLines();

    try {
      final savedFile = await _copyPhotoToAppFolder(
        sourcePath: picked.path,
        index: index,
      );

      if (!mounted) return;
      setState(() {
        imageFiles[index] = savedFile;
        imagePaths[index] = savedFile.path;
        _isStamping[index] = true;
      });

      unawaited(_stampSavedPhotoWithUi(
        index: index,
        savedPath: savedFile.path,
        line1: lines['l1']!,
        line2: lines['l2']!,
        line3: lines['l3']!,
      ));
    } catch (e) {
      _snack('Failed to upload image: $e');
    }
  }

  // ✅ Gallery pick WITHOUT stamp
  Future<void> _pickFromGalleryNoStamp(int index) async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    try {
      final savedFile = await _copyPhotoToAppFolder(
        sourcePath: picked.path,
        index: index,
      );

      setState(() {
        imageFiles[index] = savedFile;
        imagePaths[index] = savedFile.path;
        _isStamping[index] = false;
      });
    } catch (e) {
      _snack('Failed to upload image: $e');
    }
  }

  // ✅ Extra photo: stamp + save to gallery only
  Future<void> _takeExtraPhotoSaveToGalleryOnly() async {
    _captureGpsFast();

    final lines = _buildStampLines();

    final Map<String, String>? result = await Navigator.push<Map<String, String>?>(
      context,
      MaterialPageRoute(
        builder: (_) => TimestampCameraAwScreen(
          overlayLine1: lines['l1']!,
          overlayLine2: lines['l2']!,
          overlayLine3: lines['l3']!,
        ),
      ),
    );

    if (result == null) return;

    final rawPath = (result['rawPath'] ?? '').trim();
    if (rawPath.isEmpty) return;

    try {
      final tmpCopy = await _copyExtraToTemp(sourcePath: rawPath);

      await _stampUiAndOverwriteFile(
        filePath: tmpCopy.path,
        line1: lines['l1']!,
        line2: lines['l2']!,
        line3: lines['l3']!,
      );

      await _saveImageToGallery(tmpCopy);
      _snack('Extra photo saved to Gallery ✅');
    } catch (e) {
      _snack('Extra photo failed: $e');
    }
  }

  Future<void> _removePhoto(int index) async {
    final existingPath = imagePaths[index];

    setState(() {
      imageFiles[index] = null;
      imagePaths[index] = '';
      imageIssueIdsMap['$index'] = <String>[];
      _isStamping[index] = false;
    });

    try {
      if (existingPath.trim().isNotEmpty) {
        final f = File(existingPath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  // ------------------ issues helpers ------------------
  List<IssueModel> _onlyCategory(List<IssueModel> all, String category) {
    final c = category.trim().toUpperCase();
    return all.where((e) => e.category.trim().toUpperCase() == c).toList();
  }

  Widget _selectedChips({
    required List<IssueModel> options,
    required List<String> selectedIds,
    required ValueChanged<List<String>> onChanged,
  }) {
    final map = {for (final i in options) i.id: i};

    if (selectedIds.isEmpty) {
      return Text(
        'No issues selected',
        style: TextStyle(color: Colors.black.withOpacity(0.6)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selectedIds.map((id) {
        final t = map[id]?.title ?? id;
        return InputChip(
          label: Text(t),
          onDeleted: () {
            final next = List<String>.from(selectedIds)..remove(id);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }

  Future<void> _openIssuePicker({
    required String title,
    required List<IssueModel> options,
    required List<String> selectedIds,
    required ValueChanged<List<String>> onChanged,
  }) async {
    _issuePickerOpen = true;

    final out = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var temp = List<String>.from(selectedIds);

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.80,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, selectedIds),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, temp),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      child: IssueMultiSelect(
                        title: 'Select issues',
                        allIssues: options,
                        selectedIds: temp,
                        onChanged: (ids) => temp = ids,
                        onAddNewIssue: () =>
                            Navigator.pushNamed(context, IssuesMasterScreen.routeName),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    _issuePickerOpen = false;
    if (out == null) return;
    onChanged(out);
  }

  Future<void> _openImageSheet({
    required int index,
    required List<IssueModel> engineeringIssues,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final f = imageFiles[index];

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.80,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Image ${index + 1}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_isStamping[index] == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text(
                            'Stamping…',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 180,
                      color: Colors.black,
                      child: f == null
                          ? const Center(
                              child: Text('No photo selected',
                                  style: TextStyle(color: Colors.white70)),
                            )
                          : Image.file(
                              f,
                              fit: BoxFit.contain,
                              cacheWidth: 1200,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                            ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  if ((resolvedAddress ?? '').trim().isNotEmpty)
                    Text(
                      'Address: ${resolvedAddress!}',
                      style: TextStyle(color: Colors.black.withOpacity(0.70)),
                    ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _openIssuePicker(
                        title: 'Caption issues for Image ${index + 1} (Engineering only)',
                        options: engineeringIssues,
                        selectedIds: imageIssueIdsMap['$index'] ?? [],
                        onChanged: (ids) =>
                            setState(() => imageIssueIdsMap['$index'] = ids),
                      );
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Select caption issues'),
                  ),

                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _takeExtraPhotoSaveToGalleryOnly();
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Take EXTRA photo (save to Gallery only)'),
                  ),

                  const Spacer(),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _takePhoto(index);
                                if (!mounted) return;
                                (ctx as Element).markNeedsBuild();
                              },
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final choice = await showModalBottomSheet<String>(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (_) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.verified_outlined),
                                          title: const Text('Upload WITH stamp'),
                                          onTap: () => Navigator.pop(context, 'with'),
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.hide_image_outlined),
                                          title: const Text('Upload WITHOUT stamp'),
                                          onTap: () => Navigator.pop(context, 'without'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                if (choice == 'with') {
                                  await _pickFromGalleryWithStamp(index);
                                } else if (choice == 'without') {
                                  await _pickFromGalleryNoStamp(index);
                                }

                                if (!mounted) return;
                                (ctx as Element).markNeedsBuild();
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _removePhoto(index);
                            if (!mounted) return;
                            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _imageGridCard(List<IssueModel> engineeringIssues) {
    Widget btn(int index) {
      final has = imagePaths[index].trim().isNotEmpty && imageFiles[index] != null;
      final thumb = imageFiles[index];

      return OutlinedButton(
        onPressed: () => _openImageSheet(index: index, engineeringIssues: engineeringIssues),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 54,
                height: 54,
                color: Colors.black12,
                child: thumb == null
                    ? const Icon(Icons.image, size: 22)
                    : Image.file(
                        thumb,
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? 'Image ${index + 1} ✅' : 'Image ${index + 1}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: btn(0)), const SizedBox(width: 10), Expanded(child: btn(1))]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: btn(2)), const SizedBox(width: 10), Expanded(child: btn(3))]),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    final hasGps = lat != null && lng != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: locationNoC,
                    decoration: const InputDecoration(labelText: 'Location No.', hintText: 'e.g., 01'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: agency,
                    decoration: const InputDecoration(labelText: 'Agency'),
                    items: const [
                      DropdownMenuItem(value: 'NHAI', child: Text('NHAI')),
                      DropdownMenuItem(value: 'PWD', child: Text('PWD')),
                      DropdownMenuItem(value: 'ULB', child: Text('Urban/Local Body')),
                    ],
                    onChanged: (v) => setState(() => agency = v ?? 'NHAI'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: locationNameC,
              decoration: const InputDecoration(labelText: 'Location Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: policeC,
              decoration: const InputDecoration(labelText: 'Police Station (Jurisdiction)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasGps
                        ? 'Lat: ${lat!.toStringAsFixed(6)}  •  Lng: ${lng!.toStringAsFixed(6)}'
                        : 'GPS not captured',
                    style: TextStyle(color: Colors.black.withOpacity(0.7)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _captureGpsFast,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Get GPS'),
                ),
              ],
            ),
            if ((resolvedAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Address: ${resolvedAddress!}',
                  style: TextStyle(color: Colors.black.withOpacity(0.7))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => saving = true);

    try {
      final locationId = widget.args.locationId;

      final model = LocationModel(
        id: locationId ?? '',
        locationNo: locationNoC.text.trim(),
        locationName: locationNameC.text.trim(),
        agency: agency,
        policeStation: policeC.text.trim(),
        details: '',
        lat: lat,
        lng: lng,
        imagePaths: List<String>.from(imagePaths),
        imageIssueIdsMap: {
          '0': List<String>.from(imageIssueIdsMap['0'] ?? []),
          '1': List<String>.from(imageIssueIdsMap['1'] ?? []),
          '2': List<String>.from(imageIssueIdsMap['2'] ?? []),
          '3': List<String>.from(imageIssueIdsMap['3'] ?? []),
        },
        engineeringIssueIds: List<String>.from(engineeringIssueIds),
        enforcementIssueIds: List<String>.from(enforcementIssueIds),
      );

      if (locationId == null) {
        await fs.createLocation(widget.args.reportId, model);
      } else {
        await fs.updateLocation(widget.args.reportId, locationId, model);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.args.locationId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Location' : 'Add Location'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Engineering'), Tab(text: 'Enforcement')],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<IssueModel>>(
              stream: fs.watchAllIssues(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final all = snap.data!;
                final engineeringIssues = _onlyCategory(all, 'ENGINEERING');
                final enforcementIssues = _onlyCategory(all, 'ENFORCEMENT');

                return Stack(
                  children: [
                    Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                            children: [
                              _detailsCard(),
                              const SizedBox(height: 10),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Engineering Issues',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _openIssuePicker(
                                              title: 'Select Engineering Issues',
                                              options: engineeringIssues,
                                              selectedIds: engineeringIssueIds,
                                              onChanged: (ids) => setState(() => engineeringIssueIds = ids),
                                            ),
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _selectedChips(
                                        options: engineeringIssues,
                                        selectedIds: engineeringIssueIds,
                                        onChanged: (ids) => setState(() => engineeringIssueIds = ids),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _imageGridCard(engineeringIssues),
                            ],
                          ),
                          ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Enforcement Issues',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _openIssuePicker(
                                              title: 'Select Enforcement Issues',
                                              options: enforcementIssues,
                                              selectedIds: enforcementIssueIds,
                                              onChanged: (ids) => setState(() => enforcementIssueIds = ids),
                                            ),
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _selectedChips(
                                        options: enforcementIssues,
                                        selectedIds: enforcementIssueIds,
                                        onChanged: (ids) => setState(() => enforcementIssueIds = ids),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            border: const Border(top: BorderSide(color: Colors.black12)),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: saving ? null : _save,
                            icon: const Icon(Icons.save),
                            label: Text(isEdit ? 'Save Changes' : 'Save Location'),
                          ),
                        ),
                      ),
                    ),
                    if (saving)
                      Container(
                        color: Colors.black.withOpacity(0.08),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
