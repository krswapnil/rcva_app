// lib/screens/timestamp_camera_aw.dart

import 'dart:async';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  // ✅ last captured RAW file path
  String? _lastRawPath;

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

  void _confirm() {
    final path = (_lastRawPath ?? '').trim();
    if (path.isEmpty) return;
    Navigator.pop<Map<String, String>>(context, {'rawPath': path});
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.custom(
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          flashMode: FlashMode.auto,
          aspectRatio: CameraAspectRatios.ratio_16_9,
          zoom: 0.0,
        ),
        saveConfig: SaveConfig.photo(
          pathBuilder: (sensors) async => _pathBuilder(sensors),
        ),
        previewFit: CameraPreviewFit.cover,
        builder: (CameraState state, AnalysisPreview preview) {
          _sub ??= state.captureState$.listen((event) async {
            if (!mounted) return;

            if (event?.status == MediaCaptureStatus.success) {
              event?.captureRequest.when(
                single: (single) async {
                  final path = single.file?.path;
                  if (path == null) return;
                  setState(() => _lastRawPath = path);
                },
                multiple: (_) {},
              );
            }
          });

          final hasShot = (_lastRawPath ?? '').isNotEmpty;

          return Stack(
            children: [
              Positioned.fill(
                child: hasShot
                    ? Container(
                        color: Colors.black,
                        child: Image.file(
                          File(_lastRawPath!),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ),
                      )
                    : AwesomeCameraLayout(state: state),
              ),

              Positioned(
                left: 12,
                top: 12 + top,
                child: _RoundIconButton(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context, null),
                ),
              ),

              if (hasShot)
                Positioned(
                  left: 64,
                  top: 12 + top,
                  child: _RoundIconButton(
                    icon: Icons.refresh,
                    onTap: () => setState(() => _lastRawPath = null),
                  ),
                ),

              Positioned(
                right: 12,
                bottom: 12 + bottomPad + 90,
                child: IgnorePointer(
                  child: _MiniOverlayPreview(
                    l1: widget.overlayLine1,
                    l2: _liveLine2,
                    l3: widget.overlayLine3,
                  ),
                ),
              ),

              Positioned(
                right: 12,
                top: 12 + top,
                child: Opacity(
                  opacity: hasShot ? 1.0 : 0.35,
                  child: IgnorePointer(
                    ignoring: !hasShot,
                    child: _RoundIconButton(
                      icon: Icons.check,
                      onTap: _confirm,
                    ),
                  ),
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
  const _MiniOverlayPreview({
    required this.l1,
    required this.l2,
    required this.l3,
  });

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
