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
            'Camera captures are uploaded for this session only and removed locally after upload when possible. The API returns simulated suggestions; this demo does not recognize faces or retain images/templates. Notifications stay in this app.')
      ]));
}
