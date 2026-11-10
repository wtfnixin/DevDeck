import 'package:devdeck/core/utils/three_finger_swipe_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThreeFingerSwipeDetector', () {
    test('detects 3-finger horizontal swipe left and right when lined up horizontally', () {
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 36.0,
        onSwipe: triggered.add,
      );

      // 3 fingers lined up side-by-side horizontally (Mac touchpad style)
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(360, 192)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 204)));

      // Swipe left by 42dp with tiny natural vertical wobble
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(258, 203)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(318, 195)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(378, 206)));

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
      detector.handlePointerMove(const PointerMoveEvent(pointer: 5, position: Offset(345, 201)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 6, position: Offset(405, 196)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 7, position: Offset(465, 203)));

      expect(triggered, [
        ThreeFingerSwipeDirection.left,
        ThreeFingerSwipeDirection.right,
      ]);
    });

    test('completes swipe even if one finger lifts/cancels slightly before threshold', () {
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 36.0,
        onSwipe: triggered.add,
      );

      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(360, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 200)));

      // Move 25dp together
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(325, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(385, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(445, 200)));
      expect(triggered, isEmpty);

      // Edge cancellation drops pointer 3 mid-stroke
      detector.handlePointerCancel(const PointerCancelEvent(pointer: 3, position: Offset(445, 200)));

      // Remaining 2 fingers finish another 15dp (total 40dp >= 36dp)
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(340, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(400, 200)));

      expect(triggered, [ThreeFingerSwipeDirection.right]);
    });

    test('ignores 1-finger, 2-finger, vertical 3-finger, and pinch motions', () {
      final triggered = <ThreeFingerSwipeDirection>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 36.0,
        onSwipe: triggered.add,
      );

      // 2-finger horizontal swipe
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(200, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(260, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(360, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(300, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(360, 200)));
      expect(triggered, isEmpty);

      // 3-finger vertical swipe (e.g., downward screenshot swipe in landscape)
      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(300, 100)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 4, position: Offset(360, 100)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 5, position: Offset(420, 100)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(305, 220)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 4, position: Offset(365, 220)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 5, position: Offset(425, 220)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 3, position: Offset(305, 220)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 4, position: Offset(365, 220)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 5, position: Offset(425, 220)));
      expect(triggered, isEmpty);

      // 3-finger horizontal pinch (opposite horizontal moves cancel out)
      detector.handlePointerDown(const PointerDownEvent(pointer: 6, position: Offset(200, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 7, position: Offset(300, 200)));
      detector.handlePointerDown(const PointerDownEvent(pointer: 8, position: Offset(400, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 6, position: Offset(260, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 8, position: Offset(340, 200)));
      expect(triggered, isEmpty);
    });

    test('suppresses single-finger interactions during multi-touch and ignores pre-3-finger drift', () {
      final triggered = <ThreeFingerSwipeDirection>[];
      final multiTouchStates = <bool>[];
      final detector = ThreeFingerSwipeDetector(
        swipeThreshold: 36.0,
        onSwipe: triggered.add,
        onMultiTouchStateChanged: multiTouchStates.add,
      );

      // First finger touches down and slides right 25px before other fingers land
      detector.handlePointerDown(const PointerDownEvent(pointer: 1, position: Offset(300, 200)));
      expect(detector.shouldSuppressSingleFinger, isFalse);
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(325, 200)));

      detector.handlePointerDown(const PointerDownEvent(pointer: 2, position: Offset(360, 200)));
      expect(detector.isMultiTouchActive, isTrue);
      expect(detector.shouldSuppressSingleFinger, isTrue);

      detector.handlePointerDown(const PointerDownEvent(pointer: 3, position: Offset(420, 200)));
      expect(multiTouchStates, [true]);

      // Small 20px swipe left must NOT trigger (pre-landing +25px is ignored, -20px < 36px)
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(305, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(340, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(400, 200)));
      expect(triggered, isEmpty);

      // Continue left another 20px -> -40px >= 36px triggers cleanly
      detector.handlePointerMove(const PointerMoveEvent(pointer: 1, position: Offset(285, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 2, position: Offset(320, 200)));
      detector.handlePointerMove(const PointerMoveEvent(pointer: 3, position: Offset(380, 200)));
      expect(triggered, [ThreeFingerSwipeDirection.left]);

      detector.handlePointerUp(const PointerUpEvent(pointer: 1, position: Offset(285, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 2, position: Offset(320, 200)));
      detector.handlePointerUp(const PointerUpEvent(pointer: 3, position: Offset(380, 200)));
      expect(multiTouchStates, [true, false]);
      expect(detector.shouldSuppressSingleFinger, isTrue);
    });
  });

  testWidgets('landscape Listener locks PageView and triggers swipe without firing key taps',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pageController = PageController();
    addTearDown(pageController.dispose);

    int currentPage = 0;
    int keyTaps = 0;
    final swipes = <ThreeFingerSwipeDirection>[];
    StateSetter? rebuildWidget;

    final detector = ThreeFingerSwipeDetector(
      swipeThreshold: 36.0,
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
        rebuildWidget?.call(() {});
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildWidget = setState;

            return Scaffold(
              body: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: detector.handlePointerDown,
                onPointerMove: detector.handlePointerMove,
                onPointerUp: detector.handlePointerUp,
                onPointerCancel: detector.handlePointerCancel,
                child: PageView(
                  controller: pageController,
                  physics: detector.isMultiTouchActive
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (p) => currentPage = p,
                  children: [
                    Center(
                      child: GestureDetector(
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
            );
          },
        ),
      ),
    );

    final g1 = await tester.startGesture(const Offset(350, 195), pointer: 10);
    final g2 = await tester.startGesture(const Offset(420, 190), pointer: 11);
    final g3 = await tester.startGesture(const Offset(490, 200), pointer: 12);
    await tester.pump();

    await g1.moveBy(const Offset(-60, 2));
    await g2.moveBy(const Offset(-60, -1));
    await g3.moveBy(const Offset(-60, 1));
    await tester.pump();

    await g1.up();
    await g2.up();
    await g3.up();
    await tester.pumpAndSettle();

    expect(swipes, [ThreeFingerSwipeDirection.left]);
    expect(currentPage, 0);
    expect(keyTaps, 0);
  });
}
