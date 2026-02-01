// lib/screens/timestamp_camera_aw.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class TimestampCameraAwScreen extends StatefulWidget {
  const TimestampCameraAwScreen({
    super.key,
    required this.overlayLine1,
    required this.overlayLine2,
    required this.overlayLine3,
  });

  final String overlayLine1;
  final String overlayLine2;
  final String overlayLine3;

  @override
  State<TimestampCameraAwScreen> createState() => _TimestampCameraAwScreenState();
}

class _TimestampCameraAwScreenState extends State<TimestampCameraAwScreen> {
  StreamSubscription<MediaCapture?>? _sub;

  // ✅ live GPS while camera is open
  StreamSubscription<Position>? _posSub;
  Position? _lastPos;

  bool _processing = false;

  final String _logoAsset = 'assets/branding/logo_savelife.png';

  @override
  void initState() {
    super.initState();

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((p) {
      _lastPos = p;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  // ✅ live coords line for overlay + stamp
  String get _liveLine2 {
    final p = _lastPos;
    if (p == null) return widget.overlayLine2;
    return 'Lat: ${p.latitude.toStringAsFixed(6)}, Lng: ${p.longitude.toStringAsFixed(6)}';
  }

  Future<SingleCaptureRequest> _pathBuilder(List<Sensor> sensors) async {
    final tmp = await getTemporaryDirectory();
    final dir = await Directory('${tmp.path}/rcva_cam').create(recursive: true);

    final sensor = sensors.first;
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return SingleCaptureRequest(path, sensor);
  }

  TextStyle _textStyle(double size, {bool bold = false}) {
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

  Future<File> _stampToNewFile(String srcPath) async {
    final src = File(srcPath);
    final bytes = await src.readAsBytes();

    // decode base image (ui.Image)
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image base = frame.image;

    // load logo bytes
    final bd = await rootBundle.load(_logoAsset);
    final Uint8List logoBytes = bd.buffer.asUint8List();

    // decode logo (ui.Image)
    final logoCodec = await ui.instantiateImageCodec(logoBytes);
    final logoFrame = await logoCodec.getNextFrame();
    final ui.Image logo = logoFrame.image;

    final w = base.width.toDouble();
    final h = base.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // draw base
    canvas.drawImage(base, Offset.zero, Paint());

    // ✅ big stamp sizing
    final boxPad = w * 0.030;
    final lineGap = w * 0.012;

    final fontSize = (w * 0.060).clamp(22.0, 64.0).toDouble();
    final smallFont = (fontSize * 0.85).clamp(18.0, 54.0).toDouble();

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: widget.overlayLine1, style: _textStyle(fontSize, bold: true)),
          const TextSpan(text: '\n'),
          TextSpan(text: _liveLine2, style: _textStyle(smallFont)),
          const TextSpan(text: '\n'),
          TextSpan(text: widget.overlayLine3, style: _textStyle(fontSize, bold: true)),
        ],
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.78);

    // ✅ BIGGER logo in stamp (you asked to increase more)
    final logoTargetH = (w * 0.145).clamp(55.0, 130.0).toDouble();
    final logoTargetW = logoTargetH * (logo.width / logo.height);

    final boxW = (tp.width + boxPad * 2).clamp(0.0, w * 0.90).toDouble();
    final boxH = (tp.height + boxPad * 2 + lineGap + logoTargetH).toDouble();

    final right = w - (w * 0.035);
    final bottom = h - (h * 0.045);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(right - boxW, bottom - boxH, boxW, boxH),
      Radius.circular((w * 0.02).toDouble()),
    );

    // box bg
    canvas.drawRRect(rect, Paint()..color = const Color(0xAA000000));

    // text
    tp.paint(canvas, Offset(rect.left + boxPad, rect.top + boxPad));

    // logo bottom-right
    final logoX = rect.right - boxPad - logoTargetW;
    final logoY = rect.bottom - boxPad - logoTargetH;

    final dst = Rect.fromLTWH(logoX, logoY, logoTargetW, logoTargetH);
    final srcRect = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());
    canvas.drawImageRect(logo, srcRect, dst, Paint());

    // finalize image
    final picture = recorder.endRecording();
    final ui.Image stampedUi = await picture.toImage(base.width, base.height);

    // to bytes (PNG)
    final ByteData? pngBd = await stampedUi.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngU8 = pngBd!.buffer.asUint8List();

    // encode JPG using `image` pkg
    final decoded = img.decodePng(pngU8);

    // ✅ slightly lower quality for speed + smaller file
    final jpg = img.encodeJpg(decoded!, quality: 85);

    final tmp = await getTemporaryDirectory();
    final outDir = await Directory('${tmp.path}/rcva_cam').create(recursive: true);
    final outPath = '${outDir.path}/stamped_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final outFile = File(outPath);
    await outFile.writeAsBytes(jpg, flush: true);

    return outFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photo(
          pathBuilder: (sensors) async => _pathBuilder(sensors),
        ),
        previewFit: CameraPreviewFit.cover,
        builder: (CameraState state, AnalysisPreview preview) {
          _sub ??= state.captureState$.listen((event) async {
            if (!mounted) return;

            if (event?.status == MediaCaptureStatus.capturing) {
              setState(() => _processing = true);
            }

            if (event?.status == MediaCaptureStatus.success) {
              try {
                event?.captureRequest.when(
                  single: (single) async {
                    final path = single.file?.path;
                    if (path == null) {
                      if (mounted) setState(() => _processing = false);
                      return;
                    }

                    final stamped = await _stampToNewFile(path);
                    if (!mounted) return;

                    final File? confirmed = await Navigator.push<File?>(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _CapturePreviewScreen(file: stamped),
                      ),
                    );

                    if (!mounted) return;

                    if (confirmed != null) {
                      Navigator.pop(context, confirmed);
                    } else {
                      setState(() => _processing = false);
                    }
                  },
                  multiple: (_) {},
                );
              } catch (_) {
                if (mounted) setState(() => _processing = false);
              }
            }

            if (event?.status == MediaCaptureStatus.failure) {
              if (mounted) setState(() => _processing = false);
            }
          });

          return Stack(
            children: [
              Positioned.fill(child: AwesomeCameraLayout(state: state)),

              // back
              Positioned(
                left: 12,
                top: 12 + MediaQuery.of(context).padding.top,
                child: _RoundIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context, null),
                ),
              ),

              // ✅ overlay preview bottom-right but ABOVE capture button
              Positioned(
                right: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom + 90,
                child: IgnorePointer(
                  child: _MiniOverlayPreview(
                    l1: widget.overlayLine1,
                    l2: _liveLine2,
                    l3: widget.overlayLine3,
                  ),
                ),
              ),

              if (_processing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniOverlayPreview extends StatelessWidget {
  const _MiniOverlayPreview({required this.l1, required this.l2, required this.l3});
  final String l1;
  final String l2;
  final String l3;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      height: 1.1,
      shadows: [Shadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black)],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l1, style: style, textAlign: TextAlign.right),
          const SizedBox(height: 2),
          Text(l2, style: style.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          const SizedBox(height: 2),
          Text(l3, style: style, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _CapturePreviewScreen extends StatelessWidget {
  const _CapturePreviewScreen({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            left: 12,
            top: 12 + top,
            child: _RoundIconButton(
              icon: Icons.close,
              onTap: () => Navigator.pop(context, null),
            ),
          ),
          Positioned(
            right: 12,
            top: 12 + top,
            child: _RoundIconButton(
              icon: Icons.check,
              onTap: () => Navigator.pop(context, file),
            ),
          ),
        ],
      ),
    );
  }
}
