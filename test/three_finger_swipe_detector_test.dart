import 'package:devdeck/core/utils/three_finger_swipe_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestLockablePagePhysics extends PageScrollPhysics {
  const _TestLockablePagePhysics({
    required this.isLocked,
    super.parent,
  });

  final bool Function() isLocked;

  @override
  _TestLockablePagePhysics applyTo(ScrollPhysics? ancestor) {
    return _TestLockablePagePhysics(
      isLocked: isLocked,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (isLocked()) return false;
    return super.shouldAcceptUserOffset(position);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isLocked()) return 0.0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    return super.createBallisticSimulation(position, isLocked() ? 0.0 : velocity);
  }
}

void main() {
  group('MultiFingerSwipeDetector (2-Finger Mode - Default)', () {
    test('detects 2-finger horizontal swipe left and right in middle zone', () {
      final triggered = <DesktopSwipeDirection>[];
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 2,
        swipeThreshold: 26.0,
        onSwipe: triggered.add,
      );

      // 2 fingers land in middle
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(360, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(420, 200)));
      expect(detector.isMultiTouchActive, isTrue);

      // Quick swipe left by 30dp
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(330, 202)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(390, 198)));

      expect(triggered, [DesktopSwipeDirection.left]);

      // Continuing stroke must NOT double trigger
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(290, 202)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(350, 198)));
      expect(triggered, [DesktopSwipeDirection.left]);

      // Lift both fingers
      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(290, 202)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(350, 198)));
      expect(detector.isMultiTouchActive, isFalse);

      // Fresh 2-finger swipe right
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(360, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 4, position: Offset(420, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(392, 201)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 4, position: Offset(452, 199)));

      expect(triggered, [
        DesktopSwipeDirection.left,
        DesktopSwipeDirection.right,
      ]);
    });

    test('rejects 2-finger pinches and opposite direction movements', () {
      final triggered = <DesktopSwipeDirection>[];
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 2,
        swipeThreshold: 26.0,
        onSwipe: triggered.add,
      );

      // Pinch: finger 1 moves right, finger 2 moves left
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(500, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(340, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(460, 200)));
      expect(triggered, isEmpty);

      detector.reset();

      // Expansion: finger 1 moves left, finger 2 moves right
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(380, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 4, position: Offset(420, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(340, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 4, position: Offset(460, 200)));
      expect(triggered, isEmpty);

      detector.reset();

      // Vertical 2-finger scroll (absDy > absDx)
      detector.handlePointerDown(const PointerDownEvent(pointer: 5, position: Offset(380, 100)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 6, position: Offset(420, 100)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 5, position: Offset(382, 180)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 6, position: Offset(422, 180)));
      expect(triggered, isEmpty);
    });

    test('completes 2-finger swipe even if one finger lifts mid-stroke', () {
      final triggered = <DesktopSwipeDirection>[];
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 2,
        swipeThreshold: 26.0,
        onSwipe: triggered.add,
      );

      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(360, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(420, 200)));

      // Fast flick where both fingers move 30dp left and finger 1 lifts right at completion
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(330, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(390, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(330, 200)));

      expect(triggered, [DesktopSwipeDirection.left]);
    });

    test('does not block 1-finger taps, blocks 2-finger taps briefly after release', () {
      var now = DateTime(2026, 11, 11, 12, 0, 0);
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 2,
        clock: () => now,
        onSwipe: (_) {},
      );

      // Single finger tap must never suppress
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(400, 200)));
      expect(detector.shouldSuppressSingleFinger, isFalse);
      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(400, 200)));
      expect(detector.shouldSuppressSingleFinger, isFalse);

      // 2 fingers engage
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(380, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 200)));
      expect(detector.shouldSuppressSingleFinger, isTrue);

      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(380, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 3, position: Offset(420, 200)));

      // 35ms post-lift grace window active
      expect(detector.shouldSuppressSingleFinger, isTrue);
      now = now.add(const Duration(milliseconds: 40));
      expect(detector.shouldSuppressSingleFinger, isFalse);
    });

    test('ignores bezel touches outside middle zone', () {
      final triggered = <DesktopSwipeDirection>[];
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 2,
        isPositionInActiveZone: (pos) => pos.dx >= 100 && pos.dx <= 700,
        onSwipe: triggered.add,
      );

      // Left thumb resting on bezel (x=50 < 100) ignored
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(50, 200)));
      expect(detector.isMultiTouchActive, isFalse);

      // Middle finger lands (x=400)
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(400, 200)));
      // Still only 1 enrolled pointer, not multi-touch
      expect(detector.isMultiTouchActive, isFalse);

      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(350, 200)));
      expect(triggered, isEmpty);
    });

    test('disabled mode (requiredFingers = 0) stays completely dormant', () {
      final triggered = <DesktopSwipeDirection>[];
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 0,
        onSwipe: triggered.add,
      );

      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(400, 200)));
      expect(detector.isMultiTouchActive, isFalse);
      expect(detector.shouldSuppressSingleFinger, isFalse);

      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(200, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(300, 200)));
      expect(triggered, isEmpty);
    });
  });

  group('MultiFingerSwipeDetector (3-Finger Mode)', () {
    test('detects 3-finger horizontal swipe left and right when configured for 3 fingers', () {
      final triggered = <DesktopSwipeDirection>[];
      final detector = MultiFingerSwipeDetector(
        requiredFingers: 3,
        swipeThreshold: 26.0,
        onSwipe: triggered.add,
      );

      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(360, 192)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 204)));

      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(270, 205)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(330, 197)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(390, 209)));

      expect(triggered, [DesktopSwipeDirection.left]);
    });
  });

  testWidgets('landscape Listener locks PageView cleanly without rebuilds and lets 2-finger swipe trigger',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pageController = PageController();
    addTearDown(pageController.dispose);

    var fakeNow = DateTime(2026, 11, 11, 12, 0, 0);
    int currentPage = 0;
    int keyTaps = 0;
    final swipes = <DesktopSwipeDirection>[];

    late final MultiFingerSwipeDetector detector;
    detector = MultiFingerSwipeDetector(
      requiredFingers: 2,
      swipeThreshold: 26.0,
      clock: () => fakeNow,
      isPositionInActiveZone: (pos) {
        final dxRatio = pos.dx / 844.0;
        final dyRatio = pos.dy / 390.0;
        return dxRatio >= 0.15 &&
            dxRatio <= 0.85 &&
            dyRatio >= 0.08 &&
            dyRatio <= 0.92;
      },
      onSwipe: (dir) {
        swipes.add(dir);
        if (pageController.hasClients) {
          pageController.jumpToPage(currentPage);
        }
      },
      onMultiTouchStateChanged: (active) {
        if (active && pageController.hasClients) {
          final p = pageController.page;
          if (p != null && p != currentPage.toDouble()) {
            pageController.jumpToPage(currentPage);
          }
        }
      },
    );

    final physics = _TestLockablePagePhysics(
      isLocked: () => detector.isMultiTouchActive,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: detector.handlePointerDown,
            onPointerMove: detector.handlePointerMove,
            onPointerUp: detector.handlePointerUp,
            onPointerCancel: detector.handlePointerCancel,
            child: PageView(
              controller: pageController,
              physics: physics,
              onPageChanged: (p) => currentPage = p,
              children: [
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!detector.shouldSuppressSingleFinger) keyTaps++;
                    },
                    child: const SizedBox(
                      width: 400,
                      height: 200,
                      child: Text('Key 1'),
                    ),
                  ),
                ),
                const Center(child: Text('Page 2')),
              ],
            ),
          ),
        ),
      ),
    );

    // 1. Single-finger tap works cleanly
    await tester.tap(find.text('Key 1'));
    await tester.pump();
    expect(keyTaps, 1);

    // 2. 2-finger horizontal swipe in the middle triggers switch, keeps PageView at 0, suppresses tap
    final g1 = await tester.startGesture(const Offset(380, 195), pointer: 10);
    final g2 = await tester.startGesture(const Offset(450, 190), pointer: 11);
    await tester.pump();

    await g1.moveBy(const Offset(-36, 1));
    await g2.moveBy(const Offset(-36, -1));
    await tester.pump();

    await g1.up();
    await g2.up();
    fakeNow = fakeNow.add(const Duration(milliseconds: 45));
    await tester.pump(const Duration(milliseconds: 45));

    expect(swipes, [DesktopSwipeDirection.left]);
    expect(currentPage, 0);
    expect(keyTaps, 1);

    // 3. Single-finger tap right after (45ms > 35ms) works immediately
    await tester.tap(find.text('Key 1'));
    await tester.pump();
    expect(keyTaps, 2);

    // 4. Single-finger horizontal drag still switches PageView cleanly
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(currentPage, 1);
  });
}
