import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef OnPanelSlide = void Function(double position);

class ScrollableDraggableBottomSheet extends StatefulWidget {
  const ScrollableDraggableBottomSheet(
      {Key? key,
      this.controller,
      this.minHeight = 120,
      required this.maxHeight,
      this.snapHeight,
      this.onPanelSlideFromSnapPointToMax,
      required this.initialChild,
      this.switchChildDuration = const Duration(milliseconds: 300)})
      : super(key: key);

  final ScrollableDraggableBottomSheetController? controller;

  final double minHeight;

  /// [snapHeight] as height of screen
  final double? snapHeight;

  final double maxHeight;

  final OnPanelSlide? onPanelSlideFromSnapPointToMax;

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

  late Widget _selectedChild;

  // current min and max keeps changing according to position
  late double currentMin;
  late double? currentMax;

  @override
  void initState() {
    super.initState();
    _selectedChild = widget.initialChild;

    currentMin = widget.minHeight;
    currentMax = widget.snapHeight ?? widget.maxHeight;

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() {
        // method runs when going from midHeight to top
        if (widget.onPanelSlideFromSnapPointToMax != null &&
            widget.snapHeight != null &&
            _heightTween.begin == widget.snapHeight &&
            _heightTween.end == widget.maxHeight) {
          widget.onPanelSlideFromSnapPointToMax!(_animationController.value);
        }
      });

    _heightTween = Tween(begin: currentMin, end: currentMax);
    _heightAnimation = _heightTween.animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _scrollcontroller = ScrollController(initialScrollOffset: 0)
      ..addListener(() {
        // Check condition to stop the scroll and activate gesture detection
        if (_animationController.value < _animationController.upperBound ||
            _scrollcontroller.offset <= _scrollcontroller.position.minScrollExtent) {
          _scrollcontroller.animateTo(0, duration: const Duration(milliseconds: 1), curve: Curves.linear);
          setState(() {
            _scrollPhysics = const NeverScrollableScrollPhysics();
          });
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
              // padding: const EdgeInsets.symmetric(horizontal: 32),
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

    // Check multiple factors to enable scrolling
    // * 1. animation contoller is completely open
    // * 2. _heightTween == maxHeight which checks it's total open position and not the snap point
    // * 3. check primary delta which when negative which means user tried to scroll upwards
    if (_animationController.value >= _animationController.upperBound && details.primaryDelta! < 0) {
      setState(() {
        _scrollPhysics = const BouncingScrollPhysics();
      });
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

    if (child != null) setState(() => _selectedChild = child);
  }

  _animateBackToSnap({Duration? duration, Curve curve = Curves.linear, Widget? child}) async {
    assert(widget.snapHeight != null, 'cannot animate back to snap as snap position not available');
    if (_heightAnimation.value < widget.snapHeight) {
      _heightTween.end = widget.snapHeight!;
      _animationController.animateTo(1, duration: duration, curve: curve);
    } else {
      _heightTween.begin = widget.snapHeight!;
      _animationController.animateTo(0, duration: duration, curve: curve);
    }

    if (child != null) setState(() => _selectedChild = child);
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
}
