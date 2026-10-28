import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({
    super.key,
    required this.state,
    this.onCompleted,
  });

  final AppState state;
  final VoidCallback? onCompleted;

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final ImagePicker _picker = ImagePicker();
  bool consentAgreed = false;
  XFile? capturedFile;
  bool isEnrolling = false;
  String? enrollmentError;

  Future<void> _takeReferenceSelfie() async {
    setState(() => enrollmentError = null);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
      );
      if (photo != null) {
        setState(() => capturedFile = photo);
      }
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('permission') || str.contains('denied')) {
        setState(() => enrollmentError = 'Camera access was denied. Please grant camera permission in system settings to take a reference selfie.');
      } else {
        setState(() => enrollmentError = 'Camera access error: $e');
      }
    }
  }

  Future<void> _submitEnrollment() async {
    if (isEnrolling) return;
    if (!consentAgreed) {
      setState(() => enrollmentError = 'Please accept the consent terms to proceed.');
      return;
    }
    if (capturedFile == null) {
      setState(() => enrollmentError = 'Please capture a clear reference selfie.');
      return;
    }

    setState(() {
      isEnrolling = true;
      enrollmentError = null;
    });

    try {
      final bytes = await capturedFile!.readAsBytes();
      await widget.state.api.enrollReferenceSelfie(bytes, true);
      await widget.state.checkEnrollment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Reference selfie enrolled successfully!'),
          ),
        );
        widget.onCompleted?.call();
      }
    } on ApiException catch (e) {
      setState(() => enrollmentError = e.message);
    } catch (e) {
      setState(() => enrollmentError = e.toString());
    } finally {
      if (mounted) setState(() => isEnrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.state.user?.displayRole ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '$role Verification Enrollment',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.emeraldBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'One-Time Biometric Reference',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Enroll one frontal selfie to verify your presence during attendance sweeps.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Camera Frame / Selfie Preview with Biometric Brackets
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 230,
                      height: 280,
                      decoration: BoxDecoration(
                        color: AppColors.cardSubtle,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: capturedFile != null ? AppColors.primary : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: capturedFile != null
                            ? (kIsWeb
                                ? Image.network(capturedFile!.path, fit: BoxFit.cover)
                                : Image.file(File(capturedFile!.path), fit: BoxFit.cover))
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.face_rounded,
                                    size: 64,
                                    color: AppColors.muted,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Front camera only\nSingle face in frame',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.slate,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    // White / Forest Green corner brackets
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BiometricFramePainter(
                            color: capturedFile != null ? AppColors.primary : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Camera trigger button
              Center(
                child: OutlinedButton.icon(
                  onPressed: isEnrolling ? null : _takeReferenceSelfie,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                  label: Text(
                    capturedFile != null ? 'Retake Selfie' : 'Capture Front Selfie',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Consent Agreement Box
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: consentAgreed,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) => setState(() => consentAgreed = v == true),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => consentAgreed = !consentAgreed),
                        child: const Text(
                          'I consent to enrollment of an encrypted facial reference embedding for classroom attendance verification. I understand raw photos are discarded after feature extraction, and only a 512-D template is stored.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (enrollmentError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    enrollmentError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.rose,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Submit button
              AnimatedPressable(
                onTap: isEnrolling || !consentAgreed || capturedFile == null
                    ? null
                    : _submitEnrollment,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: consentAgreed && capturedFile != null
                        ? AppColors.primaryGradient
                        : null,
                    color: consentAgreed && capturedFile != null
                        ? null
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: consentAgreed && capturedFile != null
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isEnrolling
                        ? const AppLottieLoader(
                            size: 32,
                            color: Colors.white,
                          )
                        : Text(
                            'Enroll Biometric Reference',
                            style: TextStyle(
                              color: consentAgreed && capturedFile != null
                                  ? Colors.white
                                  : AppColors.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricFramePainter extends CustomPainter {
  const _BiometricFramePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLength = 22.0;
    const padding = 12.0;

    // Top Left
    canvas.drawLine(const Offset(padding, padding + cornerLength), const Offset(padding, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLength, padding), paint);

    // Top Right
    canvas.drawLine(Offset(size.width - padding - cornerLength, padding), Offset(size.width - padding, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(padding, size.height - padding - cornerLength), Offset(padding, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width - padding - cornerLength, size.height - padding), Offset(size.width - padding, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _BiometricFramePainter oldDelegate) => oldDelegate.color != color;
}
