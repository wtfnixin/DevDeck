import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/dependency_injection/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/gesture_bloc.dart';
import '../bloc/gesture_event.dart';
import '../bloc/gesture_state.dart';

class GesturePadPage extends StatefulWidget {
  const GesturePadPage({super.key});

  @override
  State<GesturePadPage> createState() => _GesturePadPageState();
}

class _GesturePadPageState extends State<GesturePadPage> {
  double _startX = 0.0;
  double _startY = 0.0;
  double _lastX = 0.0;
  double _lastY = 0.0;
  bool _swipeTriggered = false;
  String _activeFeedbackText = 'Swipe or Tap here';
  Color _feedbackColor = AppTheme.textSecondary.withOpacity(0.5);

  final List<Map<String, String>> _mappings = const [
    {'gesture': 'Swipe Left', 'action': 'Switch to Desktop (Right)'},
    {'gesture': 'Swipe Right', 'action': 'Switch to Desktop (Left)'},
    {'gesture': 'Swipe Up', 'action': 'Open Start Menu'},
    {'gesture': 'Swipe Down', 'action': 'Show Desktop'},
    {'gesture': 'Double Tap', 'action': 'Launch Developer Workspace'},
    {'gesture': 'Long Press', 'action': 'Launch Calculator App'},
  ];

  // Multi-touch 3-finger gesture tracking for virtual desktop switching
  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _pointerStartPositions = {};
  bool _hasTriggeredThreeFinger = false;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    _pointerStartPositions[event.pointer] = event.position;
    if (_activePointers.length >= 3) {
      _hasTriggeredThreeFinger = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length >= 3 && !_hasTriggeredThreeFinger) {
      double totalDx = 0;
      int validFingers = 0;

      for (final entry in _activePointers.entries) {
        final start = _pointerStartPositions[entry.key];
        if (start != null) {
          totalDx += (entry.value.dx - start.dx);
          validFingers++;
        }
      }

      if (validFingers >= 3) {
        final avgDx = totalDx / validFingers;
        const double swipeThreshold = 40.0;

        if (avgDx < -swipeThreshold) {
          _hasTriggeredThreeFinger = true;
          _triggerGesture('swipe_left', 'Desktop Right');
        } else if (avgDx > swipeThreshold) {
          _hasTriggeredThreeFinger = true;
          _triggerGesture('swipe_right', 'Desktop Left');
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _pointerStartPositions.remove(event.pointer);
    if (_activePointers.length < 3) {
      _hasTriggeredThreeFinger = false;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _pointerStartPositions.remove(event.pointer);
    if (_activePointers.length < 3) {
      _hasTriggeredThreeFinger = false;
    }
  }

  void _triggerGesture(String gestureType, String displayLabel) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeFeedbackText = '$displayLabel Triggered!';
      _feedbackColor = AppTheme.secondaryColor;
    });

    if (gestureType == 'swipe_left') {
      sl<SocketService>().emit('desktop:switch', {'direction': 'right'});
    } else if (gestureType == 'swipe_right') {
      sl<SocketService>().emit('desktop:switch', {'direction': 'left'});
    }

    context.read<GestureBloc>().add(GestureTriggerEvent(gestureType));

    // Reset feedback text after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _activeFeedbackText = 'Swipe or Tap here';
          _feedbackColor = AppTheme.textSecondary.withOpacity(0.5);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Controller'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: BlocListener<GestureBloc, GestureState>(
          listener: (context, state) {
            if (state is GestureTriggerFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Interactive Pad
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onPanStart: (details) {
                    _startX = details.localPosition.dx;
                    _startY = details.localPosition.dy;
                    _lastX = details.localPosition.dx;
                    _lastY = details.localPosition.dy;
                    _swipeTriggered = false;
                  },
                  onPanUpdate: (details) {
                    _lastX = details.localPosition.dx;
                    _lastY = details.localPosition.dy;
                    if (_swipeTriggered) return;

                    final currentX = details.localPosition.dx;
                    final currentY = details.localPosition.dy;

                    final deltaX = currentX - _startX;
                    final deltaY = currentY - _startY;

                    const swipeThreshold = 60.0;

                    if (deltaX.abs() > swipeThreshold && deltaX.abs() > deltaY.abs()) {
                      _swipeTriggered = true;
                      if (deltaX > 0) {
                        _triggerGesture('swipe_right', 'Swipe Right');
                      } else {
                        _triggerGesture('swipe_left', 'Swipe Left');
                      }
                    } else if (deltaY.abs() > swipeThreshold && deltaY.abs() > deltaX.abs()) {
                      _swipeTriggered = true;
                      if (deltaY > 0) {
                        _triggerGesture('swipe_down', 'Swipe Down');
                      } else {
                        _triggerGesture('swipe_up', 'Swipe Up');
                      }
                    }
                  },
                  onDoubleTap: () => _triggerGesture('double_tap', 'Double Tap'),
                  onLongPress: () => _triggerGesture('long_press', 'Long Press'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle trackpad grid design lines
                        Positioned.fill(
                          child: GridPaper(
                            color: Colors.white.withOpacity(0.015),
                            divisions: 2,
                            subdivisions: 1,
                          ),
                        ),
                        // Circular trackpad center glow
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Action visual indicator
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 72,
                              color: _feedbackColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activeFeedbackText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _feedbackColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Gesture Mappings Card
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Gesture Mappings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _mappings.length,
                          separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05)),
                          itemBuilder: (context, index) {
                            final map = _mappings[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getGestureIcon(map['gesture']!),
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        map['gesture']!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    map['action']!,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  IconData _getGestureIcon(String gesture) {
    if (gesture.contains('Left')) return Icons.arrow_back_rounded;
    if (gesture.contains('Right')) return Icons.arrow_forward_rounded;
    if (gesture.contains('Up')) return Icons.arrow_upward_rounded;
    if (gesture.contains('Down')) return Icons.arrow_downward_rounded;
    if (gesture.contains('Double')) return Icons.touch_app_rounded;
    return Icons.gesture_rounded;
  }
}
