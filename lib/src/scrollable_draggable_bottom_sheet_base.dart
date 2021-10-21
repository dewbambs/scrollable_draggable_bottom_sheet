import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SheetMode { snap, noSnap }

typedef OnPanelSlide = void Function(double position);

class ScrollableDraggableBottomSheet extends StatefulWidget {
  const ScrollableDraggableBottomSheet({
    Key? key,
    this.controller,
    this.minHeight = 120,
    required this.maxHeight,
    required this.snapHeight,
    this.onPanelSlideFromSnapPointToMax,
    required this.initialChild,
    this.switchChildDuration = const Duration(milliseconds: 300),
    this.onPanelSlide,
    this.onPanelSlideWithoutSnap,
  }) : super(key: key);

  final ScrollableDraggableBottomSheetController? controller;

  final double minHeight;

  /// [snapHeight] as height of screen
  final double snapHeight;

  final double maxHeight;

  /// When panel [snapHeight] is provided. And panel is moving from
  /// the snap point to the top position
  final OnPanelSlide? onPanelSlideFromSnapPointToMax;

  /// it provides logical height of the draggable panel
  final OnPanelSlide? onPanelSlide;

  /// it triggers when panel slides without a snap point.
  /// returns animationController value that is 0..1
  final OnPanelSlide? onPanelSlideWithoutSnap;

  final Widget initialChild;

  final Duration switchChildDuration;

  @override
  _ScrollableDraggableBottomSheetState createState() => _ScrollableDraggableBottomSheetState();
}

class _ScrollableDraggableBottomSheetState extends State<ScrollableDraggableBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ScrollController _scrollcontroller;

  late Tween<double> _heightTween;
  late Animation _heightAnimation;

  ScrollPhysics _scrollPhysics = const NeverScrollableScrollPhysics();

  SheetMode _sheetMode = SheetMode.snap;

  late Widget _selectedChild;

  // current min and max keeps changing according to position
  late double currentMin;
  late double? currentMax;

  @override
  void initState() {
    super.initState();
    _selectedChild = widget.initialChild;

    currentMin = widget.minHeight;
    currentMax = widget.snapHeight;

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() {
        // method runs when going from midHeight to top
        if (widget.onPanelSlideFromSnapPointToMax != null &&
            widget.snapHeight != null &&
            _heightTween.begin == widget.snapHeight &&
            _heightTween.end == widget.maxHeight) {
          widget.onPanelSlideFromSnapPointToMax!(_animationController.value);
        }

        if (widget.onPanelSlide != null) widget.onPanelSlide!(_heightAnimation.value);

        if (widget.onPanelSlideWithoutSnap != null && _sheetMode == SheetMode.noSnap) {
          widget.onPanelSlideWithoutSnap!(_animationController.value);
        }

        // start the scrolling
        if (_sheetMode == SheetMode.snap) {
          if (widget.maxHeight == _heightAnimation.value) {
            if (_scrollPhysics is! BouncingScrollPhysics) {
              setState(() => _scrollPhysics = const BouncingScrollPhysics());
            }
          } else {
            if (_scrollPhysics is! NeverScrollableScrollPhysics) {
              setState(() => _scrollPhysics = const NeverScrollableScrollPhysics());
            }
          }
        } else {
          if (_animationController.isCompleted) {
            if (_scrollPhysics is! BouncingScrollPhysics) {
              setState(() => _scrollPhysics = const BouncingScrollPhysics());
            }
          } else {
            if (_scrollPhysics is! NeverScrollableScrollPhysics) {
              setState(() => _scrollPhysics = const NeverScrollableScrollPhysics());
            }
          }
        }
      });

    _heightTween = Tween(begin: currentMin, end: currentMax);
    _heightAnimation = _heightTween.animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _scrollcontroller = ScrollController(initialScrollOffset: 0)
      ..addListener(() {
        // Check condition to stop the scroll and activate gesture detection
        if (_animationController.value < _animationController.upperBound ||
            _scrollcontroller.offset <= _scrollcontroller.position.minScrollExtent) {
          if (_scrollPhysics is! NeverScrollableScrollPhysics) {
            setState(() => _scrollPhysics = const NeverScrollableScrollPhysics());
          }
        }
      });

    widget.controller?._addState(this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              height: _heightAnimation.value,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: child,
            );
          },
          child: SingleChildScrollView(
            controller: _scrollcontroller,
            physics: _scrollPhysics,
            child: AnimatedSwitcher(
              duration: widget.switchChildDuration,
              reverseDuration: widget.switchChildDuration,
              child: _selectedChild,
            ),
          ),
        ),
      ),
    );
  }

  /*--------------------------------------------*/

  void _handleDragUpdate(DragUpdateDetails details) {
    // Handle animation to start only after midHeight
    if (widget.snapHeight != null) {
      if (_heightAnimation.value == widget.snapHeight) {
        // going down from midHeight
        if (details.primaryDelta! > 0) {
          _heightTween.begin = widget.minHeight;
          _animationController.value = widget.maxHeight;
          _heightTween.end = widget.snapHeight;
        } else {
          // going up from midHeight
          _heightTween.begin = widget.snapHeight;
          _animationController.reset();
          _heightTween.end = widget.maxHeight;
        }
      }
    }

    _animationController.value -= details.primaryDelta! / _heightAnimation.value;
  }

  /*--------------------------------------------*/

  void _handleDragEnd(DragEndDetails details) {
    if (_animationController.isAnimating || _animationController.status == AnimationStatus.completed) return;

    final double flingVelocity = details.velocity.pixelsPerSecond.dy / widget.maxHeight;

    if (flingVelocity < 0.0) {
      _animationController.fling(velocity: math.max(1.5, -flingVelocity));
    } else if (flingVelocity > 0.0) {
      _animationController.fling(velocity: math.min(-1.5, -flingVelocity));
    } else {
      _animationController.fling(velocity: _animationController.value < 0.5 ? -1.5 : 1.5);
    }
  }

  /*--------------------------------------------*/

  _animateSheetToNewMinMax({
    required double minHeight,
    required double maxHeight,
    Duration? duration,
    Curve curve = Curves.linear,
    Widget? child,
  }) async {
    if (_heightAnimation.value < minHeight) {
      _heightTween.end = minHeight;
      _animationController.animateTo(1, duration: duration, curve: curve);
      if (duration != null) await Future.delayed(duration);
      _heightTween.begin = minHeight;
      _heightTween.end = maxHeight;
      _animationController.reset();
    } else {
      // if current height of bottom sheet is more than [minHeight]
      if (_animationController.value == 1) {
        // if animation is aready completed then change the begin value
        _heightTween.begin = minHeight;
        _animationController.animateTo(0, duration: duration, curve: curve);
        if (duration != null) await Future.delayed(duration);
        _heightTween.end = maxHeight;
        _animationController.reset();
      } else {
        _heightTween.end = minHeight;
        _animationController.animateTo(1, duration: duration, curve: curve);
        // change to correct values
        if (duration != null) await Future.delayed(duration);
        _heightTween.begin = minHeight;
        _heightTween.end = maxHeight;
        _animationController.reset();
      }
    }

    _sheetMode = SheetMode.noSnap;
    if (child != null) setState(() => _selectedChild = child);
  }

  _animateBackToSnap({Duration? duration, Curve curve = Curves.linear, Widget? child}) async {
    if (_heightAnimation.value < widget.minHeight) {
      _heightTween.end = widget.minHeight;
      _animationController.animateTo(1, duration: duration, curve: curve);
    } else {
      _heightTween.begin = widget.minHeight;
      _animationController.animateTo(0, duration: duration, curve: curve);
      if (duration != null) await Future.delayed(duration);
      _heightTween.end = widget.snapHeight;
    }

    _sheetMode = SheetMode.snap;
    if (child != null) setState(() => _selectedChild = child);
  }

  _openSheet({Duration? duration, Curve curve = Curves.linear}) {
    _heightTween.end = widget.maxHeight;
    _animationController.animateTo(1, duration: duration, curve: curve);
  }
}

// ======================================================================
// Controller for the sheet
// ======================================================================

class ScrollableDraggableBottomSheetController {
  _ScrollableDraggableBottomSheetState? _scrollableDraggableBottomSheetState;

  void _addState(_ScrollableDraggableBottomSheetState panelState) {
    _scrollableDraggableBottomSheetState = panelState;
  }

  bool get isAttached => _scrollableDraggableBottomSheetState != null;

  Future<void> animateSheetToNewMinMax(
      {required double minHeight,
      required double maxHeight,
      Duration? duration,
      Curve curve = Curves.linear,
      Widget? child}) {
    assert(isAttached, "ScrollableDraggableBottomSheetController must be attached to a ScrollableDraggableBottomSheet");
    return _scrollableDraggableBottomSheetState!._animateSheetToNewMinMax(
        minHeight: minHeight, maxHeight: maxHeight, duration: duration, curve: curve, child: child);
  }

  Future<void> animateBackToSnap({Duration? duration, Curve curve = Curves.linear, Widget? child}) {
    return _scrollableDraggableBottomSheetState?._animateBackToSnap(duration: duration, curve: curve, child: child);
  }

  void openSheet({Duration? duration, Curve curve = Curves.linear}) {
    _scrollableDraggableBottomSheetState?._openSheet(duration: duration, curve: curve);
  }
}
