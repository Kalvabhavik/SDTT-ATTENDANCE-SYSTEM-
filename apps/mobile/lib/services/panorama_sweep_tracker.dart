import 'dart:math' as math;

class PanoramaSweepTracker {
  static const milestones = [35, 90, 150, 180];
  static const targetDegrees = 180.0;

  double degrees = 0;
  int? _direction;
  int _nextMilestone = 0;

  double get progress => (degrees / targetDegrees).clamp(0, 1).toDouble();
  bool get isComplete => degrees >= targetDegrees;

  bool addRotation({
    required double radiansPerSecond,
    required double elapsedSeconds,
  }) {
    final speed = radiansPerSecond.abs();
    if (!elapsedSeconds.isFinite ||
        elapsedSeconds <= 0 ||
        elapsedSeconds > 0.3) {
      return false;
    }
    if (!speed.isFinite || speed < 0.08 || speed > 3.0 || isComplete) {
      return false;
    }

    final direction = radiansPerSecond.sign.toInt();
    _direction ??= direction;
    if (direction != _direction) return false;

    degrees = math.min(
      targetDegrees,
      degrees + speed * elapsedSeconds * (180 / math.pi),
    );
    return true;
  }

  List<int> takeReachedMilestones() {
    final reached = <int>[];
    while (_nextMilestone < milestones.length &&
        degrees >= milestones[_nextMilestone]) {
      reached.add(milestones[_nextMilestone]);
      _nextMilestone++;
    }
    return reached;
  }

  void reset() {
    degrees = 0;
    _direction = null;
    _nextMilestone = 0;
  }
}
