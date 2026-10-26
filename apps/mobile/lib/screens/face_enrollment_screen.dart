import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../state/app_state.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key, required this.state});
  final AppState state;
  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _controller;
  bool _consent = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera permission'),
        content: const Text('We use the front camera for one enrollment selfie. The backend checks that one face is visible, then stores only an encrypted face embedding and your consent time. The photo is not retained.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) { front = camera; break; }
      }
      if (front == null) throw CameraException('front_camera_missing', 'No front-facing camera is available.');
      final controller = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) { await controller.dispose(); return; }
      setState(() { _controller = controller; _message = null; });
    } on CameraException catch (error) {
      setState(() => _message = error.description ?? 'Camera access failed. Check the permission in Settings.');
    } catch (_) {
      setState(() => _message = 'The front camera could not be opened.');
    }
  }

  Future<void> _enroll() async {
    final controller = _controller;
    if (!_consent || controller == null || !controller.value.isInitialized) return;
    setState(() { _busy = true; _message = null; });
    XFile? photo;
    try {
      photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final success = await widget.state.enrollFace(bytes);
      if (!success) setState(() => _message = widget.state.error ?? 'Enrollment failed. Retake the selfie and try again.');
      if (success && mounted) await controller.dispose();
    } on CameraException catch (error) {
      setState(() => _message = error.description ?? 'The selfie could not be captured.');
    } catch (_) {
      setState(() => _message = 'Enrollment could not be completed. Check your connection and retry.');
    } finally {
      if (photo != null) {
        try {
          await photo.delete();
        } catch (_) {
          if (mounted) setState(() => _message = 'The temporary camera image could not be removed. Close the app and retry.');
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Face enrollment')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('One reference selfie', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Enrollment is required before using camera attendance. Keep your face centered, use bright light, and make sure no one else is in frame.'),
        const SizedBox(height: 16),
        if (camera?.value.isInitialized == true)
          ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: camera!.value.aspectRatio, child: CameraPreview(camera)))
        else
          Container(height: 260, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(16)), child: const Center(child: Icon(Icons.face_retouching_natural, size: 70))),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: _consent,
          onChanged: (value) => setState(() => _consent = value == true),
          contentPadding: EdgeInsets.zero,
          title: const Text('I consent to backend-only face-template storage.'),
          subtitle: const Text('Only an encrypted embedding, model version, and consent timestamp are retained. The enrollment photo is discarded after analysis.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 8),
        if (camera == null)
          FilledButton.icon(onPressed: _consent ? _startCamera : null, icon: const Icon(Icons.camera_alt), label: const Text('Open front camera'))
        else
          FilledButton.icon(onPressed: _busy ? null : _enroll, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), label: Text(_busy ? 'Checking selfie…' : 'Capture and enroll')),
        if (camera != null) TextButton(onPressed: _busy ? null : () async { await camera.dispose(); if (mounted) setState(() => _controller = null); }, child: const Text('Retake')),
      ])),
    );
  }
}
