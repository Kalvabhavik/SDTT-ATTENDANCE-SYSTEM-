import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

enum VerificationStep {
  liveFace,
  classroomRoom,
  verifying,
  result,
}

enum LivenessStage {
  center,
  turnLeft,
  turnRight,
  blink,
  completed,
}

class LiveFaceVerificationScreen extends StatefulWidget {
  const LiveFaceVerificationScreen({
    super.key,
    required this.state,
    required this.session,
    this.initialCameraPermissionDenied = false,
    this.initialCameraUnavailable = false,
    this.initialCameraStreamInterrupted = false,
    this.initialStep,
    this.initialResult,
    this.initialErrorCode,
    this.initialErrorMessage,
  });

  final AppState state;
  final AttendanceSession session;
  final bool initialCameraPermissionDenied;
  final bool initialCameraUnavailable;
  final bool initialCameraStreamInterrupted;
  final VerificationStep? initialStep;
  final AttendanceVerifyResult? initialResult;
  final String? initialErrorCode;
  final String? initialErrorMessage;

  @override
  State<LiveFaceVerificationScreen> createState() =>
      _LiveFaceVerificationScreenState();
}

class _LiveFaceVerificationScreenState
    extends State<LiveFaceVerificationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _cameraPermissionError = false;
  bool _cameraPermissionDenied = false;
  bool _cameraUnavailable = false;
  bool _cameraStreamInterrupted = false;

  VerificationStep _currentStep = VerificationStep.liveFace;
  LivenessStage _livenessStage = LivenessStage.center;

  // Captured images for multi-action active liveness
  XFile? _facePhoto;    // Frontal
  XFile? _faceLeft;     // Left turn
  XFile? _faceRight;    // Right turn
  XFile? _faceBlink;    // Eye blink
  XFile? _roomPhoto;

  // Liveness animation and verification state
  late AnimationController _scannerAnim;
  bool _challengeRecorded = false; // Client pose actions captured
  bool _livenessPassed = false;    // Genuine backend verification result ONLY
  bool _isProcessing = false;
  String? _errorMessage;
  String? _errorCode;
  AttendanceVerifyResult? _result;

  bool get _isQualityFailure {
    if (_errorCode == null) return false;
    final code = _errorCode!.toUpperCase();
    return code == 'IMAGE_BLURRY' ||
        code == 'POOR_LIGHTING' ||
        code == 'EXCESSIVE_EXPOSURE' ||
        code == 'BACKLIGHTING_DETECTED' ||
        code == 'NO_FACE_DETECTED' ||
        code == 'MULTIPLE_FACES' ||
        code == 'FACE_TOO_SMALL' ||
        code == 'FACE_OUT_OF_BOUNDS' ||
        code == 'UNSUPPORTED_FORMAT' ||
        code == 'CORRUPTED_IMAGE' ||
        code == 'EMPTY_IMAGE' ||
        code == 'IMAGE_TOO_LARGE' ||
        code == 'IMAGE_TOO_SMALL';
  }

  bool get _isNetworkError {
    if (_errorCode == null) return false;
    final code = _errorCode!.toUpperCase();
    return code == 'TIMEOUT' || code == 'NETWORK_DISCONNECT';
  }

  Timer? _countdownTimer;
  int _secondsLeft = 3;

  // Hardware IMU Sensor Panorama Tracking
  bool _isSweeping = false;
  double _sweepProgress = 0.0;
  double _accumulatedDegrees = 0.0;
  DateTime? _lastGyroTime;
  double _lastAccelX = 0.0;
  double _lastAccelY = 9.8;
  double _lastAccelZ = 0.0;
  String _sweepStatusMessage = 'Hold phone upright • Pan right across classroom';
  bool _sliceCaptured30 = false;
  bool _sliceCaptured90 = false;
  bool _sliceCaptured150 = false;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  final List<XFile> _panoramaFrames = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (widget.initialCameraPermissionDenied) {
      _cameraPermissionDenied = true;
      _cameraPermissionError = true;
    }
    if (widget.initialCameraUnavailable) {
      _cameraUnavailable = true;
      _cameraPermissionError = true;
    }
    if (widget.initialCameraStreamInterrupted) {
      _cameraStreamInterrupted = true;
      _cameraPermissionError = true;
    }
    if (widget.initialStep != null) {
      _currentStep = widget.initialStep!;
    }
    if (widget.initialResult != null) {
      _result = widget.initialResult;
      _livenessPassed = _result!.livenessPassed && _result!.isPresent;
    }
    if (widget.initialErrorCode != null) {
      _errorCode = widget.initialErrorCode;
    }
    if (widget.initialErrorMessage != null) {
      _errorMessage = widget.initialErrorMessage;
    }

    if (!widget.initialCameraPermissionDenied &&
        !widget.initialCameraUnavailable &&
        !widget.initialCameraStreamInterrupted &&
        widget.initialStep != VerificationStep.result) {
      _initCamera();
    }
  }

  void _startAutoScanCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        if (_currentStep == VerificationStep.liveFace && !_challengeRecorded && !_isProcessing) {
          _advanceLivenessStage();
        }
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _initCamera() async {
    setState(() {
      _cameraPermissionError = false;
      _cameraPermissionDenied = false;
      _cameraUnavailable = false;
      _cameraStreamInterrupted = false;
    });
    try {
      _cameras = await availableCameras().timeout(const Duration(seconds: 2));
      if (_cameras.isEmpty) {
        setState(() {
          _cameraUnavailable = true;
          _cameraPermissionError = true;
        });
        return;
      }

      // Default to front camera for face detection
      int frontIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontIndex == -1) frontIndex = 0;
      _selectedCameraIndex = frontIndex;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } on TimeoutException {
      debugPrint('Camera init timed out');
      if (mounted) {
        setState(() {
          _cameraUnavailable = true;
          _cameraPermissionError = true;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera init CameraException: ${e.code} ${e.description}');
      if (mounted) {
        setState(() {
          _cameraPermissionError = true;
          if (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt' ||
              e.code == 'CameraAccessRestricted') {
            _cameraPermissionDenied = true;
          } else {
            _cameraUnavailable = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        setState(() {
          _cameraPermissionError = true;
          if (errStr.contains('permission') || errStr.contains('denied')) {
            _cameraPermissionDenied = true;
          } else {
            _cameraUnavailable = true;
          }
        });
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    final prev = _cameraController;
    if (prev != null) {
      _cameraController = null;
      await prev.dispose();
      await Future.delayed(const Duration(milliseconds: 250));
    }

    // Default preview stream format (YUV420 on Android) ensures hardware compatibility
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _cameraPermissionError = false;
        _cameraPermissionDenied = false;
        _cameraUnavailable = false;
        _cameraStreamInterrupted = false;
      });

      if (_currentStep == VerificationStep.liveFace && !_livenessPassed) {
        _startAutoScanCountdown();
      }
    } on CameraException catch (e) {
      debugPrint('Controller CameraException: ${e.code} ${e.description}');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraPermissionError = true;
          if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt') {
            _cameraPermissionDenied = true;
          } else {
            _cameraUnavailable = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Controller init error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraPermissionError = true;
          _cameraUnavailable = true;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.inactive || appState == AppLifecycleState.paused) {
      _countdownTimer?.cancel();
      if (_isSweeping) {
        _cancelPanoramaSweep();
      }
      final cameraController = _cameraController;
      if (cameraController != null && cameraController.value.isInitialized) {
        _cameraController?.dispose();
        _cameraController = null;
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
            _cameraStreamInterrupted = true;
          });
        }
      }
    } else if (appState == AppLifecycleState.resumed) {
      if (!_cameraPermissionDenied && !_cameraUnavailable && _cameraStreamInterrupted) {
        if (_cameras.isNotEmpty) {
          _setupCameraController(_cameras[_selectedCameraIndex]);
        } else {
          _initCamera();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    _countdownTimer?.cancel();
    _scannerAnim.dispose();
    _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVE LIVENESS CONFIRMATION (CENTER -> TURN LEFT -> TURN RIGHT -> BLINK)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _advanceLivenessStage() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      XFile? photo;
      if (_isCameraInitialized && _cameraController != null) {
        photo = await _cameraController!.takePicture();
      } else {
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1280,
          maxHeight: 1280,
        );
      }

      if (photo == null) {
        setState(() => _isProcessing = false);
        return;
      }

      try {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}

      if (_livenessStage == LivenessStage.center) {
        _facePhoto = photo;
        setState(() {
          _livenessStage = LivenessStage.turnLeft;
          _isProcessing = false;
          _secondsLeft = 3;
        });
        _startAutoScanCountdown();
      } else if (_livenessStage == LivenessStage.turnLeft) {
        _faceLeft = photo;
        setState(() {
          _livenessStage = LivenessStage.turnRight;
          _isProcessing = false;
          _secondsLeft = 3;
        });
        _startAutoScanCountdown();
      } else if (_livenessStage == LivenessStage.turnRight) {
        _faceRight = photo;
        setState(() {
          _livenessStage = LivenessStage.blink;
          _isProcessing = false;
          _secondsLeft = 3;
        });
        _startAutoScanCountdown();
      } else if (_livenessStage == LivenessStage.blink) {
        _faceBlink = photo;
        _countdownTimer?.cancel();
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}

        setState(() {
          _livenessStage = LivenessStage.completed;
          _challengeRecorded = true;
          _isProcessing = false;
        });

        // Advance to classroom panorama step
        await Future.delayed(const Duration(milliseconds: 700));

        if (mounted) {
          int backIndex = _cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
          );
          if (backIndex != -1 && backIndex != _selectedCameraIndex) {
            _selectedCameraIndex = backIndex;
            await _setupCameraController(_cameras[_selectedCameraIndex]);
          }

          setState(() {
            _currentStep = VerificationStep.classroomRoom;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Could not capture face frame: $e';
        });
      }
    }
  }

  Future<void> _captureFace() => _advanceLivenessStage();

  // ─────────────────────────────────────────────────────────────────────────
  // CLASSROOM ROOM / 180° PANORAMA SWEEP CAPTURE
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // CLASSROOM ROOM / 180° PANORAMA SWEEP CAPTURE (HARDWARE IMU SENSORS)
  // ─────────────────────────────────────────────────────────────────────────
  void _startPanoramaSweep() {
    if (_isSweeping || _isProcessing) return;

    setState(() {
      _isSweeping = true;
      _sweepProgress = 0.0;
      _accumulatedDegrees = 0.0;
      _lastGyroTime = null;
      _sliceCaptured30 = false;
      _sliceCaptured90 = false;
      _sliceCaptured150 = false;
      _sweepStatusMessage = 'Ready • Rotate your phone to the right across classroom';
      _errorMessage = null;
    });

    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    _panoramaFrames.clear();

    // Capture initial frame at 0°
    _captureSliceFrame('0° Left Start');

    // 1. Listen to Accelerometer (gravity vector orientation)
    _accelSubscription?.cancel();
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      _lastAccelX = event.x;
      _lastAccelY = event.y;
      _lastAccelZ = event.z;
    });

    // 2. Listen to Gyroscope (real physical angular velocity)
    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      if (!_isSweeping || !mounted) return;

      final now = DateTime.now();
      if (_lastGyroTime == null) {
        _lastGyroTime = now;
        return;
      }

      final dt = now.difference(_lastGyroTime!).inMicroseconds / 1000000.0;
      _lastGyroTime = now;

      // Ignore abnormal time deltas
      if (dt <= 0 || dt > 0.3) return;

      // Project angular velocity onto gravity vector (vertical room axis)
      final gx = _lastAccelX;
      final gy = _lastAccelY;
      final gz = _lastAccelZ;
      final gNorm = math.sqrt(gx * gx + gy * gy + gz * gz);

      double verticalRotRate = 0.0;
      if (gNorm > 1.0) {
        // Dot product with unit gravity vector gives true yaw rate
        verticalRotRate = (event.x * gx + event.y * gy + event.z * gz) / gNorm;
      } else {
        // Fallback assuming upright portrait (Y-axis vertical)
        verticalRotRate = event.y;
      }

      final speed = verticalRotRate.abs();

      // STRICT SENSOR DEADBAND:
      // If the phone is NOT physically moving (speed < 0.08 rad/s, ~4.5°/sec):
      // PROGRESS DOES NOT ADVANCE AT ALL! Zero false movement!
      if (speed < 0.08) {
        if (_accumulatedDegrees < 5.0) {
          _updateSweepStatus('No motion detected • Rotate phone to the right');
        } else {
          _updateSweepStatus('Paused • Rotate phone right (${_accumulatedDegrees.toInt()}° / 180°)');
        }
        return;
      }

      if (speed > 3.0) {
        _updateSweepStatus('Too fast! Slow down and pan smoothly');
        return;
      }

      // PHONE IS PHYSICALLY MOVING! Integrate degrees
      final degDelta = speed * (180.0 / math.pi) * dt;
      _accumulatedDegrees += degDelta;
      final progress = (_accumulatedDegrees / 180.0).clamp(0.0, 1.0);

      _updateSweepStatus('Panning Classroom: ${_accumulatedDegrees.toInt()}° / 180°');

      if ((progress - _sweepProgress).abs() >= 0.01 || progress >= 1.0) {
        setState(() {
          _sweepProgress = progress;
        });
      }

      // Capture real camera slices at physical degree milestones
      if (_accumulatedDegrees >= 35.0 && !_sliceCaptured30) {
        _sliceCaptured30 = true;
        _captureSliceFrame('35° Left Desks');
      } else if (_accumulatedDegrees >= 90.0 && !_sliceCaptured90) {
        _sliceCaptured90 = true;
        _captureSliceFrame('90° Front Board');
      } else if (_accumulatedDegrees >= 150.0 && !_sliceCaptured150) {
        _sliceCaptured150 = true;
        _captureSliceFrame('150° Right Desks');
      }

      // Reached 180° panorama complete!
      if (_accumulatedDegrees >= 180.0) {
        _completePanoramaSweep();
      }
    });
  }

  void _updateSweepStatus(String msg) {
    if (_sweepStatusMessage != msg) {
      setState(() {
        _sweepStatusMessage = msg;
      });
    }
  }

  Future<void> _captureSliceFrame(String label) async {
    try {
      HapticFeedback.selectionClick();
      if (_isCameraInitialized && _cameraController != null) {
        final f = await _cameraController!.takePicture();
        _panoramaFrames.add(f);
      }
    } catch (_) {}
  }

  void _cancelPanoramaSweep() {
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    setState(() {
      _isSweeping = false;
      _sweepProgress = 0.0;
      _accumulatedDegrees = 0.0;
      _sweepStatusMessage = 'Sweep cancelled. Tap below to start.';
    });
  }

  Future<void> _completePanoramaSweep() async {
    if (!_isSweeping) return;
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();

    setState(() {
      _isSweeping = false;
      _sweepProgress = 1.0;
      _sweepStatusMessage = '180° Panorama Complete!';
    });

    try {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    XFile? bestFrame;
    if (_panoramaFrames.isNotEmpty) {
      bestFrame = _panoramaFrames.length >= 2
          ? _panoramaFrames[1] // Front board center slice
          : _panoramaFrames.last;
    } else if (_isCameraInitialized && _cameraController != null) {
      try {
        bestFrame = await _cameraController!.takePicture();
      } catch (_) {}
    }

    bestFrame ??= await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600,
      maxHeight: 1200,
    );

    if (!mounted) return;

    if (bestFrame == null) {
      setState(() {
        _errorMessage = 'Could not capture panorama frame. Please try again.';
      });
      return;
    }

    setState(() {
      _roomPhoto = bestFrame;
      _currentStep = VerificationStep.verifying;
    });

    await _submitDualVerification();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBMIT DUAL VERIFICATION (ARCFACE / DEEPFACE + CLASSROOM MATCH)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitDualVerification() async {
    if (_facePhoto == null) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _errorCode = null;
    });

    try {
      final faceBytes = await _facePhoto!.readAsBytes();
      List<int>? roomBytes;
      if (_roomPhoto != null) {
        roomBytes = await _roomPhoto!.readAsBytes();
      }

      List<int>? leftBytes;
      if (_faceLeft != null) {
        leftBytes = await _faceLeft!.readAsBytes();
      }

      List<int>? rightBytes;
      if (_faceRight != null) {
        rightBytes = await _faceRight!.readAsBytes();
      }

      List<int>? blinkBytes;
      if (_faceBlink != null) {
        blinkBytes = await _faceBlink!.readAsBytes();
      }

      final res = await widget.state.verifyAttendanceLive(
        widget.session.id,
        faceBytes: faceBytes,
        roomBytes: roomBytes,
        faceLeftBytes: leftBytes,
        faceRightBytes: rightBytes,
        faceBlinkBytes: blinkBytes,
      );

      if (mounted) {
        setState(() {
          _result = res;
          _livenessPassed = res.livenessPassed && res.isPresent;
          _currentStep = VerificationStep.result;
          _isProcessing = false;
          _errorCode = null;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorCode = 'TIMEOUT';
          _errorMessage = 'Biometric transmission timed out. Latency threshold exceeded.';
          _currentStep = VerificationStep.result;
        });
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorCode = 'NETWORK_DISCONNECT';
          _errorMessage = 'Network disconnected. Unable to reach Attendrix server. Verify Wi-Fi or cellular data.';
          _currentStep = VerificationStep.result;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorCode = e.errorCode;
          _errorMessage = e.message;
          _currentStep = VerificationStep.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = widget.state.error ?? e.toString();
          _errorCode = widget.state.errorCode;
          _currentStep = VerificationStep.result;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera feed or fallback background
            Positioned.fill(
              child: _buildCameraFeed(),
            ),

            // Top Header & Step Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTopHeader(),
            ),

            // Center Reticle / HUD (Specific to current step)
            if (_currentStep == VerificationStep.result)
              _buildResultHUD()
            else if (!_cameraPermissionDenied && !_cameraUnavailable && !_cameraStreamInterrupted) ...[
              if (_currentStep == VerificationStep.liveFace)
                _buildFaceScanningHUD()
              else if (_currentStep == VerificationStep.classroomRoom)
                _buildClassroomRoomHUD()
              else if (_currentStep == VerificationStep.verifying)
                _buildVerifyingHUD()
            ],

            // Bottom action bar
            if (_currentStep != VerificationStep.verifying &&
                _currentStep != VerificationStep.result &&
                !_cameraPermissionDenied &&
                !_cameraUnavailable &&
                !_cameraStreamInterrupted)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: _buildBottomActions(),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: CAMERA FEED
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCameraFeed() {
    if (_cameraPermissionError || !_isCameraInitialized || _cameraController == null) {
      if (_cameraPermissionDenied) {
        return _buildCameraPermissionDeniedFeed();
      } else if (_cameraStreamInterrupted) {
        return _buildCameraStreamInterruptedFeed();
      } else if (_cameraUnavailable) {
        return _buildCameraHardwareUnavailableFeed();
      }
      return _buildCameraStandbyFeed();
    }

    final size = MediaQuery.of(context).size;
    final previewSize = _cameraController!.value.previewSize;
    // Android/iOS camera sensors are landscape (e.g. 1920x1080).
    // In portrait orientation, width is the shorter dimension (previewSize.height).
    final double previewW = previewSize != null ? previewSize.height : size.width;
    final double previewH = previewSize != null ? previewSize.width : size.height;

    return ClipRect(
      child: Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPermissionDeniedFeed() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 40,
                color: AppColors.rose,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Permission Denied',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Attendrix requires camera access to verify your live face and record your attendance. Your biometrics remain strictly confidential.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initCamera,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.security_rounded, size: 18),
              label: const Text('Grant Camera Access / Retry'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text('Return to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraHardwareUnavailableFeed() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                size: 40,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Hardware Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The camera sensor could not be initialized or is occupied by another application. Please close background camera apps and retry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initCamera,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Camera Initialization', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStreamInterruptedFeed() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.sky.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.pause_circle_outline_rounded,
                size: 40,
                color: AppColors.sky,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Stream Interrupted',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The camera stream was paused when the app was backgrounded to preserve device hardware and battery.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (_cameras.isNotEmpty) {
                  _setupCameraController(_cameras[_selectedCameraIndex]);
                } else {
                  _initCamera();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Resume Camera Stream'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStandbyFeed() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 56,
              color: AppColors.slate,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Initializing',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Establishing secure connection with camera sensor...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _initCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Camera Feed'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: TOP HEADER & PROGRESS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.session.className.isNotEmpty
                      ? widget.session.className
                      : 'Live Attendance Verification',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentStep == VerificationStep.liveFace
                      ? 'Step 1/2: Student Liveness Check'
                      : _currentStep == VerificationStep.classroomRoom
                          ? 'Step 2/2: Classroom Physical Match'
                          : _currentStep == VerificationStep.verifying
                              ? 'Neural Engine Processing...'
                              : 'Verification Complete',
                  style: const TextStyle(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_cameras.length > 1 &&
              _currentStep != VerificationStep.verifying &&
              _currentStep != VerificationStep.result)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
              tooltip: 'Switch Camera',
              onPressed: _switchCamera,
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: FACE SCANNING HUD (ACTIVE LIVENESS INTERACTIVE DETECTION)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLivenessStageIndicators() {
    final stages = [
      (LivenessStage.center, '1. Center', Icons.face_rounded),
      (LivenessStage.turnLeft, '2. Turn Left', Icons.arrow_back_rounded),
      (LivenessStage.turnRight, '3. Turn Right', Icons.arrow_forward_rounded),
      (LivenessStage.blink, '4. Blink Eyes', Icons.remove_red_eye_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: stages.map((st) {
          final isCurrent = _livenessStage == st.$1;
          final isDone = _livenessStage.index > st.$1.index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primaryLight.withValues(alpha: 0.28)
                    : isDone
                        ? AppColors.emerald.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? AppColors.primaryLight
                      : isDone
                          ? AppColors.emerald
                          : Colors.white12,
                  width: isCurrent ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDone ? Icons.check_circle_rounded : st.$3,
                    size: 12,
                    color: isCurrent
                        ? Colors.white
                        : isDone
                            ? AppColors.emerald
                            : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    st.$2,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: isCurrent
                          ? Colors.white
                          : isDone
                              ? AppColors.emerald
                              : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaceScanningHUD() {
    final size = MediaQuery.of(context).size;
    final boxWidth = (size.width * 0.76).clamp(240.0, 320.0);
    final boxHeight = (boxWidth * 1.25).clamp(280.0, 400.0);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Active Liveness Multi-Step Progression Pill Bar (Safe horizontal scroll)
            _buildLivenessStageIndicators(),
            const SizedBox(height: 14),

            // Viewfinder Frame with White Corner Brackets matching Image 2 (Screen 3)
            SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // White Rounded Corner Brackets (Image 2 Viewfinder)
                  CustomPaint(
                    size: Size(boxWidth, boxHeight),
                    painter: _CornerBracketPainter(
                      color: _challengeRecorded
                          ? AppColors.primaryLight
                          : (_livenessStage == LivenessStage.turnLeft || _livenessStage == LivenessStage.turnRight)
                              ? Colors.white
                              : _livenessStage == LivenessStage.blink
                                  ? const Color(0xFF6EE7B7)
                                  : Colors.white.withValues(alpha: 0.95),
                      cornerLength: 36.0,
                      strokeWidth: 3.5,
                      cornerRadius: 18.0,
                    ),
                  ),

                  // Soft inner guidance oval
                  Container(
                    width: boxWidth * 0.88,
                    height: boxHeight * 0.88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(boxWidth * 0.44, boxHeight * 0.44),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                  ),

                  // Center visual guidance tailored to active liveness challenge
                  if (!_livenessPassed) ...[
                    if (_livenessStage == LivenessStage.center)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.center_focus_strong_rounded,
                            size: 38,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'LOOK STRAIGHT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Center face inside brackets',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      )
                    else if (_livenessStage == LivenessStage.turnLeft)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.6)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_circle_left_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'TURN FACE LEFT ◀',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rotate head ~20° to left',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    else if (_livenessStage == LivenessStage.turnRight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.6)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_circle_right_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'TURN FACE RIGHT ▶',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rotate head ~20° to right',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    else if (_livenessStage == LivenessStage.blink)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF6EE7B7).withValues(alpha: 0.6)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_red_eye_rounded,
                              size: 42,
                              color: Color(0xFF6EE7B7),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'BLINK BOTH EYES 👁️',
                              style: TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Firmly close and open eyes',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],

                  // Animated Scanner Line
                  if (!_challengeRecorded)
                    AnimatedBuilder(
                      animation: _scannerAnim,
                      builder: (context, _) {
                        return Positioned(
                          top: 16 + _scannerAnim.value * (boxHeight - 32),
                          left: 14,
                          right: 14,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.primaryLight.withValues(alpha: 0.85),
                                  Colors.white,
                                  AppColors.primaryLight.withValues(alpha: 0.85),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Challenge Recorded Indicator (Awaiting backend neural verification)
                  if (_challengeRecorded)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Instruction Pill with countdown badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _challengeRecorded
                      ? AppColors.primaryLight
                      : Colors.white24,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_challengeRecorded)
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_secondsLeft',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.sync_rounded, color: AppColors.primaryLight, size: 18),
                    ),
                  Text(
                    _challengeRecorded
                        ? 'Challenges Recorded • Switching to Room Sweep'
                        : _livenessStage == LivenessStage.center
                            ? 'Step 1/4: Looking straight ahead...'
                            : _livenessStage == LivenessStage.turnLeft
                                ? 'Step 2/4: Turn head to the left...'
                                : _livenessStage == LivenessStage.turnRight
                                    ? 'Step 3/4: Turn head to the right...'
                                    : 'Step 4/4: Blink both eyes firmly...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: CLASSROOM ROOM / PANORAMA HUD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildClassroomRoomHUD() {
    final size = MediaQuery.of(context).size;
    final boxWidth = size.width * 0.92;
    final boxHeight = boxWidth * 0.50;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 180° Panoramic Viewfinder Frame
          Container(
            width: boxWidth,
            height: boxHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isSweeping ? Colors.cyanAccent : AppColors.primaryLight,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isSweeping ? Colors.cyanAccent : AppColors.primary)
                      .withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top Tag
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.panorama_photosphere_rounded,
                          size: 14,
                          color: _isSweeping ? Colors.cyanAccent : AppColors.primaryLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isSweeping
                              ? 'PANORAMA SWEEPING (${_accumulatedDegrees.toInt()}°)'
                              : '180° ULTRA-WIDE PANORAMA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center Horizon Level Guide
                Center(
                  child: Container(
                    height: 1.5,
                    color: Colors.cyanAccent.withValues(alpha: 0.4),
                  ),
                ),
                Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Sweep Track (0° Left -> 90° Center -> 180° Right)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '◀ 0° Left Desks',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '🏛 90° Board',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text(
                            '180° Right Desks ▶',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Animated Track Bar with Panning Cursor
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _sweepProgress.clamp(0.05, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.cyanAccent, AppColors.primaryLight],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Panorama instructions badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSweeping
                          ? Icons.sync_rounded
                          : Icons.screen_rotation_rounded,
                      color: _isSweeping ? Colors.cyanAccent : AppColors.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSweeping
                          ? _sweepStatusMessage
                          : '180° Physical Classroom Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isSweeping
                      ? 'Slowly rotate your device from left to right along the horizon.'
                      : 'Stand in room and tap "START 180° PANORAMA SWEEP" below to sweep across the classroom desks and board.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: VERIFYING HUD (AI NEURAL PROCESSING)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVerifyingHUD() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryLight),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyzing Biometrics & Room',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Extracting 512-dim ArcFace embeddings and cross-referencing classroom environment template...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  _VerificationStepRow(
                    label: 'Live Face Frame Liveness Verification',
                    active: true,
                  ),
                  SizedBox(height: 8),
                  _VerificationStepRow(
                    label: 'ArcFace Biometric Cosine Comparison',
                    active: true,
                  ),
                  SizedBox(height: 8),
                  _VerificationStepRow(
                    label: 'Physical Classroom Room Matching',
                    active: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: VERIFICATION RESULT HUD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResultHUD() {
    final isEmptyRoom = _result?.isEmptyRoom == true;
    final isPresent = _result?.isPresent == true && !isEmptyRoom;
    final isFlagged = _result?.isFlagged == true || isEmptyRoom;
    final isQuality = _isQualityFailure;
    final isNetwork = _isNetworkError;
    final isDuplicate = _errorMessage != null &&
        (_errorMessage!.toLowerCase().contains('already') ||
         _errorMessage!.toLowerCase().contains('duplicate') ||
         _errorMessage!.toLowerCase().contains('strictly 1'));

    final Color headerColor = isPresent
        ? AppColors.emerald
        : (isNetwork
            ? AppColors.sky
            : (isQuality || isDuplicate || isFlagged
                ? AppColors.amber
                : AppColors.rose));

    final IconData headerIcon = isPresent
        ? Icons.verified_user_rounded
        : (isEmptyRoom
            ? Icons.meeting_room_outlined
            : (isNetwork
                ? Icons.wifi_off_rounded
                : (isQuality
                    ? Icons.photo_camera_front_rounded
                    : (isDuplicate
                        ? Icons.fact_check_rounded
                        : (isFlagged
                            ? Icons.warning_amber_rounded
                            : Icons.gpp_bad_rounded)))));

    final String title = isPresent
        ? 'Attendance Verified Present!'
        : (isEmptyRoom
            ? 'Empty Room Detected — Proxy Blocked'
            : (isNetwork
                ? 'Network Timeout / Disconnected'
                : (isQuality
                    ? 'Image Quality Check Failed'
                    : (isDuplicate
                        ? 'Attendance Already Recorded'
                        : (isFlagged
                            ? 'Attendance Flagged for Review'
                            : 'Verification Failed')))));

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: headerColor.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: headerColor.withValues(alpha: 0.25),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(headerIcon, color: headerColor, size: 38),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: headerColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _result?.message ?? _errorMessage ?? 'Biometric verification processed.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            if (isQuality && _errorCode != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, color: AppColors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quality Guidance: [$_errorCode]',
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _qualityRemedyText(_errorCode!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Detailed Metric Tiles
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (isEmptyRoom) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.rose.withValues(alpha: 0.45)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppColors.rose, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Anti-Proxy Triggered: Room is completely empty. Both Lecturer and student peers are absent from stage and hall.',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Biometric Match:', style: TextStyle(color: AppColors.slate, fontSize: 13)),
                        Text(
                          '${(_result!.faceConfidence * 100).toInt()}% Match',
                          style: TextStyle(
                            color: _result!.faceMatch ? AppColors.emerald : AppColors.rose,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Active Liveness (Turn & Blink):', style: TextStyle(color: AppColors.slate, fontSize: 13)),
                        Row(
                          children: [
                            Icon(
                              _result!.livenessPassed ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              size: 14,
                              color: _result!.livenessPassed ? AppColors.emerald : AppColors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _result!.livenessPassed ? 'Verified Passed' : _result!.livenessNote,
                              style: TextStyle(
                                color: _result!.livenessPassed ? AppColors.emerald : AppColors.amber,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sir (Lecturer on Stage):', style: TextStyle(color: AppColors.slate, fontSize: 13)),
                        Text(
                          _result!.sirDetected ? 'Detected' : 'Not Detected',
                          style: TextStyle(
                            color: _result!.sirDetected ? AppColors.emerald : AppColors.amber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Crowd Audience:', style: TextStyle(color: AppColors.slate, fontSize: 13)),
                        Text(
                          _result!.crowdDetected ? '${_result!.crowdCount} peers in hall' : 'Not Detected',
                          style: TextStyle(
                            color: _result!.crowdDetected ? AppColors.emerald : AppColors.amber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hall Venue:', style: TextStyle(color: AppColors.slate, fontSize: 13)),
                        Text(
                          _result!.hallType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (isNetwork && _facePhoto != null) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sky,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isProcessing ? null : _submitDualVerification,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry Attendance Submission',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Done Button
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: headerColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).pop(isPresent);
              },
              child: Text(
                isPresent ? 'Return to Home' : 'Close',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),

            if (!isPresent) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    _currentStep = VerificationStep.liveFace;
                    _livenessStage = LivenessStage.center;
                    _challengeRecorded = false;
                    _livenessPassed = false;
                    _isProcessing = false;
                    _errorMessage = null;
                    _result = null;
                    _facePhoto = null;
                    _faceLeft = null;
                    _faceRight = null;
                    _faceBlink = null;
                    _roomPhoto = null;
                    _sweepProgress = 0.0;
                    _accumulatedDegrees = 0.0;
                    _secondsLeft = 3;
                  });
                  _startAutoScanCountdown();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry Verification Attempt',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_clock_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '1-Attempt Policy • Attempt Recorded & Finalized',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  String _qualityRemedyText(String code) {
    switch (code.toUpperCase()) {
      case 'IMAGE_BLURRY':
        return 'Hold your phone steady with both hands. Avoid sudden movements or taps during photo capture.';
      case 'POOR_LIGHTING':
        return 'Insufficient light detected. Move towards overhead classroom lights or open a window.';
      case 'EXCESSIVE_EXPOSURE':
        return 'Overexposure or glare detected. Avoid pointing camera directly at projector lamps or bright sunlight.';
      case 'BACKLIGHTING_DETECTED':
        return 'Severe backlighting detected. Position the light source in front of you rather than behind your head.';
      case 'NO_FACE_DETECTED':
        return 'No face was recognized in the camera frame. Center your face inside the viewfinder reticle.';
      case 'MULTIPLE_FACES':
        return 'Multiple faces detected in frame. Only one individual student face is permitted during verification.';
      case 'FACE_TOO_SMALL':
        return 'Face is too far from camera. Move phone closer until your face fills 40% to 60% of the frame.';
      case 'FACE_OUT_OF_BOUNDS':
        return 'Facial features are partially outside the camera borders. Center your chin and forehead inside the frame.';
      case 'UNSUPPORTED_FORMAT':
        return 'The captured image format is unsupported. Please use the camera directly to capture JPEG or PNG photos.';
      case 'CORRUPTED_IMAGE':
        return 'Image data decoding failed. Retake photo with good camera stabilization.';
      case 'EMPTY_IMAGE':
        return 'Empty image payload received (0 bytes). Please retry taking your photo.';
      default:
        return 'Ensure your face is clearly visible, well lit, and centered within the camera viewfinder.';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: BOTTOM ACTIONS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomActions() {
    if (_currentStep == VerificationStep.liveFace) {
      final String actionLabel = _livenessStage == LivenessStage.center
          ? 'Tap to capture frontal face'
          : _livenessStage == LivenessStage.turnLeft
              ? 'Tap to capture left angle'
              : _livenessStage == LivenessStage.turnRight
                  ? 'Tap to capture right angle'
                  : _livenessStage == LivenessStage.blink
                      ? 'Tap to capture blink'
                      : 'Challenges recorded';

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: (_isProcessing || _challengeRecorded) ? null : _captureFace,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _challengeRecorded
                  ? 'Motion challenges recorded • Preparing Room Sweep'
                  : 'Auto-scan in ${_secondsLeft}s • $actionLabel',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentStep == VerificationStep.classroomRoom) {
      if (_isSweeping) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.cyanAccent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_accumulatedDegrees.toInt()}° / 180°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(_sweepProgress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _sweepProgress,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _sweepStatusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _cancelPanoramaSweep,
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white60),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  if (_accumulatedDegrees >= 60.0)
                    ElevatedButton.icon(
                      onPressed: _completePanoramaSweep,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        'Finish Sweep (${_accumulatedDegrees.toInt()}°)',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _startPanoramaSweep,
          icon: const Icon(Icons.panorama_photosphere_rounded, size: 28),
          label: const Text(
            'START 180° PANORAMA SWEEP',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _VerificationStepRow extends StatelessWidget {
  const _VerificationStepRow({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for crisp rounded corner brackets matching Image 2 (Screen 3)
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;

  const _CornerBracketPainter({
    required this.color,
    this.cornerLength = 32.0,
    this.strokeWidth = 3.5,
    this.cornerRadius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final len = cornerLength;

    // Top-Left corner
    final pathTL = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(len, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right corner
    final pathTR = Path()
      ..moveTo(w - len, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, len);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left corner
    final pathBL = Path()
      ..moveTo(0, h - len)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
      ..lineTo(len, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right corner
    final pathBR = Path()
      ..moveTo(w - len, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
      ..lineTo(w, h - len);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      color != oldDelegate.color;
}
