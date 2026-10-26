import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';

class SweepCaptureScreen extends StatefulWidget {
  const SweepCaptureScreen({super.key, required this.state, required this.session});
  final AppState state;
  final AttendanceSession session;
  @override
  State<SweepCaptureScreen> createState() => _SweepCaptureScreenState();
}

class _SweepFrame {
  const _SweepFrame(this.bytes, this.offsetSeconds, this.headingDegrees);
  final Uint8List bytes;
  final double offsetSeconds;
  final double headingDegrees;
}

class _SweepCaptureScreenState extends State<SweepCaptureScreen> {
  CameraController? _camera;
  StreamSubscription<GyroscopeEvent>? _gyro;
  final FlutterTts _tts = FlutterTts();
  final Stopwatch _clock = Stopwatch();
  final List<_SweepFrame> _frames = [];
  Timer? _finishHold;
  Timer? _countdown;
  bool _cameraReady = false;
  bool _cameraLoading = false;
  bool _capturing = false;
  bool _uploading = false;
  bool _practiceDone = true;
  bool _practice = false;
  String _stage = 'idle';
  String? _message;
  double _heading = 0;
  double _startHeading = 0;
  double _headingSpan = 0;
  double? _lastGyroTime;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _selfieHoldAt;

  @override
  void initState() {
    super.initState();
    _loadPracticeState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _listenGyroscope();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.48);
  }

  Future<void> _loadPracticeState() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) setState(() => _practiceDone = preferences.getBool('attendance_sweep_practice_done') ?? false);
  }

  Future<void> _listenGyroscope() async {
    _gyro = gyroscopeEvents.listen((event) {
      if (!_capturing || _lastGyroTime == null) return;
      final now = _clock.elapsedMicroseconds / 1000000.0;
      final deltaSeconds = now - _lastGyroTime!;
      _lastGyroTime = now;
      _heading = (_heading + event.y * deltaSeconds * 180 / math.pi) % 360;
      if (_heading < 0) _heading += 360;
      _headingSpan = ((_heading - _startHeading + 180) % 360 - 180).abs();
      if (mounted) setState(() {});
      if (!_practice && _stage == 'sweep' && _headingSpan >= 150 && _finishHold == null) {
        _stage = 'hold';
        HapticFeedback.mediumImpact();
        _speak('Hold still');
        _finishHold = Timer(const Duration(seconds: 1), _finishCapture);
      }
    }, onError: (_) {
      if (mounted) setState(() => _message = 'Motion sensor unavailable. Retake or use manual roll call.');
    });
  }

  Future<void> _prepareCamera() async {
    if (_cameraLoading) return;
    setState(() => _cameraLoading = true);
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Camera and motion access'),
      content: const Text('The front camera records a short sweep at about five frames per second. Gyroscope headings and frame timing are sent as supporting evidence. Raw frames are deleted after analysis unless a private review filmstrip is needed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
      ],
    ));
    if (accepted != true || !mounted) { if (mounted) setState(() => _cameraLoading = false); return; }
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) { front = camera; break; }
      }
      if (front == null) throw CameraException('front_camera_missing', 'A front camera is required.');
      final controller = CameraController(front, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
      await controller.initialize();
      if (!mounted) { await controller.dispose(); return; }
      setState(() { _camera = controller; _cameraReady = true; });
    } on CameraException catch (error) {
      if (mounted) setState(() => _message = error.description ?? 'Camera permission or initialization failed.');
    } catch (_) {
      if (mounted) setState(() => _message = 'The front camera is unavailable on this device.');
    } finally {
      if (mounted) setState(() => _cameraLoading = false);
    }
  }

  Future<void> _begin({required bool practice}) async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _uploading) return;
    await WakelockPlus.enable();
    _frames.clear();
    _finishHold?.cancel();
    _finishHold = null;
    _practice = practice;
    _capturing = true;
    _stage = 'selfie';
    _message = null;
    _headingSpan = 0;
    _startHeading = _heading;
    _clock..reset()..start();
    _lastGyroTime = 0;
    _selfieHoldAt = DateTime.now();
    await _speak('Start. Hold still');
    HapticFeedback.selectionClick();
    setState(() {});
    try {
      await camera.startImageStream(_onCameraFrame);
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (mounted && _capturing && _stage == 'selfie') {
          _stage = 'sweep';
          _speak('Keep going');
          HapticFeedback.lightImpact();
          setState(() {});
        }
      });
      Timer(const Duration(seconds: 15), () {
        if (_capturing) _finishCapture();
      });
      if (practice) {
        Timer(const Duration(seconds: 5), () { if (_capturing) _finishCapture(); });
      }
    } on CameraException catch (error) {
      _capturing = false;
      _clock.stop();
      await WakelockPlus.disable();
      if (mounted) setState(() => _message = error.description ?? 'Camera stream failed.');
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!_capturing || _frames.length >= 90) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame).inMilliseconds < 200) return;
    _lastFrame = now;
    try {
      final bytes = _encodeJpeg(image);
      _frames.add(_SweepFrame(bytes, _clock.elapsedMicroseconds / 1000000.0, _heading));
      if (_frames.length >= 90 && _stage == 'sweep') _finishCapture();
    } catch (_) {
      if (mounted) setState(() => _message = 'A camera frame could not be encoded. Please retake.');
    }
  }

  Uint8List _encodeJpeg(CameraImage cameraImage) {
    final output = img.Image(width: cameraImage.width, height: cameraImage.height);
    if (cameraImage.planes.length == 1) {
      final plane = cameraImage.planes.first;
      for (var y = 0; y < cameraImage.height; y++) {
        for (var x = 0; x < cameraImage.width; x++) {
          final at = y * plane.bytesPerRow + x * (plane.bytesPerPixel ?? 4);
          output.setPixelRgb(x, y, plane.bytes[at + 2], plane.bytes[at + 1], plane.bytes[at]);
        }
      }
    } else {
      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;
      for (var y = 0; y < cameraImage.height; y++) {
        for (var x = 0; x < cameraImage.width; x++) {
          final yy = yPlane.bytes[y * yPlane.bytesPerRow + x].toDouble();
          final uv = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uvPixelStride;
          final u = uPlane.bytes[uv].toDouble() - 128;
          final v = vPlane.bytes[(y ~/ 2) * vPlane.bytesPerRow + (x ~/ 2) * (vPlane.bytesPerPixel ?? 1)].toDouble() - 128;
          final r = (yy + 1.402 * v).round().clamp(0, 255);
          final g = (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
          final b = (yy + 1.772 * u).round().clamp(0, 255);
          output.setPixelRgb(x, y, r, g, b);
        }
      }
    }
    return Uint8List.fromList(img.encodeJpg(output, quality: 78));
  }

  Future<void> _finishCapture() async {
    if (!_capturing) return;
    _capturing = false;
    _finishHold?.cancel();
    _clock.stop();
    final camera = _camera;
    if (camera?.value.isStreamingImages == true) await camera!.stopImageStream();
    await WakelockPlus.disable();
    HapticFeedback.heavyImpact();
    await _speak('Done');
    if (_practice) {
      _frames.clear();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('attendance_sweep_practice_done', true);
      if (mounted) setState(() { _practiceDone = true; _practice = false; _stage = 'practice_done'; _message = 'Practice complete. Practice frames were not uploaded.'; });
      return;
    }
    if (_frames.isEmpty || _headingSpan < 150) {
      if (mounted) setState(() { _stage = 'idle'; _message = 'Sweep did not reach 150°. Retake or use manual roll call.'; });
      return;
    }
    await _upload();
  }

  Future<void> _upload() async {
    if (_frames.length < 12) {
      setState(() { _stage = 'idle'; _message = 'Too few frames. Hold the phone steady and retake.'; });
      return;
    }
    setState(() { _uploading = true; _stage = 'uploading'; _message = 'Uploading one encrypted-in-transit sweep attempt…'; });
    try {
      final response = await widget.state.api.submitSweep(
        sessionId: widget.session.id,
        attemptId: const Uuid().v4(),
        durationSeconds: _clock.elapsedMicroseconds / 1000000.0,
        frames: _frames.map((frame) => frame.bytes).toList(),
        metadata: _frames.map((frame) => {"offset_seconds": frame.offsetSeconds, "heading_degrees": frame.headingDegrees}).toList(),
      );
      final result = response['status']?.toString();
      final reason = response['reason_code']?.toString() ?? 'unknown';
      _frames.clear();
      if (!mounted) return;
      setState(() {
        _stage = result ?? 'error';
        _message = switch (result) {
          'verified' => 'Attendance marked present.',
          'flagged' => 'Your attempt needs lecturer review. Attendance is pending.',
          'rejected' => _plainReason(reason),
          _ => 'The attempt was received. Refresh for the latest status.',
        };
      });
      await widget.state.loadHome();
    } catch (error) {
      if (mounted) setState(() { _stage = 'idle'; _message = 'Upload failed: $error'; });
    } finally {
      _frames.clear();
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _plainReason(String code) => switch (code) {
    'reject.self_not_matched' => 'We could not match the early selfie. Retake in bright light.',
    'reject.neighbour_not_visible' => 'A nearby classmate was not visible in the opening frames.',
    'reject.lecturer_not_visible' => 'The lecturer was not visible near the end of the sweep.',
    'reject.lecturer_not_matched' => 'The lecturer could not be matched. Ask your lecturer to review manually.',
    'reject.too_few_frames' || 'sweep.too_few_frames' => 'The camera captured too few frames. Retake the sweep.',
    'sweep.heading_span_too_small' => 'The sweep did not cover a wide enough arc. Retake slowly.',
    'review.image_quality_retake' => 'The images were too dark or blurry. Retake in brighter light.',
    _ => 'Attendance could not be verified ($code). You can retake or ask for manual roll call.',
  };

  Future<void> _speak(String phrase) async { try { await _tts.stop(); await _tts.speak(phrase); } catch (_) { SystemSound.play(SystemSoundType.click); } }

  @override
  void dispose() {
    _finishHold?.cancel();
    _countdown?.cancel();
    _gyro?.cancel();
    _camera?.dispose();
    _tts.stop();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.session.timeRemaining;
    final expired = remaining == null || remaining.isNegative || remaining == Duration.zero || widget.session.status != 'open';
    final progress = (_headingSpan / 180).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Mark attendance')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.session.className, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(remaining == null ? 'Session time unavailable' : expired ? 'Attendance window closed' : 'Server-synced time remaining: ${_formatDuration(remaining)}'),
        const SizedBox(height: 16),
        if (_cameraReady && _camera != null)
          ClipRRect(borderRadius: BorderRadius.circular(18), child: AspectRatio(aspectRatio: _camera!.value.aspectRatio, child: CameraPreview(_camera!)))
        else
          Container(height: 280, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(18)), child: Center(child: _message == null ? const CircularProgressIndicator() : Text(_message!, textAlign: TextAlign.center))),
        const SizedBox(height: 18),
        Center(child: SizedBox(width: 90, height: 90, child: CircularProgressIndicator(value: _capturing ? progress : 0, strokeWidth: 8, backgroundColor: Colors.black12))),
        const SizedBox(height: 12),
        Text(_stageLabel, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message!, textAlign: TextAlign.center)),
        const SizedBox(height: 18),
        if (!_practiceDone)
          OutlinedButton.icon(onPressed: _cameraReady && !_capturing ? () => _begin(practice: true) : null, icon: const Icon(Icons.school_outlined), label: const Text('Try a short practice sweep (not uploaded)')),
        FilledButton.icon(
          onPressed: _cameraLoading || _capturing || _uploading || expired ? null : _cameraReady ? () => _begin(practice: false) : _prepareCamera,
          icon: Icon(_capturing ? Icons.motion_photos_on : _cameraReady ? Icons.camera_alt : Icons.camera_front),
          label: Text(_cameraLoading ? 'Opening camera…' : _capturing ? 'Sweep in progress…' : _uploading ? 'Uploading…' : _cameraReady ? 'Start attendance sweep' : 'Enable front camera'),
        ),
        const SizedBox(height: 8),
        const Text('Hold still for one second, then sweep slowly across the room and hold facing the lecturer. Motion headings are supporting evidence, never proof of physical movement.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ])),
    );
  }

  String get _stageLabel => switch (_stage) {
    'selfie' => 'Hold still for the opening selfie frames',
    'sweep' => 'Keep going through a horizontal arc',
    'hold' => 'Hold still facing the lecturer',
    'uploading' => 'Sending one continuous attempt',
    'verified' => 'Verified',
    'flagged' => 'Needs lecturer review',
    'rejected' => 'Retake or ask for manual roll call',
    'practice_done' => 'Practice complete',
    _ => 'Ready when you are',
  };

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 99999);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
