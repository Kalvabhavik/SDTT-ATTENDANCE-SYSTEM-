import 'package:flutter/material.dart';

import 'app_widgets.dart';

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key});
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Privacy & Biometric Protection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Verification captures are processed for this session only. Raw facial images are discarded immediately after in-memory feature extraction into 512-D encrypted templates. Notifications remain strictly private within this academic app.',
          style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
        ),
      ],
    ),
  );
}
