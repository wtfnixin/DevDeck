import 'package:flutter/gestures.dart';

/// Direction of a horizontal desktop swipe gesture.
enum DesktopSwipeDirection { left, right }

/// Backward compatibility alias for [DesktopSwipeDirection].
typedef ThreeFingerSwipeDirection = DesktopSwipeDirection;

/// Detects trackpad-style horizontal multi-finger swipes (2 or 3 fingers) across raw pointer events.
///
/// Supports restricting pointer enrollment to a specific active region (such as
/// the center portion of the screen), preserves fast staggered motion when fingers
/// land within [maxRestOriginAge], enforces parallel direction consensus (rejecting pinches),
/// retains early-lifted finger displacements mid-stroke, and latches one trigger per stroke.
class MultiFingerSwipeDetector {
  MultiFingerSwipeDetector({
    this.requiredFingers = 2,
    this.swipeThreshold = 26.0,
    this.maxRestOriginAge = const Duration(milliseconds: 250),
    this.isPositionInActiveZone,
    required this.onSwipe,
    this.onMultiTouchStateChanged,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Number of fingers required for the gesture (typically 2 for mobile, 3 for Mac style, or 0 to disable).
  int requiredFingers;
  final double swipeThreshold;
  final Duration maxRestOriginAge;
  final bool Function(Offset position)? isPositionInActiveZone;
  final void Function(DesktopSwipeDirection direction) onSwipe;
  final void Function(bool isMultiTouchActive)? onMultiTouchStateChanged;
  final DateTime Function() _clock;

  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _pointerOrigins = {};
  final Map<int, DateTime> _pointerDownTimes = {};
  final Map<int, Offset> _completedStrokeDeltas = {};

  int _peakPointersInStroke = 0;
  bool _gestureEngaged = false;
  bool _hasTriggeredInStroke = false;
  DateTime? _lastGestureEndTime;

  /// True while enough enrolled pointers are currently touching the active zone.
  bool get isMultiTouchActive =>
      requiredFingers > 0 && _activePointers.length >= requiredFingers;

  /// True while a multi-finger stroke is engaged or within 35ms of ending,
  /// preventing accidental button taps from firing on finger lift without
  /// blocking normal single-finger interactions.
  bool get shouldSuppressSingleFinger {
    if (requiredFingers <= 0) return false;
    if (_gestureEngaged || _peakPointersInStroke >= requiredFingers) return true;
    final endedAt = _lastGestureEndTime;
    if (endedAt == null) return false;
    return _clock().difference(endedAt) < const Duration(milliseconds: 35);
  }

  /// Enrolls pointers touching inside [isPositionInActiveZone] and engages
  /// detection once [requiredFingers] pointers are active.
  void handlePointerDown(PointerDownEvent event) {
    if (requiredFingers <= 0) return;

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

    if (!_gestureEngaged && _activePointers.length >= requiredFingers) {
      _gestureEngaged = true;
      _completedStrokeDeltas.clear();

      // Re-anchor pointers that rested idle longer than maxRestOriginAge while
      // keeping recent staggered motion when fingers land together.
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
    if (requiredFingers <= 0 || !_activePointers.containsKey(event.pointer)) {
      return;
    }

    _activePointers[event.pointer] = event.position;

    if (!_gestureEngaged || _hasTriggeredInStroke) {
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
    _gestureEngaged = false;
    _hasTriggeredInStroke = false;
    if (wasMultiTouch) {
      onMultiTouchStateChanged?.call(false);
    }
  }

  void _evaluateSwipe() {
    if (requiredFingers <= 0) return;

    final deltas = <int, Offset>{};
    double totalDx = 0.0;
    double totalDy = 0.0;

    for (final entry in _activePointers.entries) {
      final origin = _pointerOrigins[entry.key];
      if (origin != null) {
        final delta = entry.value - origin;
        deltas[entry.key] = delta;
        totalDx += delta.dx;
        totalDy += delta.dy;
      }
    }

    for (final entry in _completedStrokeDeltas.entries) {
      deltas[entry.key] = entry.value;
      totalDx += entry.value.dx;
      totalDy += entry.value.dy;
    }

    if (deltas.length < requiredFingers) return;

    final avgDx = totalDx / deltas.length;
    final avgDy = totalDy / deltas.length;
    final absDx = avgDx.abs();
    final absDy = avgDy.abs();

    // Parallel movement check:
    // If swiping in one direction, no finger should be moving backwards against the general swipe.
    // This rejects pinches (zooming in/out) and opposite-direction rotational swipes.
    for (final delta in deltas.values) {
      if ((avgDx < 0 && delta.dx > 4.0) || (avgDx > 0 && delta.dx < -4.0)) {
        return;
      }
    }

    // Require clear horizontal intent while staying forgiving of natural wrist/finger arc.
    if (absDx >= swipeThreshold && absDx >= absDy * 0.7) {
      _hasTriggeredInStroke = true;
      onSwipe(
        avgDx < 0
            ? DesktopSwipeDirection.left
            : DesktopSwipeDirection.right,
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

    // Keep displacement of an early-lifted finger if enough fingers remain down
    // so a fast flick completing as a finger lifts still fires cleanly.
    final minRemainingForStroke = requiredFingers == 2 ? 1 : (requiredFingers - 1);
    if (_gestureEngaged &&
        !_hasTriggeredInStroke &&
        _activePointers.length >= minRemainingForStroke &&
        lastPos != null &&
        origin != null) {
      _completedStrokeDeltas[pointer] = lastPos - origin;
      _evaluateSwipe();
    }

    if (wasMultiTouch && !isMultiTouchActive) {
      onMultiTouchStateChanged?.call(false);
    }

    if (_activePointers.length < minRemainingForStroke) {
      if (_gestureEngaged) {
        _lastGestureEndTime = _clock();
      }
      _gestureEngaged = false;
      _hasTriggeredInStroke = false;
      _completedStrokeDeltas.clear();

      final now = _clock();
      for (final id in _activePointers.keys) {
        _pointerOrigins[id] = _activePointers[id]!;
        _pointerDownTimes[id] = now;
      }
    }

    if (_activePointers.isEmpty) {
      if (_peakPointersInStroke >= requiredFingers) {
        _lastGestureEndTime = _clock();
      }
      _peakPointersInStroke = 0;
    }
  }
}

/// Backward compatibility alias for [MultiFingerSwipeDetector].
typedef ThreeFingerSwipeDetector = MultiFingerSwipeDetector;
