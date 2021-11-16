import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SheetMode { snap, noSnap }

/// Show the current state of bottom sheet.
/// when sheet is stationary its [idle]
/// when gesture moves up then [movingUp]
/// and similarly when moving down [movingDown]
enum BottomSheetState { idle, movingUp, movingDown }

/// provides [height] of the bottomsheet in logical pixels
/// also provides [value] which is between 0..1.
/// It's 0 for lower Bound and 1 for upper bounds
typedef OnPanelSlide = void Function(double height, double value, BottomSheetState bottomSheetState);

/// Listener class helps to provide listener between given indexs
/// the [minHeight] to [snapHeights.length]+1 which is maxHeight
/// 1,2,3 are respective index for [snapHeights] array
class SnappingListener {
  SnappingListener({
    required this.fromIndex,
    required this.toIndex,
    required this.onPanleSlide,
  });

  int fromIndex;
  int toIndex;
  OnPanelSlide onPanleSlide;
}

// App deletegate to stick the header at the top
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required Widget child, required double minExtent, required double maxExtent})
      : _child = child,
        _maxExtent = maxExtent,
        _minExtent = minExtent;

  final Widget _child;
  final double _minExtent;
  final double _maxExtent;

  @override
  double get minExtent => _minExtent;
  @override
  double get maxExtent => _maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      child: _child,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class ScrollableDraggableBottomSheet extends StatefulWidget {
  const ScrollableDraggableBottomSheet({
    Key? key,
    this.controller,
    this.minHeight = 120,
    required this.maxHeight,
    required this.snapHeights,
    this.switchChildDuration = const Duration(milliseconds: 300),
    this.onPanelSlide,
    this.onPanelSlideWithoutSnap,
    this.snappingListener,
    this.header,
    this.headerHeight,
    this.decoration,
    required this.primaryChild,
    required this.secondaryChild,
  }) : super(key: key);

  final ScrollableDraggableBottomSheetController? controller;

  final double minHeight;

  /// list of [snapHeights] as height of screen, i.e. in logical pixels
  final List<double> snapHeights;

  final double maxHeight;

  /// it provides logical height of the draggable panel
  final OnPanelSlide? onPanelSlide;

  /// it triggers when panel slides without a snap point.
  /// returns animationController value that is 0..1
  final OnPanelSlide? onPanelSlideWithoutSnap;

  // final Widget initialChild;

  final Duration switchChildDuration;

  /// provide a min and max index between 0..[snapHeights.length]+1
  /// and add [OnPanelSlide] callback to add action.
  /// provides a listener between the given two indexs
  ///
  /// helps to add listener for defined range
  /// from 0 i.e. the [minHeight] to [snapHeights.length]+1 which is maxHeight
  /// 1,2,3 are respective index for [snapHeights] array
  final SnappingListener? snappingListener;

  /// header to the bottom sheet which will always drag the sheet
  /// irrespective of the position of the scrollview
  final Widget? header;

  /// defines the height for header widget
  final double? headerHeight;

  /// decoration for bottomsheet
  final BoxDecoration? decoration;

  final Widget Function(ScrollController sc, ScrollPhysics physics) primaryChild;

  final Widget Function(ScrollController sc, ScrollPhysics physics) secondaryChild;

  @override
  _ScrollableDraggableBottomSheetState createState() => _ScrollableDraggableBottomSheetState();
}

class _ScrollableDraggableBottomSheetState extends State<ScrollableDraggableBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ScrollController _scrollcontroller;
  late ScrollController _secondaryScrollController;

  late Tween<double> _heightTween;
  late Animation _heightAnimation;

  ScrollPhysics _scrollPhysics = const NeverScrollableScrollPhysics();
  ScrollPhysics _secondaryScrollPhysics = const NeverScrollableScrollPhysics();

  SheetMode _sheetMode = SheetMode.snap;

  int _selectedChild = 0;

  // current min and max keeps changing according to position
  late double currentMin;
  late double? currentMax;

  BottomSheetState _bottomSheetState = BottomSheetState.idle;

  @override
  void initState() {
    super.initState();

    currentMin = widget.minHeight;
    currentMax = widget.snapHeights.first;

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() {
        // Listener for defined index of snap, it includes [minHeight] at index 0.
        // And [maxHeight] at index [snapHeights.length + 1]
        if (widget.snappingListener != null && widget.snapHeights.isNotEmpty) {
          final lowerBound = widget.snappingListener!.fromIndex == 0
              ? widget.minHeight
              : widget.snapHeights[widget.snappingListener!.fromIndex - 1];
          final upperBound = widget.snappingListener!.toIndex == widget.snapHeights.length + 1
              ? widget.maxHeight
              : widget.snapHeights[widget.snappingListener!.toIndex - 1];
          if (lowerBound < _heightAnimation.value && _heightAnimation.value < upperBound) {
            widget.snappingListener!
                .onPanleSlide(_heightAnimation.value, _animationController.value, _bottomSheetState);
          }
        }

        // logic for [onPanelSlide] which listens for all the values
        if (widget.onPanelSlide != null) {
          widget.onPanelSlide!(_heightAnimation.value, _animationController.value, _bottomSheetState);
        }

        // logic for [onPanelSlideWithoutSnap] which listens for all the values
        // when the mode of bottomsheet is shifted to no snap mode
        if (widget.onPanelSlideWithoutSnap != null && _sheetMode == SheetMode.noSnap) {
          widget.onPanelSlideWithoutSnap!(_heightAnimation.value, _animationController.value, _bottomSheetState);
        }

        // start the scrolling
        if (_sheetMode == SheetMode.snap) {
          if (_selectedChild == 0) {
            _snapModeScrollLogic();
          } else {
            _snapModeSecondaryScrollLogic();
          }
        } else {
          if (_selectedChild == 0) {
            _noSnapModeScrollLogic();
          } else {
            _noSnapModeSecondaryScrollLogic();
          }
        }
      });

    _heightTween = Tween(begin: currentMin, end: currentMax);
    _heightAnimation = _heightTween.animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _scrollcontroller = ScrollController(initialScrollOffset: 0)..addListener(() => _scrollListener());
    _secondaryScrollController = ScrollController(initialScrollOffset: 0)
      ..addListener(() => _secondaryScrollListener());

    widget.controller?._addState(this);
  }

  /*--------------------------------------------*/

  void _noSnapModeScrollLogic() {
    if (!_scrollcontroller.hasClients) return;

    if (_animationController.isCompleted) {
      if (_scrollPhysics is! BouncingScrollPhysics) {
        setState(() => _scrollPhysics = const BouncingScrollPhysics());
      }
    } else {
      if (_scrollPhysics is! NeverScrollableScrollPhysics) {
        _scrollcontroller.jumpTo(1);
        setState(() => _scrollPhysics = const NeverScrollableScrollPhysics());
      }
    }
  }

  /*--------------------------------------------*/

  void _noSnapModeSecondaryScrollLogic() {
    if (!_secondaryScrollController.hasClients) return;

    if (_animationController.isCompleted) {
      if (_secondaryScrollPhysics is! BouncingScrollPhysics) {
        setState(() => _secondaryScrollPhysics = const BouncingScrollPhysics());
      }
    } else {
      if (_secondaryScrollPhysics is! NeverScrollableScrollPhysics) {
        _secondaryScrollController.jumpTo(1);
        setState(() => _secondaryScrollPhysics = const NeverScrollableScrollPhysics());
      }
    }
  }

  /*--------------------------------------------*/

  void _snapModeScrollLogic() {
    if (!_scrollcontroller.hasClients) return;

    if (widget.maxHeight == _heightAnimation.value) {
      if (_scrollPhysics is! BouncingScrollPhysics) {
        setState(() => _scrollPhysics = const BouncingScrollPhysics());
      }
    } else {
      if (_scrollPhysics is! NeverScrollableScrollPhysics) {
        _scrollcontroller.jumpTo(1);
        setState(() => _scrollPhysics = const NeverScrollableScrollPhysics());
      }
    }
  }

  /*--------------------------------------------*/

  void _snapModeSecondaryScrollLogic() {
    if (!_secondaryScrollController.hasClients) return;

    if (widget.maxHeight == _heightAnimation.value) {
      if (_secondaryScrollPhysics is! BouncingScrollPhysics) {
        setState(() => _secondaryScrollPhysics = const BouncingScrollPhysics());
      }
    } else {
      if (_secondaryScrollPhysics is! NeverScrollableScrollPhysics) {
        _secondaryScrollController.jumpTo(1);
        setState(() => _secondaryScrollPhysics = const NeverScrollableScrollPhysics());
      }
    }
  }

  /*--------------------------------------------*/

  _scrollListener() {
    if (!_scrollcontroller.hasClients) return;
    // Check condition to stop the scroll and activate gesture detection
    if (_animationController.value < _animationController.upperBound ||
        _scrollcontroller.offset <= _scrollcontroller.position.minScrollExtent) {
      if (_scrollPhysics is! NeverScrollableScrollPhysics) {
        _scrollcontroller.jumpTo(1);
        setState(() => _scrollPhysics = const NeverScrollableScrollPhysics());
      }
    }
  }

  /*--------------------------------------------*/

  _secondaryScrollListener() {
    if (!_secondaryScrollController.hasClients) return;

    // Check condition to stop the scroll and activate
    // gesture detection
    if (_animationController.value < _animationController.upperBound ||
        _secondaryScrollController.offset <= _secondaryScrollController.position.minScrollExtent) {
      if (_secondaryScrollPhysics is! NeverScrollableScrollPhysics) {
        _secondaryScrollController.jumpTo(1);
        setState(() => _secondaryScrollPhysics = const NeverScrollableScrollPhysics());
      }
    }
  }

  /*--------------------------------------------*/

  @override
  void dispose() {
    _animationController.dispose();
    _scrollcontroller.dispose();
    _secondaryScrollController.dispose();
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
              decoration: widget.decoration ?? const BoxDecoration(color: Colors.white),
              child: child,
            );
          },
          child: Stack(
            children: [
              Positioned.fill(
                top: widget.headerHeight,
                child: AnimatedSwitcher(
                  duration: widget.switchChildDuration,
                  reverseDuration: widget.switchChildDuration,
                  child: _selectedChild == 0
                      ? widget.primaryChild(_scrollcontroller, _scrollPhysics)
                      : widget.secondaryChild(_secondaryScrollController, _secondaryScrollPhysics),
                ),
              ),

              // if header is provided, show the header
              if (widget.header != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: widget.headerHeight,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      _handleDragUpdate(details);
                    },
                    onVerticalDragEnd: (details) {
                      _handleDragEnd(details);
                    },
                    child: widget.header,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /*--------------------------------------------*/

  void _handleDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! > 0) {
      _bottomSheetState = BottomSheetState.movingDown;
    } else {
      _bottomSheetState = BottomSheetState.movingUp;
    }

    // Handle animation to start only after midHeight
    if (widget.snapHeights.isNotEmpty) {
      if (widget.snapHeights.contains(_heightAnimation.value)) {
        int _selectedIndex = widget.snapHeights.indexOf(_heightAnimation.value);
        double newLowerBound = _selectedIndex > 0 ? widget.snapHeights.elementAt(_selectedIndex - 1) : widget.minHeight;
        double newUpperBound = _selectedIndex < widget.snapHeights.length - 1
            ? widget.snapHeights.elementAt(_selectedIndex + 1)
            : widget.maxHeight;

        if (details.primaryDelta! > 0) {
          // going down
          _heightTween.begin = newLowerBound;
          _animationController.value = newUpperBound;
          _heightTween.end = widget.snapHeights[_selectedIndex];
        } else {
          // going up
          _heightTween.begin = widget.snapHeights[_selectedIndex];
          _animationController.reset();
          _heightTween.end = newUpperBound;
        }
      }
    }

    _animationController.value -= details.primaryDelta! / (_heightTween.end! - _heightTween.begin!);
  }

  /*--------------------------------------------*/

  void _handleDragEnd(DragEndDetails details) {
    if (_animationController.isAnimating || _animationController.status == AnimationStatus.completed) return;

    final double flingVelocity = details.velocity.pixelsPerSecond.dy / widget.maxHeight;

    _bottomSheetState = BottomSheetState.idle;

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
    setState(() => _selectedChild = 1);
  }

  _animateBackToSnap({Duration? duration, Curve curve = Curves.linear}) async {
    List<double> listHeight = [widget.minHeight, ...widget.snapHeights, widget.maxHeight];
    double currentHeight = _heightAnimation.value;
    List<double> greater = listHeight.where((e) => e >= currentHeight).toList()..sort();

    double newPosition = greater.first;

    if (!_animationController.isCompleted) {
      _heightTween.end = _heightAnimation.value;
      _animationController.value = 1;
      _heightTween.begin = newPosition;
      _animationController.animateTo(0, duration: duration, curve: curve);
    } else {
      _heightTween.begin = _heightAnimation.value;
      // _animationController.reset();
      _heightTween.end = newPosition;
      _animationController.animateTo(1, duration: duration, curve: curve);
      _heightTween.begin = widget.snapHeights.last;
    }

    // if (_heightAnimation.value < widget.minHeight) {
    //   _heightTween.end = widget.minHeight;
    //   _animationController.animateTo(1, duration: duration, curve: curve);
    // } else {
    //   // to bring the height to minimum height
    //   // if the animation is completed change end as changing the begin will cause abrupt change
    //   if (!_animationController.isCompleted) {
    //     _heightTween.end = widget.minHeight;
    //     _animationController.animateTo(1, duration: duration, curve: curve);
    //   } else {
    //     // else change begin
    //     _heightTween.begin = widget.minHeight;
    //     _animationController.animateTo(0, duration: duration, curve: curve);
    //   }
    //   if (duration != null) await Future.delayed(duration);
    //   _heightTween.begin = widget.minHeight;
    //   _animationController.reset();
    //   _heightTween.end = widget.snapHeights[0];
    // }

    _sheetMode = SheetMode.snap;
    setState(() => _selectedChild = 0);
  }

  _jumpToPosition({required int position, Duration? duration, Curve curve = Curves.linear}) {
    double newPosition;
    if (position == widget.snapHeights.length + 1) {
      newPosition = widget.maxHeight;
    } else if (position == 0) {
      newPosition = widget.minHeight;
    } else {
      newPosition = widget.snapHeights[position - 1];
    }

    if (_sheetMode == SheetMode.snap && _heightAnimation.value != newPosition) {
      if (_heightAnimation.value > newPosition) {
        _heightTween.end = _heightAnimation.value;
        _animationController.value = 1;
        _heightTween.begin = newPosition;
        _animationController.animateTo(0, duration: duration, curve: curve);
      } else {
        _heightTween.begin = _heightAnimation.value;
        _animationController.reset();
        _heightTween.end = newPosition;
        _animationController.animateTo(1, duration: duration, curve: curve);
      }

      // when position is [widget.maxHeight], we need to provide lowerbound so to return to the last snap position.
      // if this is not provided the sheet will no longer be snap sheet
      // similar approach for [widget.minHeight]
      if (position == widget.snapHeights.length + 1) {
        _heightTween.begin = widget.snapHeights.last;
      } else if (position == 0) {
        _heightTween.end = widget.snapHeights.first;
      }
    }
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
      {required double minHeight, required double maxHeight, Duration? duration, Curve curve = Curves.linear}) {
    assert(isAttached, "ScrollableDraggableBottomSheetController must be attached to a ScrollableDraggableBottomSheet");
    return _scrollableDraggableBottomSheetState!
        ._animateSheetToNewMinMax(minHeight: minHeight, maxHeight: maxHeight, duration: duration, curve: curve);
  }

  Future<void> animateBackToSnap({Duration? duration, Curve curve = Curves.linear}) {
    return _scrollableDraggableBottomSheetState?._animateBackToSnap(duration: duration, curve: curve);
  }

  void jumpToPosition({required int position, Duration? duration, Curve curve = Curves.linear}) {
    _scrollableDraggableBottomSheetState?._jumpToPosition(position: position, duration: duration, curve: curve);
  }
}
