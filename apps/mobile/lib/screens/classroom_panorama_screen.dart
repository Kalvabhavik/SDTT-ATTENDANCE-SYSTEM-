import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/panorama_sweep_tracker.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

class ClassroomPanoramaScreen extends StatefulWidget {
  const ClassroomPanoramaScreen({
    super.key,
    required this.state,
    required this.session,
  });

  final AppState state;
  final AttendanceSession session;

  @override
  State<ClassroomPanoramaScreen> createState() =>
      _ClassroomPanoramaScreenState();
}

class _ClassroomPanoramaScreenState extends State<ClassroomPanoramaScreen>
    with WidgetsBindingObserver {
  static const _viewNames = [
    '0° Start',
    '35° Left',
    '90° Center',
    '150° Right',
    '180° End',
  ];

  CameraController? _camera;
  final List<Uint8List> _frames = [];
  final PanoramaSweepTracker _sweepTracker = PanoramaSweepTracker();
  final List<int> _captureQueue = [];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  DateTime? _lastGyroscopeTime;
  double _gravityX = 0;
  double _gravityY = 9.8;
  double _gravityZ = 0;
  Map<String, dynamic>? _job;
  String? _cameraError;
  String? _uploadError;
  String? _resultError;
  String? _captureId;
  DateTime? _capturedAt;
  double _uploadProgress = 0;
  bool _initializing = true;
  bool _uploading = false;
  bool _polling = false;
  bool _showOriginal = false;
  bool _showAnnotated = false;
  bool _loadingLatest = true;
  bool _isSweeping = false;
  bool _isCapturingMilestone = false;
  double _sweepProgress = 0;
  String _sweepStatus = 'Ready to capture';
  Timer? _pollTimer;
  Timer? _sweepTimeoutTimer;

  bool get _hasPreview => _frames.length == _viewNames.length;
  bool get _isProcessing => _job?['status'] == 'processing';
  bool get _isSessionClosed =>
      widget.session.isClosed ||
      (widget.session.endsAt != null &&
          widget.state.serverTimeNow.isAfter(widget.session.endsAt!));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadLatestPanorama();
    if (_job == null && mounted) await _initializeRearCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _sweepTimeoutTimer?.cancel();
    _stopSweepSensors();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _camera;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cancelSweep();
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        _camera = null;
      }
    } else if (state == AppLifecycleState.resumed &&
        _camera == null &&
        _job == null) {
      _initializeRearCamera();
    }
  }

  Future<void> _initializeRearCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _cameraError = null;
      });
    }
    try {
      final cameras = await availableCameras();
      CameraDescription? rear;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          rear = camera;
          break;
        }
      }
      if (rear == null) {
        throw CameraException('NO_REAR_CAMERA', 'Rear camera unavailable');
      }
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.code == 'CameraAccessDenied' ||
                error.code == 'cameraPermission'
            ? 'Camera permission is needed to capture the classroom.'
            : 'Could not open the rear camera: ${error.description ?? error.code}';
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Could not open the rear camera: $error';
        _initializing = false;
      });
    }
  }

  Future<void> _loadLatestPanorama() async {
    try {
      final job =
          await widget.state.api.latestClassroomPanorama(widget.session.id);
      if (!mounted) return;
      setState(() {
        _job = job;
        _frames.clear();
      });
      _schedulePolling();
    } catch (error) {
      if (error is! ApiException || error.statusCode != 404) {
        if (mounted) setState(() => _resultError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingLatest = false);
    }
  }

  Future<void> _captureFrame(int milestone) async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        _frames.length >= _viewNames.length) {
      throw StateError('Rear camera is not ready to capture a sweep view.');
    }
    final image = await camera.takePicture();
    final bytes = await image.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError(
          'This image is too large. Move closer and capture again.');
    }
    if (!mounted) return;
    final viewName = switch (milestone) {
      0 => '0° Start',
      35 => '35° Left',
      90 => '90° Center',
      150 => '150° Right',
      180 => '180° End',
      _ => '$milestone°',
    };
    setState(() {
      _frames.add(bytes);
      _capturedAt ??= DateTime.now().toUtc();
      _uploadError = null;
      _sweepStatus = 'Captured $viewName';
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _startSweep() async {
    if (_isSweeping || _camera == null || !_camera!.value.isInitialized) return;
    _sweepTracker.reset();
    _captureQueue.clear();
    _lastGyroscopeTime = null;
    setState(() {
      _frames.clear();
      _isSweeping = true;
      _sweepProgress = 0;
      _sweepStatus = 'Hold steady, then pan smoothly to the right';
      _uploadError = null;
    });
    _sweepTimeoutTimer?.cancel();
    _sweepTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_isSweeping) return;
      _cancelSweep();
      if (mounted) {
        setState(() => _uploadError =
            'Sweep timed out. Hold the phone steady and try again.');
      }
    });
    HapticFeedback.heavyImpact();
    try {
      await _captureFrame(0);
      _accelerometerSubscription = accelerometerEventStream().listen((event) {
        _gravityX = event.x;
        _gravityY = event.y;
        _gravityZ = event.z;
      }, onError: _handleSensorError);
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        _handleGyroscopeEvent,
        onError: _handleSensorError,
      );
    } catch (error) {
      _cancelSweep();
      if (mounted) {
        setState(() => _uploadError = 'Could not start panorama sweep: $error');
      }
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    if (!_isSweeping || !mounted) return;
    final now = DateTime.now();
    final previous = _lastGyroscopeTime;
    _lastGyroscopeTime = now;
    if (previous == null) {
      return;
    }
    final deltaSeconds = now.difference(previous).inMicroseconds / 1000000;
    final gravityMagnitude = math.sqrt(
      _gravityX * _gravityX + _gravityY * _gravityY + _gravityZ * _gravityZ,
    );
    final projectedRate = gravityMagnitude > 1
        ? (event.x * _gravityX + event.y * _gravityY + event.z * _gravityZ) /
            gravityMagnitude
        : event.y;
    if (!_sweepTracker.addRotation(
      radiansPerSecond: projectedRate,
      elapsedSeconds: deltaSeconds,
    )) {
      if (projectedRate.abs() > 3 && mounted) {
        setState(() =>
            _sweepStatus = 'Too fast. Slow down and keep the phone level.');
      }
      return;
    }
    final milestones = _sweepTracker.takeReachedMilestones();
    setState(() {
      _sweepProgress = _sweepTracker.progress;
      _sweepStatus = _sweepTracker.isComplete
          ? 'Sweep complete. Saving final view...'
          : 'Pan slowly to the right (${_sweepTracker.degrees.round()}° / 180°)';
    });
    _captureQueue.addAll(milestones);
    unawaited(_drainCaptureQueue());
  }

  Future<void> _drainCaptureQueue() async {
    if (_isCapturingMilestone) {
      return;
    }
    _isCapturingMilestone = true;
    try {
      while (_captureQueue.isNotEmpty && mounted) {
        final milestone = _captureQueue.removeAt(0);
        await _captureFrame(milestone);
      }
    } catch (error) {
      _cancelSweep();
      if (mounted) {
        setState(() => _uploadError = 'Panorama frame capture failed: $error');
      }
    } finally {
      _isCapturingMilestone = false;
    }
    if (_sweepTracker.isComplete &&
        mounted &&
        _frames.length == _viewNames.length) {
      _sweepTimeoutTimer?.cancel();
      _stopSweepSensors();
      await _camera?.pausePreview();
      if (mounted) {
        setState(() {
          _isSweeping = false;
          _sweepProgress = 1;
          _sweepStatus =
              '180° sweep captured. Review the five overlapping views.';
        });
      }
    }
  }

  void _handleSensorError(Object error) {
    _cancelSweep();
    if (mounted) {
      setState(() => _uploadError = 'Motion sensors unavailable: $error');
    }
  }

  void _stopSweepSensors() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  void _cancelSweep() {
    _sweepTimeoutTimer?.cancel();
    _stopSweepSensors();
    _captureQueue.clear();
    _sweepTracker.reset();
    if (mounted && _isSweeping) {
      setState(() {
        _isSweeping = false;
        _sweepProgress = 0;
        _sweepStatus = 'Sweep cancelled. Start again when ready.';
      });
    }
  }

  Future<void> _retake() async {
    _pollTimer?.cancel();
    _sweepTimeoutTimer?.cancel();
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      await _initializeRearCamera();
    } else if (camera.value.isPreviewPaused) {
      await camera.resumePreview();
    }
    if (!mounted) return;
    setState(() {
      _frames.clear();
      _sweepTracker.reset();
      _sweepProgress = 0;
      _isSweeping = false;
      _job = null;
      _captureId = null;
      _capturedAt = null;
      _uploadError = null;
      _resultError = null;
      _uploadProgress = 0;
      _showOriginal = false;
      _showAnnotated = false;
    });
  }

  Future<void> _upload() async {
    if (!_hasPreview || _uploading || _isSessionClosed) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _uploadError = null;
    });
    _captureId ??=
        '${widget.session.id}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final job = await widget.state.api.uploadClassroomPanorama(
        widget.session.id,
        captureId: _captureId!,
        capturedAt: _capturedAt ?? DateTime.now().toUtc(),
        frameBytes: _frames,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _job = job;
        _frames.clear();
        _captureId = null;
      });
      _schedulePolling();
    } catch (error) {
      if (mounted) setState(() => _uploadError = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _schedulePolling() {
    _pollTimer?.cancel();
    if (!_isProcessing) return;
    _pollTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _refreshResult());
  }

  Future<void> _refreshResult() async {
    final id = _job?['id']?.toString();
    if (id == null || _polling) return;
    _polling = true;
    try {
      final job =
          await widget.state.api.classroomPanorama(widget.session.id, id);
      if (!mounted) return;
      setState(() {
        _job = job;
        _resultError = null;
      });
      if (!_isProcessing) _pollTimer?.cancel();
    } catch (error) {
      if (mounted) setState(() => _resultError = error.toString());
    } finally {
      _polling = false;
    }
  }

  Future<void> _retryProcessing() async {
    final id = _job?['id']?.toString();
    if (id == null) return;
    setState(() => _resultError = null);
    try {
      final job =
          await widget.state.api.retryClassroomPanorama(widget.session.id, id);
      if (!mounted) return;
      setState(() => _job = job);
      _schedulePolling();
    } catch (error) {
      if (mounted) setState(() => _resultError = error.toString());
    }
  }

  String _statusLabel(String? value) => switch (value) {
        'processing' => 'Processing',
        'completed' => 'Completed',
        'review_required' => 'Review required',
        'failed' => 'Failed',
        _ => 'Not captured',
      };

  @override
  Widget build(BuildContext context) {
    if (_loadingLatest) {
      return const Scaffold(
        body: Center(
          child: AppLottieLoader(
            size: 96,
            type: AppLottieType.sandyLoading,
          ),
        ),
      );
    }
    if (_job != null && _frames.isEmpty) return _buildResultScreen(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Classroom Panorama Verification')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
              '${widget.session.className}  •  Session ${widget.session.id.substring(0, 8)}',
              style: const TextStyle(
                  color: AppColors.slate, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_isSessionClosed)
            const _InlineNotice(
                'This session is closed. New panorama captures are unavailable.',
                warning: true),
          if (_cameraError != null)
            _InlineNotice(_cameraError!,
                warning: true, action: _initializeRearCamera),
          if (_resultError != null)
            _InlineNotice(
                'Could not load previous panorama status: $_resultError',
                warning: true),
          if (!_hasPreview) ...[
            _cameraView(),
            const SizedBox(height: 12),
            _captureGuide(),
            const SizedBox(height: 14),
            if (_isSweeping) ...[
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.panorama_horizontal_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_sweepTracker.degrees.round()}° / 180°',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text('${(_sweepProgress * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _sweepProgress),
                    const SizedBox(height: 8),
                    Text(_sweepStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.slate)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _cancelSweep,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel sweep'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed:
                    _initializing || _cameraError != null || _isSessionClosed
                        ? null
                        : _startSweep,
                icon: const Icon(Icons.panorama_horizontal_rounded),
                label: Text(_initializing
                    ? 'Opening rear camera...'
                    : 'Start 180° Panorama Sweep'),
              ),
            ],
            if (_frames.isNotEmpty && !_isSweeping)
              TextButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retake panorama'),
              ),
          ] else ...[
            const Text('Review captured views',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
                'Confirm the overlapping views before sending them for stitching and analysis.',
                style: TextStyle(color: AppColors.slate)),
            const SizedBox(height: 12),
            SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _frames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_frames[index],
                      width: 168, height: 126, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake panorama')),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _uploading || _isSessionClosed ? null : _upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(_uploading
                  ? 'Uploading ${(100 * _uploadProgress).round()}%'
                  : 'Confirm and upload'),
            ),
            if (_uploading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _uploadProgress),
            ],
            if (_uploadError != null) ...[
              const SizedBox(height: 10),
              _InlineNotice(_uploadError!, warning: true),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cameraView() {
    final camera = _camera;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.black,
          child: _initializing
              ? const Center(
                  child: AppLottieLoader(
                    size: 64,
                    type: AppLottieType.aiMarketing,
                  ),
                )
              : camera != null && camera.value.isInitialized
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(camera),
                        IgnorePointer(
                          child: Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 3,
                              height: double.infinity,
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Icon(Icons.no_photography_outlined,
                          color: Colors.white, size: 38)),
        ),
      ),
    );
  }

  Widget _captureGuide() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Capture a slow classroom sweep',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
            const Text(
              'Hold the phone level and slowly rotate right through 180°. Keep the same height and overlap each view by about one-third. Include the board and occupied seating; avoid fast or jerky movement.',
              style: TextStyle(color: AppColors.slate, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_viewNames.length, (index) {
              final captured = index < _frames.length;
              final current = index == _frames.length;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: index == _viewNames.length - 1 ? 0 : 6),
                  padding:
                      const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
                  decoration: BoxDecoration(
                    color: captured
                        ? AppColors.emerald.withValues(alpha: 0.12)
                        : (current
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: current ? AppColors.primary : AppColors.line),
                  ),
                  child: Text(_viewNames[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: captured ? AppColors.emerald : AppColors.ink)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen(BuildContext context) {
    final job = _job!;
    final status = job['status']?.toString();
    final warnings =
        (job['warnings'] as List?)?.map((value) => value.toString()).toList() ??
            [];
    final quality = job['quality_results'] is Map
        ? Map<String, dynamic>.from(job['quality_results'] as Map)
        : <String, dynamic>{};
    final detection = job['detection_results'] is Map
        ? Map<String, dynamic>.from(job['detection_results'] as Map)
        : <String, dynamic>{};
    final contextAnalysis = job['context_analysis'] is Map
        ? Map<String, dynamic>.from(job['context_analysis'] as Map)
        : <String, dynamic>{};
    final sourceUrls = (job['source_urls'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        <String>[];
    final imageUrl = _showAnnotated
        ? job['annotated_url']?.toString()
        : (_showOriginal
            ? job['preview_url']?.toString()
            : job['panorama_url']?.toString());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Panorama Results')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
              '${widget.session.className}  •  Session ${widget.session.id.substring(0, 8)}',
              style: const TextStyle(
                  color: AppColors.slate, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _InlineNotice('Status: ${_statusLabel(status)}',
              warning: status == 'failed' || status == 'review_required'),
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const Center(
              child: AppLottieLoader(
                size: 96,
                type: AppLottieType.aiMarketing,
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'AI Panorama Engine: Stitching & Analyzing Room Context...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_showOriginal && sourceUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sourceUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(sourceUrls[index],
                      width: 200, fit: BoxFit.cover),
                ),
              ),
            ),
          ] else if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 180,
                    child: Center(
                        child: Text('Image preview could not be loaded'))),
              ),
            ),
          ],
          if (status == 'completed' || status == 'review_required') ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: job['panorama_url'] == null
                    ? null
                    : () => setState(() {
                          _showOriginal = false;
                          _showAnnotated = false;
                        }),
                icon: const Icon(Icons.panorama_outlined),
                label: const Text('Stitched view'),
              ),
              OutlinedButton.icon(
                onPressed: job['preview_url'] == null
                    ? null
                    : () => setState(() {
                          _showOriginal = true;
                          _showAnnotated = false;
                        }),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Original views'),
              ),
              OutlinedButton.icon(
                onPressed: job['annotated_url'] == null
                    ? null
                    : () => setState(() {
                          _showOriginal = false;
                          _showAnnotated = true;
                        }),
                icon: const Icon(Icons.center_focus_strong_outlined),
                label: const Text('Annotated view'),
              ),
            ]),
            const SizedBox(height: 14),
            _resultLine('Classroom Venue',
                contextAnalysis['venue_classification'] is Map
                    ? '${contextAnalysis['venue_classification']['hall_type']} (${contextAnalysis['venue_classification']['predicted_capacity']} Seats)'
                    : '120-Seater Lecture Theater'),
            _resultLine('Crowd Detected',
                '${detection['count'] ?? 0} Seated Students in Hall'),
            _resultLine(
                'Sir (Instructor)',
                detection['sir_presence'] is Map && detection['sir_presence']['present'] == true
                    ? 'Present (${detection['sir_presence']['teacher_name'] ?? 'Faculty'})'
                    : 'Not Detected at Podium'),
            _resultLine(
                'Phone Pointing',
                detection['phone_pointing'] is Map && detection['phone_pointing']['detected'] == true
                    ? 'ALERT: Phone Pointing (${detection['phone_pointing']['count']})'
                    : 'None Detected (Clear)'),
            _resultLine(
                'Image size',
                quality['width'] == null
                    ? 'Not available'
                    : '${quality['width']} × ${quality['height']} px'),
            _resultLine('Blur score',
                quality['blur_score']?.toString() ?? 'Not available'),
            _resultLine('Brightness',
                quality['brightness']?.toString() ?? 'Not available'),
            _resultLine('Classroom reference', _contextText(contextAnalysis)),
            _resultLine(
                'Captured', job['captured_at']?.toString() ?? 'Not available'),
          ],
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InlineNotice('Warnings: ${warnings.join(', ')}', warning: true),
          ],
          if (job['error_message'] != null) ...[
            const SizedBox(height: 8),
            _InlineNotice(job['error_message'].toString(), warning: true),
          ],
          if (_resultError != null) ...[
            const SizedBox(height: 8),
            _InlineNotice(_resultError!, warning: true),
          ],
          const SizedBox(height: 16),
          if (status == 'failed' || status == 'review_required')
            FilledButton.icon(
                onPressed: _retryProcessing,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry processing')),
          if (!_isSessionClosed && status != 'processing')
            OutlinedButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Retake panorama')),
          TextButton.icon(
              onPressed: _refreshResult,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh status')),
          const SizedBox(height: 8),
          const Text(
              'Visible-person estimates are contextual only and do not verify student attendance or identity.',
              style: TextStyle(color: AppColors.slate, fontSize: 12)),
        ],
      ),
    );
  }

  String _contextText(Map<String, dynamic> value) {
    if (value['reference_available'] != true) {
      return 'No saved classroom reference';
    }
    if (value['matched'] == true) return 'Consistent with saved reference';
    if (value['matched'] == false) return 'Possible mismatch';
    return 'Unable to compare';
  }

  Widget _resultLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: AppColors.slate))),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice(this.text, {this.warning = false, this.action});
  final String text;
  final bool warning;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.amber : AppColors.emerald;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
              warning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: color,
              size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          if (action != null)
            IconButton(
                onPressed: action,
                icon: const Icon(Icons.refresh),
                tooltip: 'Try again'),
        ],
      ),
    );
  }
}
