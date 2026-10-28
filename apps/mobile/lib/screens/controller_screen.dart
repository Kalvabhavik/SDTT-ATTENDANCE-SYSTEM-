import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

const Map<int, String> kHallTypeMap = {
  80: '80-Seater Seminar Hall',
  120: '120-Seater Lecture Theater',
  240: '240-Seater Tiered Amphitheater',
  260: '260-Seater Grand Auditorium',
};

Widget _buildRoomImage(String photoUrl, {double height = 120}) {
  if (photoUrl.isEmpty) {
    return Container(
      height: height,
      color: AppColors.cardSubtle,
      child: const Center(
        child: Icon(Icons.meeting_room_outlined, color: AppColors.slate, size: 36),
      ),
    );
  }
  if (photoUrl.startsWith('data:image')) {
    try {
      final b64 = photoUrl.split(',').last;
      return Image.memory(
        base64Decode(b64),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: AppColors.cardSubtle,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.slate)),
        ),
      );
    } catch (_) {
      return Container(
        height: height,
        color: AppColors.cardSubtle,
        child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.slate)),
      );
    }
  }
  return Image.network(
    photoUrl,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      height: height,
      color: AppColors.cardSubtle,
      child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.slate)),
    ),
  );
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  int _selectedTab = 0; // 0: Classes & Rooms, 1: Student Roster
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    widget.state.loadControllerData();
  }

  void _showCaptureRoomDialog(Classroom cls) {
    int selectedCapacity = cls.capacity > 0 ? cls.capacity : 120;
    final roomCtrl = TextEditingController(text: cls.roomNumber.isNotEmpty ? cls.roomNumber : 'LH-$selectedCapacity');
    Uint8List? capturedBytes;
    bool isSaving = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Official Classroom Reference',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            Text(
                              '${cls.name} (${cls.code})',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hall Seating Capacity Selection
                  const Text(
                    'Classroom Seating Capacity Tier',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [80, 120, 240, 260].map((cap) {
                      final isSelected = selectedCapacity == cap;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedCapacity = cap;
                                if (roomCtrl.text.startsWith('LH-') || roomCtrl.text.isEmpty) {
                                  roomCtrl.text = 'LH-$cap';
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.cardSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.line,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$cap',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isSelected ? Colors.white : AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    'Seats',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  AppTextField(
                    controller: roomCtrl,
                    label: 'Assigned Room / Venue Number',
                    hint: 'e.g. LH-$selectedCapacity or Main Auditorium',
                    prefixIcon: Icons.meeting_room_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Room Photo Preview / Capture Options
                  const Text(
                    'Classroom Reference Panorama',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),

                  if (capturedBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.memory(
                            capturedBytes!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.emerald,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Ready to Save',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (cls.roomPhoto.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          _buildRoomImage(cls.roomPhoto, height: 160),
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Current Active Template',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.cardSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.slate),
                            SizedBox(height: 6),
                            Text(
                              'No reference image captured yet',
                              style: TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Capture the stage & seating to train anti-proxy verification',
                              style: TextStyle(fontSize: 10, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Capture Action Buttons: Camera & Gallery
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final photo = await _picker.pickImage(
                                source: ImageSource.camera,
                                preferredCameraDevice: CameraDevice.rear,
                                maxWidth: 1600,
                                maxHeight: 1200,
                                imageQuality: 88,
                              );
                              if (photo != null) {
                                final bytes = await photo.readAsBytes();
                                setModalState(() {
                                  capturedBytes = bytes;
                                  localError = null;
                                });
                              }
                            } catch (e) {
                              setModalState(() => localError = 'Camera error: $e');
                            }
                          },
                          icon: const Icon(Icons.photo_camera_rounded, size: 18),
                          label: const Text('Open Camera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final photo = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1600,
                                maxHeight: 1200,
                                imageQuality: 88,
                              );
                              if (photo != null) {
                                final bytes = await photo.readAsBytes();
                                setModalState(() {
                                  capturedBytes = bytes;
                                  localError = null;
                                });
                              }
                            } catch (e) {
                              setModalState(() => localError = 'Gallery error: $e');
                            }
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text('From Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: isSaving || (capturedBytes == null && cls.roomPhoto.isEmpty)
                        ? null
                        : () async {
                            if (capturedBytes == null) {
                              setModalState(() => localError = 'Please capture a new room photo first.');
                              return;
                            }
                            setModalState(() {
                              isSaving = true;
                              localError = null;
                            });
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(ctx);
                            final success = await widget.state.captureClassRoom(
                              classId: cls.id,
                              photoBytes: capturedBytes!,
                              capacity: selectedCapacity,
                              hallType: kHallTypeMap[selectedCapacity] ?? '$selectedCapacity-Seater Hall',
                              roomNumber: roomCtrl.text.trim(),
                            );
                            setModalState(() => isSaving = false);
                            if (mounted) {
                              if (success) {
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Official reference saved for ${cls.name} (${roomCtrl.text.trim()})!'),
                                    backgroundColor: AppColors.emerald,
                                  ),
                                );
                              } else {
                                setModalState(() {
                                  localError = widget.state.error ?? 'Upload failed. Please check lighting.';
                                });
                              }
                            }
                          },
                    icon: isSaving
                        ? const AppLottieLoader(size: 20, color: Colors.white)
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(isSaving ? 'Uploading & Analyzing…' : 'Save Reference Template'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final sectionCtrl = TextEditingController(text: 'Section A');
    int selectedCapacity = 120;
    final roomCtrl = TextEditingController(text: 'LH-120');
    final photoCtrl = TextEditingController();
    Uint8List? capturedBytes;
    String? capturedDataUri;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create Class & Assign Venue',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Course Name',
                    hint: 'e.g. Data Structures & Algorithms',
                    prefixIcon: Icons.menu_book_rounded,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: codeCtrl,
                          label: 'Course Code',
                          hint: 'e.g. CS-201',
                          prefixIcon: Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: sectionCtrl,
                          label: 'Section',
                          hint: 'e.g. Section B',
                          prefixIcon: Icons.groups_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hall Seating Capacity Selection
                  const Text(
                    'Hall Seating Capacity Tier',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [80, 120, 240, 260].map((cap) {
                      final isSelected = selectedCapacity == cap;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedCapacity = cap;
                                if (roomCtrl.text.startsWith('LH-') || roomCtrl.text.isEmpty) {
                                  roomCtrl.text = 'LH-$cap';
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.cardSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.line,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$cap',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isSelected ? Colors.white : AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    'Seats',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  AppTextField(
                    controller: roomCtrl,
                    label: 'Assigned Classroom Room',
                    hint: 'e.g. LH-$selectedCapacity',
                    prefixIcon: Icons.meeting_room_rounded,
                  ),
                  const SizedBox(height: 14),

                  // Room Photo: Camera capture / Gallery upload
                  const Text(
                    'Classroom Reference Photo',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),

                  if (capturedBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.memory(
                            capturedBytes!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 14,
                              child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                            ),
                            onPressed: () {
                              setModalState(() {
                                capturedBytes = null;
                                capturedDataUri = null;
                                photoCtrl.text = '';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final photo = await _picker.pickImage(
                                source: ImageSource.camera,
                                preferredCameraDevice: CameraDevice.rear,
                                maxWidth: 1600,
                                maxHeight: 1200,
                                imageQuality: 88,
                              );
                              if (photo != null) {
                                final bytes = await photo.readAsBytes();
                                final b64 = base64Encode(bytes);
                                final dataUri = 'data:image/jpeg;base64,$b64';
                                setModalState(() {
                                  capturedBytes = bytes;
                                  capturedDataUri = dataUri;
                                  photoCtrl.text = dataUri;
                                  dialogError = null;
                                });
                              }
                            } catch (e) {
                              setModalState(() => dialogError = 'Camera error: $e');
                            }
                          },
                          icon: const Icon(Icons.photo_camera_rounded, size: 18),
                          label: const Text('Capture Camera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final photo = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1600,
                                maxHeight: 1200,
                                imageQuality: 88,
                              );
                              if (photo != null) {
                                final bytes = await photo.readAsBytes();
                                final b64 = base64Encode(bytes);
                                final dataUri = 'data:image/jpeg;base64,$b64';
                                setModalState(() {
                                  capturedBytes = bytes;
                                  capturedDataUri = dataUri;
                                  photoCtrl.text = dataUri;
                                  dialogError = null;
                                });
                              }
                            } catch (e) {
                              setModalState(() => dialogError = 'Gallery error: $e');
                            }
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text('Upload Photo'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  AppTextField(
                    controller: photoCtrl,
                    label: 'Or Reference Room Photo URL (Optional)',
                    hint: 'Image URL or data URI',
                    prefixIcon: Icons.link_rounded,
                  ),

                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) return;
                      Navigator.of(ctx).pop();
                      final photoToSave = (capturedDataUri != null && capturedDataUri!.isNotEmpty)
                          ? capturedDataUri
                          : (photoCtrl.text.trim().isNotEmpty
                              ? photoCtrl.text.trim()
                              : 'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=800');
                      final success = await widget.state.createClassroom(
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim(),
                        section: sectionCtrl.text.trim(),
                        roomNumber: roomCtrl.text.trim(),
                        capacity: selectedCapacity,
                        hallType: kHallTypeMap[selectedCapacity] ?? '$selectedCapacity-Seater Hall',
                        roomPhoto: photoToSave,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Class created successfully!' : (widget.state.error ?? 'Failed')),
                            backgroundColor: success ? AppColors.emerald : AppColors.rose,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Save Classroom & Venue Template'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final selectedClassIds = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Register College Student',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. John Doe',
                    prefixIcon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailCtrl,
                    label: 'College Email',
                    hint: 'e.g. student3@demo.edu',
                    prefixIcon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: rollCtrl,
                          label: 'Roll Number',
                          hint: 'CS-2026-045',
                          prefixIcon: Icons.badge_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: idCtrl,
                          label: 'Student ID',
                          hint: 'STU-991',
                          prefixIcon: Icons.numbers_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Assign to Classes:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: widget.state.controllerClasses.map((cls) {
                      final selected = selectedClassIds.contains(cls.id);
                      return FilterChip(
                        label: Text('${cls.code} (${cls.section})'),
                        selected: selected,
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedClassIds.add(cls.id);
                            } else {
                              selectedClassIds.remove(cls.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || rollCtrl.text.trim().isEmpty) {
                        return;
                      }
                      Navigator.of(ctx).pop();
                      final success = await widget.state.createStudent(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        rollNumber: rollCtrl.text.trim(),
                        studentId: idCtrl.text.trim().isNotEmpty ? idCtrl.text.trim() : null,
                        classIds: selectedClassIds.toList(),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Student registered in database!' : (widget.state.error ?? 'Failed')),
                            backgroundColor: success ? AppColors.emerald : AppColors.rose,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Add to College Roster'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final classes = state.controllerClasses;
    final students = state.controllerStudents;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Controller',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            Text(
              state.user?.name ?? 'Admin',
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.loadControllerData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: () => state.logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.loadControllerData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Controller Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Academic Controller Portal',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Manage classrooms, sections, rosters & locks',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _StatBadge(label: 'Total Classes', value: '${classes.length}'),
                      const SizedBox(width: 12),
                      _StatBadge(label: 'Students Roster', value: '${students.length}'),
                      const SizedBox(width: 12),
                      _StatBadge(
                        label: 'Locked',
                        value: '${students.where((s) => s.registrationLocked).length}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab Selector
            Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Classrooms & Rooms (${classes.length})',
                    active: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TabButton(
                    label: 'Student Roster (${students.length})',
                    active: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab 0: Classrooms
            if (_selectedTab == 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Configured Classrooms',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  TextButton.icon(
                    onPressed: _showAddClassDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Class'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (classes.isEmpty)
                const EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'No Classes Configured',
                  message: 'Tap Add Class to configure courses and assign room reference images.',
                )
              else
                ...classes.map((cls) => _ClassCard(classroom: cls, onCapture: _showCaptureRoomDialog)),
            ] else ...[
              // Tab 1: Students
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'College Student Database',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  TextButton.icon(
                    onPressed: _showAddStudentDialog,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Register Student'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (students.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No Students in Database',
                  message: 'Add students to allow them to register biometrics and mark attendance.',
                )
              else
                ...students.map((stu) => _StudentCard(
                      student: stu,
                      onUnlock: () async {
                        await state.unlockStudent(stu.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unlocked ${stu.name}. They can now re-enroll biometrics.'),
                              backgroundColor: AppColors.emerald,
                            ),
                          );
                        }
                      },
                    )),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.primary : AppColors.line),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.classroom, required this.onCapture});
  final Classroom classroom;
  final ValueChanged<Classroom> onCapture;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = classroom.roomPhoto.isNotEmpty;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${classroom.code} • ${classroom.section}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cardSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  classroom.roomNumber,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Capacity Tier & Hall Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_seat_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${classroom.capacity} Seats',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  classroom.hallType,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Classroom Photo Thumbnail Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                _buildRoomImage(classroom.roomPhoto, height: 110),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasPhoto ? AppColors.emerald.withValues(alpha: 0.9) : AppColors.amber.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPhoto ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPhoto ? 'Reference Set' : 'Photo Required',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enrolled: ${classroom.studentCount} Students',
                style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
              ),
              if (classroom.referenceCapturedAt.isNotEmpty)
                const Text(
                  'Verified Live',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Dedicated Capture Room Photo Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onCapture(classroom),
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: Text(hasPhoto ? 'Update Room Panorama' : '📸 Capture Room Reference'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasPhoto ? AppColors.primaryDark : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onUnlock});
  final ControllerStudent student;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              student.name.isNotEmpty ? student.name[0] : 'S',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.name,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: student.registrationLocked ? AppColors.emeraldBg : AppColors.amberBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        student.registrationLocked ? 'Locked (Registered)' : 'Pending Register',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: student.registrationLocked ? AppColors.emerald : AppColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${student.rollNumber} • ${student.email}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
                if (student.classes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Classes: ${student.classes.join(", ")}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          if (student.registrationLocked)
            IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 20),
              tooltip: 'Unlock Registration',
              onPressed: onUnlock,
            ),
        ],
      ),
    );
  }
}
