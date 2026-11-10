import 'package:flutter/gestures.dart';

/// Direction of a horizontal three-finger swipe gesture.
enum ThreeFingerSwipeDirection { left, right }

/// Detects Mac-touchpad-style horizontal three-finger swipes across raw pointer events.
///
/// Tracks average centroid displacement once three pointers engage, rejects
/// predominantly vertical or pinch motions, and latches each stroke so one
/// continuous swipe switches exactly one desktop until fingers lift.
class ThreeFingerSwipeDetector {
  ThreeFingerSwipeDetector({
    this.swipeThreshold = 36.0,
    required this.onSwipe,
    this.onMultiTouchStateChanged,
  });

  final double swipeThreshold;
  final void Function(ThreeFingerSwipeDirection direction) onSwipe;
  final void Function(bool isMultiTouchActive)? onMultiTouchStateChanged;

  final Map<int, Offset> _activePointers = {};
  int _peakPointersInStroke = 0;
  bool _threeFingerEngaged = false;
  bool _hasTriggeredInStroke = false;
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  DateTime? _lastMultiTouchEndTime;

  /// True while two or more pointers are currently touching the screen.
  bool get isMultiTouchActive => _activePointers.length >= 2;

  /// True while a multi-touch stroke is active or immediately after it ends,
  /// preventing single-finger taps or drags from firing concurrently.
  bool get shouldSuppressSingleFinger {
    if (_peakPointersInStroke >= 2) return true;
    final endedAt = _lastMultiTouchEndTime;
    if (endedAt == null) return false;
    return DateTime.now().difference(endedAt) < const Duration(milliseconds: 180);
  }

  /// Records a pointer down event and engages three-finger tracking when >= 3 fingers touch.
  void handlePointerDown(PointerDownEvent event) {
    final wasMultiTouch = isMultiTouchActive;
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length > _peakPointersInStroke) {
      _peakPointersInStroke = _activePointers.length;
    }

    // Start measuring displacement cleanly once all 3 fingers are down so
    // early drift from the first landing finger does not skew the swipe.
    if (!_threeFingerEngaged && _activePointers.length >= 3) {
      _threeFingerEngaged = true;
      _accumulatedDx = 0.0;
      _accumulatedDy = 0.0;
    }

    if (!wasMultiTouch && isMultiTouchActive) {
      onMultiTouchStateChanged?.call(true);
    }
  }

  /// Accumulates centroid movement across active pointers and triggers once past threshold.
  void handlePointerMove(PointerMoveEvent event) {
    final previous = _activePointers[event.pointer];
    _activePointers[event.pointer] = event.position;

    if (!_threeFingerEngaged || _hasTriggeredInStroke || previous == null) {
      return;
    }

    final activeCount = _activePointers.length;
    if (activeCount < 2) {
      return;
    }

    final stepDx = event.position.dx - previous.dx;
    final stepDy = event.position.dy - previous.dy;

    _accumulatedDx += stepDx / activeCount;
    _accumulatedDy += stepDy / activeCount;

    final absDx = _accumulatedDx.abs();
    final absDy = _accumulatedDy.abs();

    // Require clear horizontal dominance ("almost same line") so vertical
    // swipes do not misfire while tolerating natural finger arc.
    if (absDx >= swipeThreshold && absDx >= absDy * 0.85) {
      _hasTriggeredInStroke = true;
      onSwipe(
        _accumulatedDx < 0
            ? ThreeFingerSwipeDirection.left
            : ThreeFingerSwipeDirection.right,
      );
    }
  }

  /// Handles pointer release.
  void handlePointerUp(PointerUpEvent event) => _removePointer(event.pointer);

  /// Handles OS pointer cancellation (e.g., system edge gesture interception).
  void handlePointerCancel(PointerCancelEvent event) => _removePointer(event.pointer);

  /// Clears all active pointer tracking (e.g., when opening a modal dialog/sheet).
  void reset() {
    final wasMultiTouch = isMultiTouchActive;
    _activePointers.clear();
    _peakPointersInStroke = 0;
    _threeFingerEngaged = false;
    _hasTriggeredInStroke = false;
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
    if (wasMultiTouch) {
      onMultiTouchStateChanged?.call(false);
    }
  }

  void _removePointer(int pointer) {
    final wasMultiTouch = isMultiTouchActive;
    _activePointers.remove(pointer);

    if (wasMultiTouch && !isMultiTouchActive) {
      onMultiTouchStateChanged?.call(false);
    }

    if (_activePointers.length <= 1) {
      // Allow starting a fresh 3-finger swipe even if 1 finger rests on screen,
      // while resisting 3 -> 2 -> 3 mid-stroke finger bounce double triggers.
      _threeFingerEngaged = false;
      _hasTriggeredInStroke = false;
      _accumulatedDx = 0.0;
      _accumulatedDy = 0.0;
    }

    if (_activePointers.isEmpty) {
      if (_peakPointersInStroke >= 2) {
        _lastMultiTouchEndTime = DateTime.now();
      }
      _peakPointersInStroke = 0;
    }
  }
}
