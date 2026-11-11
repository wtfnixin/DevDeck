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
  group('ThreeFingerSwipeDetector', () {
    test('detects 3-finger horizontal swipe left and right when lined up in middle', () {
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 26.0,
        onSwipe: triggered.add,
      );

      // 3 fingers lined up side-by-side horizontally (Mac touchpad style)
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(360, 192)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 204)));

      // Quick swipe left by 30dp with slight natural vertical wobble
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(270, 205)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(330, 197)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(390, 209)));

      expect(triggered, [ThreeFingerSwipeDirection.left]);

      // Continuing same stroke or grazing with a 4th finger should NOT double trigger
      detector.handlePointerDown(const PointerDownEvent(pointer: 4, position: Offset(440, 210)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(200, 203)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(260, 195)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(320, 206)));
      expect(triggered, [ThreeFingerSwipeDirection.left]);

      // Lift all fingers
      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(200, 203)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(260, 195)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 3, position: Offset(320, 206)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 4, position: Offset(440, 210)));

      // Fresh 3-finger swipe right
      detector.handlePointerDown(const PointerDownEvent(pointer: 5, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 6, position: Offset(360, 195)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 7, position: Offset(420, 202)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 5, position: Offset(332, 201)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 6, position: Offset(392, 196)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 7, position: Offset(452, 203)));

      expect(triggered, [
        ThreeFingerSwipeDirection.left,
        ThreeFingerSwipeDirection.right,
      ]);
    });

    test('scopes enrollment to middle + nearby zone while tracking outward exit', () {
      const width = 840.0;
      const height = 390.0;
      final triggered = <ThreeFingerSwipeDirection>[];

      bool inMiddleZone(Offset pos) {
        final dxRatio = pos.dx / width;
        final dyRatio = pos.dy / height;
        return dxRatio >= 0.15 &&
            dxRatio <= 0.85 &&
            dyRatio >= 0.08 &&
            dyRatio <= 0.92;
      }

      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 26.0,
        isPositionInActiveZone: inMiddleZone,
        onSwipe: triggered.add,
      );

      // Edge touches (outer 15% on left & right ends) must be ignored completely
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(40, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(80, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(790, 200)));
      expect(detector.isMultiTouchActive, isFalse);
      expect(detector.shouldSuppressSingleFinger, isFalse);

      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(140, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(180, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(730, 200)));
      expect(triggered, isEmpty);

      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(140, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(180, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 3, position: Offset(730, 200)));

      // Touching near edge with a thumb (ignored) + 2 fingers in middle does NOT false-trigger
      detector.handlePointerDown(const PointerDownEvent(pointer: 10, position: Offset(40, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 11, position: Offset(400, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 12, position: Offset(460, 200)));
      expect(detector.shouldSuppressSingleFinger, isFalse);
      detector.handlePointerMove(const PointerMoveEvent(pointer: 11, position: Offset(460, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 12, position: Offset(520, 200)));
      expect(triggered, isEmpty);
      detector.handlePointerUp(const PointerUpEvent(pointer: 10, position: Offset(40, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 11, position: Offset(460, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 12, position: Offset(520, 200)));

      // Swiping with 3 fingers starting inside middle zone (620, 660, 700 <= 714)
      // still completes even if one finger crosses beyond x=714 during the swipe
      detector.handlePointerDown(const PointerDownEvent(pointer: 20, position: Offset(620, 195)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 21, position: Offset(660, 195)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 22, position: Offset(700, 195)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 20, position: Offset(655, 195)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 21, position: Offset(695, 195)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 22, position: Offset(735, 195)));
      expect(triggered, [ThreeFingerSwipeDirection.right]);
    });

    test('preserves staggered fast landing motion and re-anchors stale idle fingers', () {
      var now = DateTime(2026, 11, 11, 12, 0, 0);
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 26.0,
        clock: () => now,
        onSwipe: triggered.add,
      );

      // Fast staggered swipe within 30ms preserves earlier fingers' travel
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(400, 200)));
      now = now.add(const Duration(milliseconds: 12));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(365, 200)));

      now = now.add(const Duration(milliseconds: 5));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(450, 200)));
      now = now.add(const Duration(milliseconds: 10));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(350, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(420, 200)));

      // Third finger lands -> average (-50 - 30 + 0) / 3 = -26.67 >= 26 -> triggers immediately
      now = now.add(const Duration(milliseconds: 5));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(500, 200)));
      expect(triggered, [ThreeFingerSwipeDirection.left]);

      detector.reset();
      triggered.clear();

      // Stale finger resting > 250ms before 3rd finger joins must be re-anchored
      detector.handlePointerDown(const PointerDownEvent(pointer: 10, position: Offset(400, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 10, position: Offset(250, 200)));
      now = now.add(const Duration(milliseconds: 400));
      detector.handlePointerDown(const PointerDownEvent(pointer: 11, position: Offset(450, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 12, position: Offset(500, 200)));
      expect(triggered, isEmpty);
    });

    test('completes swipe even if one finger lifts/cancels slightly before threshold', () {
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 26.0,
        onSwipe: triggered.add,
      );

      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(360, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 200)));

      // Move 18dp together
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(318, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(378, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(438, 200)));
      expect(triggered, isEmpty);

      // Edge cancellation drops pointer 3 mid-stroke
      detector.handlePointerCancel(const PointerCancelEvent(pointer: 3, position: Offset(438, 200)));

      // Remaining 2 fingers finish another 14dp -> avg = (32 + 32 + 18) / 3 = 27.3 >= 26
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(332, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(392, 200)));

      expect(triggered, [ThreeFingerSwipeDirection.right]);
    });

    test('does not block 2-finger taps, blocks 3-finger taps briefly, and ignores vertical/pinch', () {
      var now = DateTime(2026, 11, 11, 12, 0, 0);
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 26.0,
        clock: () => now,
        onSwipe: triggered.add,
      );

      // 2-finger touches/taps must NOT suppress single-finger interactions
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(200, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(260, 200)));
      expect(detector.shouldSuppressSingleFinger, isFalse);
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(360, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(360, 200)));
      expect(triggered, isEmpty);
      expect(detector.shouldSuppressSingleFinger, isFalse);

      // 3-finger vertical swipe (e.g., downward screenshot swipe in landscape)
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(300, 100)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 4, position: Offset(360, 100)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 5, position: Offset(420, 100)));
      expect(detector.shouldSuppressSingleFinger, isTrue);
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(305, 220)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 4, position: Offset(365, 220)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 5, position: Offset(425, 220)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 3, position: Offset(305, 220)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 4, position: Offset(365, 220)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 5, position: Offset(425, 220)));
      expect(triggered, isEmpty);

      // Suppression expires after 35ms
      expect(detector.shouldSuppressSingleFinger, isTrue);
      now = now.add(const Duration(milliseconds: 45));
      expect(detector.shouldSuppressSingleFinger, isFalse);

      // 3-finger horizontal pinch (opposite horizontal moves cancel out)
      detector.handlePointerDown(const PointerDownEvent(pointer: 6, position: Offset(200, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 7, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 8, position: Offset(400, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 6, position: Offset(260, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 8, position: Offset(340, 200)));
      expect(triggered, isEmpty);
    });
  });

  testWidgets('landscape Listener locks PageView cleanly without rebuilds and lets middle swipe trigger',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pageController = PageController();
    addTearDown(pageController.dispose);

    var fakeNow = DateTime(2026, 11, 11, 12, 0, 0);
    int currentPage = 0;
    int keyTaps = 0;
    final swipes = <ThreeFingerSwipeDirection>[];

    late final ThreeFingerSwipeDetector detector;
    detector = ThreeFingerSwipeDetector(
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

    // 2. 3-finger horizontal swipe in the middle triggers switch, keeps PageView at 0, suppresses tap
    final g1 = await tester.startGesture(const Offset(350, 195), pointer: 10);
    final g2 = await tester.startGesture(const Offset(420, 190), pointer: 11);
    final g3 = await tester.startGesture(const Offset(490, 200), pointer: 12);
    await tester.pump();

    await g1.moveBy(const Offset(-36, 2));
    await g2.moveBy(const Offset(-36, -1));
    await g3.moveBy(const Offset(-36, 1));
    await tester.pump();

    await g1.up();
    await g2.up();
    await g3.up();
    fakeNow = fakeNow.add(const Duration(milliseconds: 45));
    await tester.pump(const Duration(milliseconds: 45));

    expect(swipes, [ThreeFingerSwipeDirection.left]);
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
