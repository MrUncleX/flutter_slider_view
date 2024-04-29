// Copyright 2018 The FlutterCandies author. All rights reserved.
// Use of this source code is governed by an Apache license that can be found
// in the LICENSE file.

library slider_view;

import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The slide view supports custom type model [T],
/// [aspectRatio] or [width] * [height], determine switch [scrollInterval],
/// show indicators with custom [indicatorSize] and [indicatorColor],
/// callbacks when [onPageChanged].
@immutable
class SliderViewConfig<T> extends Equatable {
  const SliderViewConfig({
    required this.models,
    required this.itemBuilder,
    this.scrollDirection = Axis.horizontal,
    this.aspectRatio,
    this.width,
    this.height,
    this.viewportFraction = 1.0,
    this.autoScroll = true,
    this.autoScrollOnPointerDown = false,
    this.scrollCurve = Curves.easeInOutQuart,
    this.scrollDuration = const Duration(milliseconds: 500),
    this.scrollInterval = const Duration(seconds: 5),
    this.borderRadius = BorderRadius.zero,
    this.showIndicator = true,
    this.indicatorSize = 8,
    this.indicatorColor = Colors.white,
    this.unselectedIndicatorColor = Colors.white38,
    this.indicatorOffsetFromBottom,
    this.indicatorBuilder,
    this.onItemTap,
    this.onPageChanged,
    this.onPageIndexChanged,
    this.routeObserver,
    this.physics,
  })  : assert(
          (width != null && height != null) || aspectRatio != null,
          'At least one set of size constraints need to be set.',
        ),
        assert(
          scrollInterval - scrollDuration >= const Duration(milliseconds: 100),
          'The scrollInterval($scrollInterval) needs to be at least 100ms more '
          'than the scrollDuration($scrollDuration).',
        );

  /// Any type of models.
  final List<T> models;

  /// Build [Widget] with the given model.
  final Widget Function(T model) itemBuilder;

  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis scrollDirection;

  /// The aspect ratio of the slider view.
  ///
  /// The [width] and [height] won't be effective if it's non-null.
  final double? aspectRatio;

  /// The width of the slider view.
  ///
  /// Must be set along with [height].
  final double? width;

  /// The height of the slider view.
  ///
  /// Must be set along with [width].
  final double? height;

  /// The fraction of the viewport that each page should occupy.
  ///
  /// Defaults to 1.0, which means each page fills the viewport in the
  /// scrolling direction.
  ///
  /// Will only be assigned once when the widget is initialized.
  final double viewportFraction;

  /// Whether items are allow to scroll automatically.
  ///
  /// Defaults to true.
  final bool autoScroll;

  /// Whether items are allow to scroll automatically when pointers are down.
  ///
  /// Defaults to false.
  final bool autoScrollOnPointerDown;

  /// The [Curve] for each scrolls.
  ///
  /// Defaults to [Curves.easeInOutQuart].
  final Curve scrollCurve;

  /// The [Duration] for each scrolls.
  ///
  /// Defaults to 500 milliseconds.
  final Duration scrollDuration;

  /// The interval duration for each scrolls.
  ///
  /// Defaults to 5 seconds.
  final Duration scrollInterval;

  /// Round rects clip for the slider view.
  ///
  /// Defaults to [BorderRadius.zero].
  final BorderRadius borderRadius;

  /// Whether to displays indicators for the slider view.
  ///
  /// Defaults to true.
  final bool showIndicator;

  /// How large will indicators be.
  ///
  /// Defaults to 8.
  final double indicatorSize;

  /// What color will indicators show.
  ///
  /// Defaults to [Colors.white].
  final Color indicatorColor;

  /// What color will unselected indicators show.
  ///
  /// Defaults to [Colors.white38].
  final Color unselectedIndicatorColor;

  /// The y-axis offset of indicators from the bottom.
  final double? indicatorOffsetFromBottom;

  /// How the page view should respond to user input.
  final ScrollPhysics? physics;

  /// Build the indicator with the given interpolation of page.
  final Widget Function(
    BuildContext context,
    double interpolation,
  )? indicatorBuilder;

  /// Callback when the [model] was tapped.
  final void Function(int index, T model)? onItemTap;

  /// Callback when the [PageController.page] has changed.
  ///
  /// Note that the implementation of infinite scroll causes the [page]
  /// transition to not follow the normal range from 0 to ([models].length - 1).
  ///
  /// When sliding from the first item to the last, the [page] transition
  /// sequence is 0...-1, followed by a direct jump to ([models].length - 1).
  ///
  /// Conversely, when sliding from the last item back to the first, the [page]
  /// transition sequence is from ([models].length - 1)...[models].length,
  /// followed by a direct jump to 0.
  ///
  /// See [SlideViewState._onScrollNotification].
  final void Function(double page)? onPageChanged;

  /// Callback when the page in integer has changed.
  final void Function(int index)? onPageIndexChanged;

  /// Use the given [RouteObserver] to observer if the slider
  /// is not the current route, then pause.
  final RouteObserver? routeObserver;

  @override
  List<Object?> get props {
    return <Object?>[
      models,
      itemBuilder,
      scrollDirection,
      aspectRatio,
      width,
      height,
      viewportFraction,
      autoScroll,
      autoScrollOnPointerDown,
      scrollCurve,
      scrollDuration,
      scrollInterval,
      borderRadius,
      showIndicator,
      indicatorSize,
      indicatorColor,
      unselectedIndicatorColor,
      indicatorOffsetFromBottom,
      indicatorBuilder,
      onItemTap,
      onPageChanged,
      onPageIndexChanged,
      routeObserver,
    ];
  }
}

/// The slider view.
class SliderView<T> extends StatefulWidget {
  const SliderView({Key? key, required this.config}) : super(key: key);

  /// The configuration of the widget.
  final SliderViewConfig<T> config;

  @override
  SlideViewState<T> createState() => SlideViewState<T>();
}

const int _kFillerPageNum = 2;

class SlideViewState<T> extends State<SliderView<T>>
    with WidgetsBindingObserver, RouteAware {
  SliderViewConfig<T> get config => widget.config;

  /// Current page's simplify notifier.
  ///
  /// Start from the [_kFillerPageNum] if there are more than one model.
  late final ValueNotifier<double> _pageNotifier =
      ValueNotifier<double>(_hasOnlyOneModel ? 0 : _kFillerPageNum.toDouble());

  /// If [SliderViewConfig.models] has only one element,
  /// so the slider is not required to scroll.
  bool get _hasOnlyOneModel => config.models.length == 1;

  /// The controller used by the slider's [PageView].
  late final PageController _pageController = PageController(
    // Start from the [kFillerPageNum] if there are more than one model.
    initialPage: _hasOnlyOneModel ? 0 : _kFillerPageNum,
    viewportFraction: config.viewportFraction,
  )..addListener(_pageListener);

  late RouteObserver? _routeObserver = config.routeObserver;

  /// Models involved in rendering.
  late List<T> _models = _handleModels();

  int _lastReportedPage = 0;

  /// Record last callback page index for de-duplication.
  int? _lastCallbackPageIndex;

  /// Scrolling timer.
  Timer? _timer;

  /// Pointers that accepted by the slider view.
  int _pointers = 0;

  /// Cached layout to avoid redundant layout calculations.
  Widget? _body;

  @override
  void initState() {
    super.initState();
    _ambiguate(WidgetsBinding.instance)
      // Register lifecycle hook.
      ?..addObserver(this)
      // Start the slide after the first frame were built.
      ..addPostFrameCallback((_) => startTimer());

    _lastReportedPage = _pageController.initialPage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver?.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startTimer();
      return;
    }
    // Stop the slider if the lifecycle is not resumed.
    stopTimer();
  }

  @override
  void didUpdateWidget(SliderView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Relayout if any arguments changed.
    if (oldWidget.config != widget.config) {
      // Get before [setState].
      final int oldWidgetModelsLength = _models.length;

      setState(() {
        _models = _handleModels();
        _body = _buildBody(context);
      });

      _ambiguate(WidgetsBinding.instance)?.addPostFrameCallback((_) {
        // Keep position when changing from one model to multiple models.
        if (oldWidgetModelsLength == 1 && _models.length > 1) {
          _pageController.jumpToPage(_kFillerPageNum);
        } else if (oldWidgetModelsLength > _models.length) {
          if (_pageNotifier.value > _models.length - 1 - _kFillerPageNum) {
            _pageController.jumpToPage(_pageNotifier.value.toInt() - 1);
          }
        }

        startTimer();
      });
    }
    // Make sure the old route observer is unsubscribed
    // and the new old is subscribed correctly.
    if (oldWidget.config.routeObserver != widget.config.routeObserver) {
      _routeObserver?.unsubscribe(this);
      if (mounted) {
        _routeObserver = widget.config.routeObserver;
        final ModalRoute? route = ModalRoute.of(context);
        if (route != null) {
          _routeObserver?.subscribe(this, route);
        }
      }
    }
  }

  @override
  void didPushNext() {
    stopTimer();
  }

  @override
  void didPopNext() {
    startTimer();
  }

  @override
  void dispose() {
    stopTimer();
    _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  /// Preprocessed [SliderViewConfig.models] to enable infinite scrolling.
  ///
  /// Shallow copy to use as a judgment when [didUpdateWidget].
  List<T> _handleModels() {
    final int length = config.models.length;
    if (length == 1) {
      return <T>[...config.models];
    }

    final List<T> leftFiller = config.models.sublist(length - _kFillerPageNum);
    final Iterable<T> rightFiller = config.models.take(_kFillerPageNum);

    return <T>[
      ...leftFiller,
      ...config.models,
      ...rightFiller,
    ];
  }

  void _pageListener() {
    if (_pageController.hasClients) {
      final double page = _pageController.page ?? 0;
      if (page != _pageNotifier.value) {
        config.onPageChanged?.call(page - _kFillerPageNum);
      }
      _pageNotifier.value = page;
    }
  }

  void startTimer() {
    // Cancel the last timer if exists.
    if (_timer != null) {
      stopTimer();
    }
    // Prevent scrolling if [autoScroll] is false and only one model is given.
    if (!config.autoScroll || _hasOnlyOneModel) {
      return;
    }
    // Set the timer to scroll periodically.
    _timer = Timer.periodic(
      config.scrollInterval,
      (_) => _pageController.nextPage(
        curve: Curves.easeInOutQuart,
        duration: config.scrollDuration,
      ),
    );
  }

  /// Cancel and remove the [_timer].
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// The implementation of infinite scroll.
  ///
  /// Padding items are added at the beginning and end for infinite scrolling.
  /// The correct item is then navigated to when a [ScrollEndNotification] is
  /// received while at a padding item.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0 && notification is ScrollEndNotification) {
      // Jump to the first or last page when the slide ends and goes out
      // of bounds.
      final int currentPage =
          (notification.metrics as PageMetrics).page!.round();

      if (currentPage != _lastReportedPage) {
        _lastReportedPage = currentPage;

        // Actual length.
        final int length = _models.length - _kFillerPageNum;

        // Manually jump to the actual first or last page when on the
        // filler page.
        if (currentPage <= _kFillerPageNum - 1) {
          _pageController.jumpToPage(length - 1);
        } else if (currentPage >= length) {
          _pageController.jumpToPage(_kFillerPageNum);
        }
      }
    }

    return false;
  }

  /// Reset the page when the current position is on a filler page.
  ///
  /// The page needs to be adjusted by subtracting the added filler pages
  /// on the left (i.e., [page] - [_kFillerPageNum]).
  ///
  /// When on a filler page on the left (i.e., [page] < [_kFillerPageNum]),
  /// the page should be additionally adjusted to the right.
  ///
  /// When on a filler page on the right (i.e., [page] > [_models].length - 1 - [_kFillerPageNum]),
  /// the page should be additionally adjusted to the left.
  double _handlePage(double page) {
    final int length = config.models.length;

    double pageFix = page - _kFillerPageNum;

    if (page < _kFillerPageNum) {
      pageFix += length;
    } else if (page > _models.length - 1 - _kFillerPageNum) {
      pageFix -= length;
    }
    return pageFix;
  }

  Widget _buildBody(BuildContext context) {
    final Widget child = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(child: _buildSlideBody(context)),
        if (config.showIndicator && !_hasOnlyOneModel)
          _buildIndicators(context),
      ],
    );

    // Prefer to the aspect ratio if defined.
    if (config.aspectRatio != null) {
      return AspectRatio(aspectRatio: config.aspectRatio!, child: child);
    }
    return SizedBox(width: config.width, height: config.height, child: child);
  }

  Widget _buildSlideBody(BuildContext context) {
    final Widget body = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: PageView.builder(
        scrollDirection: config.scrollDirection,
        physics: config.physics,
        scrollBehavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          // Capable with desktops.
          dragDevices: <PointerDeviceKind>{
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        controller: _pageController,
        itemBuilder: _buildItem,
        itemCount: _models.length,
        onPageChanged: (int i) {
          int index = i - _kFillerPageNum;

          // Fix index in filler pages.
          if (index < 0) {
            index = widget.config.models.length - 1;
          } else if (index >= widget.config.models.length) {
            index = 0;
          }

          // Skip duplicate index.
          if (_lastCallbackPageIndex == index) {
            return;
          }

          _lastCallbackPageIndex = index;
          config.onPageIndexChanged?.call(index);
        },
      ),
    );
    if (config.autoScrollOnPointerDown) {
      return body;
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        ++_pointers;
        stopTimer();
      },
      onPointerUp: (PointerUpEvent e) {
        if (_pointers > 0) {
          --_pointers;
        }
        if (_pointers == 0) {
          startTimer();
        }
      },
      child: body,
    );
  }

  Widget _buildIndicators(BuildContext context) {
    final double size = config.indicatorSize;
    return ValueListenableBuilder<double>(
      valueListenable: _pageNotifier,
      builder: (BuildContext context, double page, __) {
        final double result = _handlePage(page);
        return Positioned.fill(
          top: null,
          bottom: config.indicatorOffsetFromBottom ?? size / 1.5,
          child: Container(
            alignment: Alignment.center,
            height: size,
            child: ListView.separated(
              scrollDirection: config.scrollDirection,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              separatorBuilder: (_, __) => SizedBox(width: size),
              itemCount: config.models.length,
              itemBuilder: (_, int index) => _buildIndicatorItem(index, result),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicatorItem(int index, double page) {
    return Builder(
      builder: (BuildContext context) {
        // Calculate the interpolation of the page.
        final double interpolation = math.min(1, (index - page).abs());
        if (config.indicatorBuilder != null) {
          return config.indicatorBuilder!(context, interpolation);
        }
        return Container(
          margin: EdgeInsets.symmetric(horizontal: config.indicatorSize / 2),
          width: config.indicatorSize,
          height: config.indicatorSize,
          decoration: BoxDecoration(
            color: Color.lerp(
              config.indicatorColor,
              config.unselectedIndicatorColor,
              interpolation,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final int newIndex = index % (config.models.length);
    final T model = _models[newIndex];
    Widget item = GestureDetector(
      onTap: () => config.onItemTap?.call(newIndex, model),
      child: config.itemBuilder(model),
    );
    // Clip with round rects if the border radius is valid.
    if (config.borderRadius != BorderRadius.zero) {
      item = ClipRRect(
        borderRadius: config.borderRadius,
        child: item,
      );
    }
    return item;
  }

  @override
  Widget build(BuildContext context) {
    // Cache the layout to avoid redundant layout calculations.
    _body ??= _buildBody(context);
    return _body!;
  }
}

T? _ambiguate<T>(T value) => value;
