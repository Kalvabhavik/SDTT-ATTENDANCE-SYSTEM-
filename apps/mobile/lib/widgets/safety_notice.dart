import 'package:flutter/material.dart';

import 'app_widgets.dart';

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key});
  @override
  Widget build(BuildContext context) => AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Privacy and safety',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
            'Face enrollment stores only an encrypted embedding and consent time on the backend. Sweep frames are analyzed server-side and deleted after analysis except a short-lived private review filmstrip for flagged attempts. Manual roll call is always available.')
      ]));
}
