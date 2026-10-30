import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/services/panorama_sweep_tracker.dart';

void main() {
  test('tracks only deliberate forward sweep and signals panorama milestones',
      () {
    final tracker = PanoramaSweepTracker();

    expect(tracker.addRotation(radiansPerSecond: 0.02, elapsedSeconds: 0.2),
        false);
    expect(tracker.degrees, 0);
    expect(tracker.addRotation(radiansPerSecond: 1, elapsedSeconds: 0.2), true);
    expect(
        tracker.addRotation(radiansPerSecond: -1, elapsedSeconds: 0.2), false);
    expect(tracker.degrees, closeTo(180 / math.pi * 0.2, 0.001));

    tracker.reset();
    final crossed = <int>[];
    for (var index = 0; index < 20; index++) {
      tracker.addRotation(radiansPerSecond: 1, elapsedSeconds: 0.2);
      crossed.addAll(tracker.takeReachedMilestones());
    }

    expect(crossed, [35, 90, 150, 180]);
    expect(tracker.isComplete, true);
  });

  test('ignores invalid timing and implausibly fast movement', () {
    final tracker = PanoramaSweepTracker();

    expect(tracker.addRotation(radiansPerSecond: 2, elapsedSeconds: 0), false);
    expect(
        tracker.addRotation(radiansPerSecond: 2, elapsedSeconds: 0.5), false);
    expect(
        tracker.addRotation(radiansPerSecond: 4, elapsedSeconds: 0.1), false);
    expect(tracker.degrees, 0);
  });
}
