import 'package:flutter/gestures.dart';

/// Direction of a horizontal three-finger swipe gesture.
enum ThreeFingerSwipeDirection { left, right }

/// Detects Mac-touchpad-style horizontal three-finger swipes across raw pointer events.
///
/// Supports restricting pointer enrollment to a specific active region (such as
/// the center portion of the screen), preserves fast staggered motion when all
/// three fingers land within [maxRestOriginAge], retains early-lifted finger
/// displacements mid-stroke, and latches one trigger per stroke.
class ThreeFingerSwipeDetector {
  ThreeFingerSwipeDetector({
    this.swipeThreshold = 26.0,
    this.maxRestOriginAge = const Duration(milliseconds: 250),
    this.isPositionInActiveZone,
    required this.onSwipe,
    this.onMultiTouchStateChanged,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final double swipeThreshold;
  final Duration maxRestOriginAge;
  final bool Function(Offset position)? isPositionInActiveZone;
  final void Function(ThreeFingerSwipeDirection direction) onSwipe;
  final void Function(bool isMultiTouchActive)? onMultiTouchStateChanged;
  final DateTime Function() _clock;

  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _pointerOrigins = {};
  final Map<int, DateTime> _pointerDownTimes = {};
  final Map<int, Offset> _completedStrokeDeltas = {};

  int _peakPointersInStroke = 0;
  bool _threeFingerEngaged = false;
  bool _hasTriggeredInStroke = false;
  DateTime? _lastThreeFingerEndTime;

  /// True while two or more enrolled pointers are currently touching the active zone.
  bool get isMultiTouchActive => _activePointers.length >= 2;

  /// True while a three-finger stroke is engaged or within 35ms of ending,
  /// preventing accidental button taps from firing on finger lift without
  /// blocking normal one- or two-finger interactions.
  bool get shouldSuppressSingleFinger {
    if (_threeFingerEngaged || _peakPointersInStroke >= 3) return true;
    final endedAt = _lastThreeFingerEndTime;
    if (endedAt == null) return false;
    return _clock().difference(endedAt) < const Duration(milliseconds: 35);
  }

  /// Enrolls pointers touching inside [isPositionInActiveZone] and engages
  /// three-finger detection once three pointers are active.
  void handlePointerDown(PointerDownEvent event) {
    if (isPositionInActiveZone != null && !isPositionInActiveZone!(event.position)) {
      return;
    }

    final wasMultiTouch = isMultiTouchActive;
    final now = _clock();
    _activePointers[event.pointer] = event.position;
    _pointerOrigins[event.pointer] = event.position;
    _pointerDownTimes[event.pointer] = now;

    if (_activePointers.length > _peakPointersInStroke) {
      _peakPointersInStroke = _activePointers.length;
    }

    if (!_threeFingerEngaged && _activePointers.length >= 3) {
      _threeFingerEngaged = true;
      _completedStrokeDeltas.clear();

      // Re-anchor pointers that rested idle longer than maxRestOriginAge while
      // keeping recent staggered motion when all three fingers land together.
      for (final id in _activePointers.keys) {
        final downTime = _pointerDownTimes[id];
        if (downTime != null && now.difference(downTime) > maxRestOriginAge) {
          _pointerOrigins[id] = _activePointers[id]!;
          _pointerDownTimes[id] = now;
        }
      }

      if (!_hasTriggeredInStroke) {
        _evaluateSwipe();
      }
    }

    if (!wasMultiTouch && isMultiTouchActive) {
      onMultiTouchStateChanged?.call(true);
    }
  }

  /// Updates enrolled pointer movement and fires [onSwipe] once past threshold.
  void handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) {
      return;
    }

    _activePointers[event.pointer] = event.position;

    if (!_threeFingerEngaged || _hasTriggeredInStroke) {
      return;
    }

    _evaluateSwipe();
  }

  /// Handles pointer release.
  void handlePointerUp(PointerUpEvent event) => _removePointer(event.pointer);

  /// Handles OS pointer cancellation (e.g., system edge gesture interception).
  void handlePointerCancel(PointerCancelEvent event) => _removePointer(event.pointer);

  /// Clears all active pointer tracking (e.g., when opening a modal dialog/sheet).
  void reset() {
    final wasMultiTouch = isMultiTouchActive;
    _activePointers.clear();
    _pointerOrigins.clear();
    _pointerDownTimes.clear();
    _completedStrokeDeltas.clear();
    _peakPointersInStroke = 0;
    _threeFingerEngaged = false;
    _hasTriggeredInStroke = false;
    if (wasMultiTouch) {
      onMultiTouchStateChanged?.call(false);
    }
  }

  void _evaluateSwipe() {
    double totalDx = 0.0;
    double totalDy = 0.0;
    int count = 0;

    for (final entry in _activePointers.entries) {
      final origin = _pointerOrigins[entry.key];
      if (origin != null) {
        totalDx += (entry.value.dx - origin.dx);
        totalDy += (entry.value.dy - origin.dy);
        count++;
      }
    }

    for (final delta in _completedStrokeDeltas.values) {
      totalDx += delta.dx;
      totalDy += delta.dy;
      count++;
    }

    if (count < 3) return;

    final avgDx = totalDx / count;
    final avgDy = totalDy / count;
    final absDx = avgDx.abs();
    final absDy = avgDy.abs();

    // Require clear horizontal intent ("almost same line") while staying
    // forgiving of natural wrist/finger arc across the center zone.
    if (absDx >= swipeThreshold && absDx >= absDy * 0.7) {
      _hasTriggeredInStroke = true;
      onSwipe(
        avgDx < 0
            ? ThreeFingerSwipeDirection.left
            : ThreeFingerSwipeDirection.right,
      );
    }
  }

  void _removePointer(int pointer) {
    if (!_activePointers.containsKey(pointer)) {
      return;
    }

    final wasMultiTouch = isMultiTouchActive;
    final lastPos = _activePointers.remove(pointer);
    final origin = _pointerOrigins.remove(pointer);
    _pointerDownTimes.remove(pointer);

    // Keep displacement of an early-lifted finger if >= 2 fingers remain down
    // so a fast flick completing with 2 remaining fingers still fires cleanly.
    if (_threeFingerEngaged &&
        !_hasTriggeredInStroke &&
        _activePointers.length >= 2 &&
        lastPos != null &&
        origin != null) {
      _completedStrokeDeltas[pointer] = lastPos - origin;
    }

    if (wasMultiTouch && !isMultiTouchActive) {
      onMultiTouchStateChanged?.call(false);
    }

    if (_activePointers.length <= 1) {
      if (_threeFingerEngaged) {
        _lastThreeFingerEndTime = _clock();
      }
      _threeFingerEngaged = false;
      _hasTriggeredInStroke = false;
      _completedStrokeDeltas.clear();

      final now = _clock();
      for (final id in _activePointers.keys) {
        _pointerOrigins[id] = _activePointers[id]!;
        _pointerDownTimes[id] = now;
      }
    }

    if (_activePointers.isEmpty) {
      if (_peakPointersInStroke >= 3) {
        _lastThreeFingerEndTime = _clock();
      }
      _peakPointersInStroke = 0;
    }
  }
}
