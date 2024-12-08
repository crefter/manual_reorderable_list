import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum ReorderType {
  /// Use for manual reordering by startItemManualReorder method
  manual,

  /// Use for drag reordering by startItemDragReorder method
  drag,

  /// Use for both reordering types.
  all;
}

const _defaultAnimationDuration = Duration(milliseconds: 300);

/// A callback used by [ManualReorderableList] to report that a list item has moved
/// to a new position in the list.
///
/// Implementations should remove the corresponding list item at [oldIndex]
/// and reinsert it at [newIndex].
///
/// If [oldIndex] is before [newIndex], removing the item at [oldIndex] from the
/// list will reduce the list's length by one. Implementations will need to
/// account for this when inserting before [newIndex].
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=3fB1mxOsqJE}
///
/// {@tool snippet}
///
/// ```dart
/// final List<MyDataObject> backingList = <MyDataObject>[/* ... */];
///
/// void handleReorder(int oldIndex, int newIndex) {
///   if (oldIndex < newIndex) {
///     // removing the item at oldIndex will shorten the list by 1.
///     newIndex -= 1;
///   }
///   final MyDataObject element = backingList.removeAt(oldIndex);
///   backingList.insert(newIndex, element);
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [ManualReorderableList], a widget list that allows the user to reorder
///    its items.
///  * [ManualSliverReorderableList], a sliver list that allows the user to reorder
///    its items.
///  * [ReorderableListView], a Material Design list that allows the user to
///    reorder its items.
typedef ManualReorderCallback = void Function(int oldIndex, int newIndex);

/// Signature for the builder callback used to decorate the dragging item in
/// [ManualReorderableList] and [ManualSliverReorderableList].
///
/// The [child] will be the item that is being dragged, and [index] is the
/// position of the item in the list.
///
/// The [animation] will be driven forward from 0.0 to 1.0 while the item is
/// being picked up during a drag operation, and reversed from 1.0 to 0.0 when
/// the item is dropped. This can be used to animate properties of the proxy
/// like an elevation or border.
///
/// The returned value will typically be the [child] wrapped in other widgets.
typedef ManualReorderItemProxyDecorator = Widget Function(
    Widget child, int index, Animation<double> animation);

/// A scrolling container that allows the user to interactively reorder the
/// list items.
///
/// This widget is similar to one created by [ListView.builder], and uses
/// an [IndexedWidgetBuilder] to create each item.
///
/// It is up to the application to wrap each child (or an internal part of the
/// child such as a drag handle) with a drag listener that will recognize
/// the start of an item drag and then start the reorder by calling
/// [ManualReorderableListState.startItemDragReorder]. This is most easily achieved
/// by wrapping each child in a [ManualReorderableDragStartListener] or a
/// [ManualReorderableDelayedDragStartListener]. These will take care of recognizing
/// the start of a drag gesture and call the list state's
/// [ManualReorderableListState.startItemDragReorder] method.
///
/// This widget's [ManualReorderableListState] can be used to manually start an item
/// reorder, or cancel a current drag. To refer to the
/// [ManualReorderableListState] either provide a [GlobalKey] or use the static
/// [ManualReorderableList.of] method from an item's build method.
///
/// See also:
///
///  * [ManualSliverReorderableList], a sliver list that allows the user to reorder
///    its items.
///  * [ReorderableListView], a Material Design list that allows the user to
///    reorder its items.
class ManualReorderableList extends StatefulWidget {
  /// Creates a scrolling container that allows the user to interactively
  /// reorder the list items.
  ///
  /// The [itemCount] must be greater than or equal to zero.
  const ManualReorderableList({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
    this.manualAnimationController,
    this.reorderType = ReorderType.all,
    this.manualItemAnimationCurve = Curves.linear,
    this.manualScrollAnimationCurve = Curves.linear,
    this.manualItemAnimationFactor = 1,
    this.manualItemAnimationDuration = const Duration(milliseconds: 1000),
    this.manualScrollAnimationDurationByIndex =
        const Duration(milliseconds: 100),
    this.canStartReorder = true,
    this.scrollableState,
  })  : assert(itemCount >= 0),
        assert(
          (itemExtent == null && prototypeItem == null) ||
              (itemExtent == null && itemExtentBuilder == null) ||
              (prototypeItem == null && itemExtentBuilder == null),
          'You can only pass one of itemExtent, prototypeItem and itemExtentBuilder.',
        );

  /// {@template flutter.widgets.reorderable_list.itemBuilder}
  /// Called, as needed, to build list item widgets.
  ///
  /// List items are only built when they're scrolled into view.
  ///
  /// The [IndexedWidgetBuilder] index parameter indicates the item's
  /// position in the list. The value of the index parameter will be between
  /// zero and one less than [itemCount]. All items in the list must have a
  /// unique [Key], and should have some kind of listener to start the drag
  /// (usually a [ManualReorderableDragStartListener] or
  /// [ManualReorderableDelayedDragStartListener]).
  /// {@endtemplate}
  final AnimatedItemBuilder itemBuilder;

  /// {@template flutter.widgets.reorderable_list.itemCount}
  /// The number of items in the list.
  ///
  /// It must be a non-negative integer. When zero, nothing is displayed and
  /// the widget occupies no space.
  /// {@endtemplate}
  final int itemCount;

  /// {@template flutter.widgets.reorderable_list.onReorder}
  /// A callback used by the list to report that a list item has been dragged
  /// to a new location in the list and the application should update the order
  /// of the items.
  /// {@endtemplate}
  final ManualReorderCallback onReorder;

  /// {@template flutter.widgets.reorderable_list.onReorderStart}
  /// A callback that is called when an item drag has started.
  ///
  /// The index parameter of the callback is the index of the selected item.
  ///
  /// See also:
  ///
  ///   * [onReorderEnd], which is a called when the dragged item is dropped.
  ///   * [onReorder], which reports that a list item has been dragged to a new
  ///     location.
  /// {@endtemplate}
  final void Function(int index)? onReorderStart;

  /// {@template flutter.widgets.reorderable_list.onReorderEnd}
  /// A callback that is called when the dragged item is dropped.
  ///
  /// The index parameter of the callback is the index where the item is
  /// dropped. Unlike [onReorder], this is called even when the list item is
  /// dropped in the same location.
  ///
  /// See also:
  ///
  ///   * [onReorderStart], which is a called when an item drag has started.
  ///   * [onReorder], which reports that a list item has been dragged to a new
  ///     location.
  /// {@endtemplate}
  final void Function(int index)? onReorderEnd;

  /// {@template flutter.widgets.reorderable_list.proxyDecorator}
  /// A callback that allows the app to add an animated decoration around
  /// an item when it is being dragged.
  /// {@endtemplate}
  final ManualReorderItemProxyDecorator? proxyDecorator;

  /// {@template flutter.widgets.reorderable_list.padding}
  /// The amount of space by which to inset the list contents.
  ///
  /// It defaults to `EdgeInsets.all(0)`.
  /// {@endtemplate}
  final EdgeInsetsGeometry? padding;

  /// {@macro flutter.widgets.scroll_view.scrollDirection}
  final Axis scrollDirection;

  /// {@macro flutter.widgets.scroll_view.reverse}
  final bool reverse;

  /// {@macro flutter.widgets.scroll_view.controller}
  final ScrollController? controller;

  /// Is primary?
  final bool? primary;

  /// {@macro flutter.widgets.scroll_view.physics}
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scroll_view.shrinkWrap}
  final bool shrinkWrap;

  /// {@macro flutter.widgets.scroll_view.anchor}
  final double anchor;

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  final double? cacheExtent;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.scroll_view.keyboardDismissBehavior}
  ///
  /// The default is [ScrollViewKeyboardDismissBehavior.manual]
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// {@macro flutter.widgets.scrollable.restorationId}
  final String? restorationId;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// {@macro flutter.widgets.list_view.itemExtent}
  final double? itemExtent;

  /// {@macro flutter.widgets.list_view.itemExtentBuilder}
  final ItemExtentBuilder? itemExtentBuilder;

  /// {@macro flutter.widgets.list_view.prototypeItem}
  final Widget? prototypeItem;

  /// {@macro flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  ///
  /// {@macro flutter.widgets.SliverReorderableList.autoScrollerVelocityScalar.default}
  final double? autoScrollerVelocityScalar;

  /// Curve for dragging item animation to end position after scrolling (if need)
  final Curve manualItemAnimationCurve;

  /// Curve for scroll animation to end position
  final Curve manualScrollAnimationCurve;

  /// Dragging animation factor. Use it to calculate drag animation duration
  final double manualItemAnimationFactor;

  /// Dragging animation duration.
  final Duration manualItemAnimationDuration;

  /// Scroll animation duration depending on element indexes
  final Duration manualScrollAnimationDurationByIndex;

  /// Animation controller for drag item animation.
  /// If [manualAnimationController] is null then manual item dragging animation is not start
  final AnimationController? manualAnimationController;

  /// Reordering type
  final ReorderType reorderType;

  /// Parent scrollable state. Use it if [ManualReorderableList] nested in other scrollable widget
  final ScrollableState? scrollableState;

  final bool canStartReorder;

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [ManualReorderableList] item widgets that
  /// insert or remove items in response to user input.
  ///
  /// If no [ManualReorderableList] surrounds the given context, then this function
  /// will assert in debug mode and throw an exception in release mode.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// See also:
  ///
  ///  * [maybeOf], a similar function that will return null if no
  ///    [ManualReorderableList] ancestor is found.
  static ManualReorderableListState of(BuildContext context) {
    final ManualReorderableListState? result =
        context.findAncestorStateOfType<ManualReorderableListState>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'ReorderableList.of() called with a context that does not contain a ReorderableList.'),
          ErrorDescription(
            'No ReorderableList ancestor could be found starting from the context that was passed to ReorderableList.of().',
          ),
          ErrorHint(
            'This can happen when the context provided is from the same StatefulWidget that '
            'built the ReorderableList. Please see the ReorderableList documentation for examples '
            'of how to refer to an ReorderableListState object:\n'
            '  https://api.flutter.dev/flutter/widgets/ReorderableListState-class.html',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [ManualReorderableList] item widgets that insert
  /// or remove items in response to user input.
  ///
  /// If no [ManualReorderableList] surrounds the context given, then this function will
  /// return null.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// See also:
  ///
  ///  * [of], a similar function that will throw if no [ManualReorderableList] ancestor
  ///    is found.
  static ManualReorderableListState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ManualReorderableListState>();
  }

  @override
  ManualReorderableListState createState() => ManualReorderableListState();
}

/// The state for a list that allows the user to interactively reorder
/// the list items.
///
/// An app that needs to start a new item drag or cancel an existing one
/// can refer to the [ManualReorderableList]'s state with a global key:
///
/// ```dart
/// GlobalKey<ReorderableListState> listKey = GlobalKey<ReorderableListState>();
/// // ...
/// Widget build(BuildContext context) {
///   return ReorderableList(
///     key: listKey,
///     itemBuilder: (BuildContext context, int index) => const SizedBox(height: 10.0),
///     itemCount: 5,
///     onReorder: (int oldIndex, int newIndex) {
///        // ...
///     },
///   );
/// }
/// // ...
/// listKey.currentState!.cancelReorder();
/// ```
class ManualReorderableListState extends State<ManualReorderableList> {
  final GlobalKey<ManualSliverReorderableListState> _sliverReorderableListKey =
      GlobalKey();

  /// Initiate the dragging of the item at [index] that was started with
  /// the pointer down [event].
  ///
  /// The given [recognizer] will be used to recognize and start the drag
  /// item tracking and lead to either an item reorder, or a canceled drag.
  /// The list will take ownership of the returned recognizer and will dispose
  /// it when it is no longer needed.
  ///
  /// Most applications will not use this directly, but will wrap the item
  /// (or part of the item, like a drag handle) in either a
  /// [ManualReorderableDragStartListener] or [ManualReorderableDelayedDragStartListener]
  /// which call this for the application.
  void startItemDragReorder({
    required int index,
    required PointerDownEvent event,
    required MultiDragGestureRecognizer recognizer,
  }) {
    _sliverReorderableListKey.currentState!.startItemDragReorder(
        index: index, event: event, recognizer: recognizer);
  }

  Future<void> startItemManualReorder(
    int startIndex,
    int endIndex, {
    Future<void> Function(int startIndex, int endIndex)? doBefore,
    Duration? scrollDuration,
    Duration? itemAnimationDuration,
  }) async {
    await _sliverReorderableListKey.currentState!.startItemManualReorder(
      startIndex,
      endIndex,
      doBefore: doBefore,
      scrollDuration: scrollDuration,
      itemAnimationDuration: itemAnimationDuration,
    );
  }

  /// Cancel any item drag in progress.
  ///
  /// This should be called before any major changes to the item list
  /// occur so that any item drags will not get confused by
  /// changes to the underlying list.
  ///
  /// If no drag is active, this will do nothing.
  void cancelReorder() {
    _sliverReorderableListKey.currentState!.cancelReorder();
  }

  /// Insert an item at [index] and start an animation that will be passed
  /// to [ManualReorderableList.itemBuilder] when the item
  /// is visible.
  ///
  /// This method's semantics are the same as Dart's [List.insert] method: it
  /// increases the length of the list of items by one and shifts
  /// all items at or after [index] towards the end of the list of items.
  void insertItem(int index, {Duration duration = _defaultAnimationDuration}) {
    _sliverReorderableListKey.currentState!
        .insertItem(index, duration: duration);
  }

  /// Insert multiple items at [index] and start an animation that will be passed
  /// to [ManualReorderableList.itemBuilder]  when the items
  /// are visible.
  void insertAllItems(int index, int length,
      {Duration duration = _defaultAnimationDuration, bool isAsync = false}) {
    _sliverReorderableListKey.currentState!
        .insertAllItems(index, length, duration: duration);
  }

  /// Remove the item at `index` and start an animation that will be passed to
  /// `builder` when the item is visible.
  ///
  /// Items are removed immediately. After an item has been removed, its index
  /// will no longer be passed to the `itemBuilder`. However, the
  /// item will still appear for `duration` and during that time
  /// `builder` must construct its widget as needed.
  ///
  /// This method's semantics are the same as Dart's [List.remove] method: it
  /// decreases the length of items by one and shifts all items at or before
  /// `index` towards the beginning of the list of items.
  ///
  /// See also:
  ///
  ///   * [AnimatedRemovedItemBuilder], which describes the arguments to the
  ///     `builder` argument.
  void removeItem(int index, AnimatedRemovedItemBuilder builder,
      {Duration duration = _defaultAnimationDuration}) {
    _sliverReorderableListKey.currentState!
        .removeItem(index, builder, duration: duration);
  }

  /// Remove all the items and start an animation that will be passed to
  /// `builder` when the items are visible.
  ///
  /// Items are removed immediately. However, the
  /// items will still appear for `duration`, and during that time
  /// `builder` must construct its widget as needed.
  ///
  /// This method's semantics are the same as Dart's [List.clear] method: it
  /// removes all the items in the list.
  void removeAllItems(AnimatedRemovedItemBuilder builder,
      {Duration duration = _defaultAnimationDuration}) {
    _sliverReorderableListKey.currentState!
        .removeAllItems(builder, duration: duration);
  }

  @override
  Widget build(BuildContext context) {
    return _wrap(
      ManualSliverReorderableList(
        key: _sliverReorderableListKey,
        itemExtent: widget.itemExtent,
        prototypeItem: widget.prototypeItem,
        itemBuilder: widget.itemBuilder,
        itemCount: widget.itemCount,
        onReorder: widget.onReorder,
        onReorderStart: widget.onReorderStart,
        onReorderEnd: widget.onReorderEnd,
        proxyDecorator: widget.proxyDecorator,
        autoScrollerVelocityScalar: widget.autoScrollerVelocityScalar,
        manualItemAnimationCurve: widget.manualItemAnimationCurve,
        manualItemAnimationDuration: widget.manualItemAnimationDuration,
        manualScrollAnimationDurationByIndex:
            widget.manualScrollAnimationDurationByIndex,
        manualItemAnimationFactor: widget.manualItemAnimationFactor,
        manualAnimationController: widget.manualAnimationController,
        manualScrollAnimationCurve: widget.manualScrollAnimationCurve,
        reorderType: widget.reorderType,
        scrollableState: widget.scrollableState,
      ),
      widget.scrollDirection,
    );
  }

  Widget _wrap(Widget sliver, Axis direction) {
    EdgeInsetsGeometry? effectivePadding = widget.padding;
    if (widget.padding == null) {
      final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        // Automatically pad sliver with padding from MediaQuery.
        final EdgeInsets mediaQueryHorizontalPadding =
            mediaQuery.padding.copyWith(top: 0, bottom: 0);
        final EdgeInsets mediaQueryVerticalPadding =
            mediaQuery.padding.copyWith(left: 0, right: 0);
        // Consume the main axis padding with SliverPadding.
        effectivePadding = direction == Axis.vertical
            ? mediaQueryVerticalPadding
            : mediaQueryHorizontalPadding;
        // Leave behind the cross axis padding.
        sliver = MediaQuery(
          data: mediaQuery.copyWith(
            padding: direction == Axis.vertical
                ? mediaQueryHorizontalPadding
                : mediaQueryVerticalPadding,
          ),
          child: sliver,
        );
      }
    }

    sliver = SliverPadding(
      padding: effectivePadding ?? widget.padding ?? EdgeInsets.zero,
      sliver: sliver,
    );

    return CustomScrollView(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: widget.controller,
      primary: widget.primary,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      anchor: widget.anchor,
      cacheExtent: widget.cacheExtent,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      slivers: <Widget>[
        sliver,
      ],
    );
  }
}

/// A sliver list that allows the user to interactively reorder the list items.
///
/// It is up to the application to wrap each child (or an internal part of the
/// child) with a drag listener that will recognize the start of an item drag
/// and then start the reorder by calling
/// [ManualSliverReorderableListState.startItemDragReorder]. This is most easily
/// achieved by wrapping each child in a [ManualReorderableDragStartListener] or
/// a [ManualReorderableDelayedDragStartListener]. These will take care of
/// recognizing the start of a drag gesture and call the list state's start
/// item drag method.
///
/// This widget's [ManualSliverReorderableListState] can be used to manually start an item
/// reorder, or cancel a current drag that's already underway. To refer to the
/// [ManualSliverReorderableListState] either provide a [GlobalKey] or use the static
/// [ManualSliverReorderableList.of] method from an item's build method.
///
/// See also:
///
///  * [ManualReorderableList], a regular widget list that allows the user to reorder
///    its items.
class ManualSliverReorderableList extends StatefulWidget {
  /// Creates a sliver list that allows the user to interactively reorder its
  /// items.
  ///
  /// The [itemCount] must be greater than or equal to zero.
  const ManualSliverReorderableList({
    super.key,
    required this.itemBuilder,
    this.findChildIndexCallback,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.manualAnimationController,
    this.manualItemAnimationCurve = Curves.linear,
    this.manualScrollAnimationCurve = Curves.linear,
    this.manualItemAnimationFactor = 1,
    this.manualItemAnimationDuration = const Duration(milliseconds: 1000),
    this.manualScrollAnimationDurationByIndex =
        const Duration(milliseconds: 100),
    this.reorderType = ReorderType.all,
    this.canStartReorder = true,
    double? autoScrollerVelocityScalar,
    this.scrollableState,
  })  : autoScrollerVelocityScalar =
            autoScrollerVelocityScalar ?? _kDefaultAutoScrollVelocityScalar,
        assert(itemCount >= 0),
        assert(
          (itemExtent == null && prototypeItem == null) ||
              (itemExtent == null && itemExtentBuilder == null) ||
              (prototypeItem == null && itemExtentBuilder == null),
          'You can only pass one of itemExtent, prototypeItem and itemExtentBuilder.',
        );

  // An eyeballed value for a smooth scrolling experience.
  static const double _kDefaultAutoScrollVelocityScalar = 50;

  /// {@macro flutter.widgets.reorderable_list.itemBuilder}
  final AnimatedItemBuilder itemBuilder;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.findChildIndexCallback}
  final ChildIndexGetter? findChildIndexCallback;

  /// {@macro flutter.widgets.reorderable_list.itemCount}
  final int itemCount;

  /// {@macro flutter.widgets.reorderable_list.onReorder}
  final ManualReorderCallback onReorder;

  /// {@macro flutter.widgets.reorderable_list.onReorderStart}
  final void Function(int)? onReorderStart;

  /// {@macro flutter.widgets.reorderable_list.onReorderEnd}
  final void Function(int)? onReorderEnd;

  /// {@macro flutter.widgets.reorderable_list.proxyDecorator}
  final ManualReorderItemProxyDecorator? proxyDecorator;

  /// {@macro flutter.widgets.list_view.itemExtent}
  final double? itemExtent;

  /// {@macro flutter.widgets.list_view.itemExtentBuilder}
  final ItemExtentBuilder? itemExtentBuilder;

  /// {@macro flutter.widgets.list_view.prototypeItem}
  final Widget? prototypeItem;

  /// {@macro flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  ///
  /// {@template flutter.widgets.SliverReorderableList.autoScrollerVelocityScalar.default}
  /// Defaults to 50 if not set or set to null.
  /// {@endtemplate}
  final double autoScrollerVelocityScalar;

  /// Curve for dragging item animation to end position after scrolling (if need)
  final Curve manualItemAnimationCurve;

  /// Curve for scroll animation to end position
  final Curve manualScrollAnimationCurve;

  /// Dragging animation factor. Use it to calculate drag animation duration
  final double manualItemAnimationFactor;

  /// Dragging animation duration.
  final Duration manualItemAnimationDuration;

  /// Scroll animation duration depending on element indexes
  final Duration manualScrollAnimationDurationByIndex;

  /// Animation controller for drag item animation.
  /// If [manualAnimationController] is null then manual item dragging animation is not start
  final AnimationController? manualAnimationController;

  /// Reordering type
  final ReorderType reorderType;

  /// Parent scrollable state.
  /// Use it if [ManualReorderableList] nested in other [Scrollable] widget
  /// (ex. [SingleChildScrollView] -> [ManualReorderableList] or
  /// [ListView] -> [ManualReorderableList])
  final ScrollableState? scrollableState;

  final bool canStartReorder;

  @override
  ManualSliverReorderableListState createState() =>
      ManualSliverReorderableListState();

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [ManualSliverReorderableList] item widgets to
  /// start or cancel an item drag operation.
  ///
  /// If no [ManualSliverReorderableList] surrounds the context given, this function
  /// will assert in debug mode and throw an exception in release mode.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// See also:
  ///
  ///  * [maybeOf], a similar function that will return null if no
  ///    [ManualSliverReorderableList] ancestor is found.
  static ManualSliverReorderableListState of(BuildContext context) {
    final ManualSliverReorderableListState? result =
        context.findAncestorStateOfType<ManualSliverReorderableListState>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'SliverReorderableList.of() called with a context that does not contain a SliverReorderableList.',
          ),
          ErrorDescription(
            'No SliverReorderableList ancestor could be found starting from the context that was passed to SliverReorderableList.of().',
          ),
          ErrorHint(
            'This can happen when the context provided is from the same StatefulWidget that '
            'built the SliverReorderableList. Please see the SliverReorderableList documentation for examples '
            'of how to refer to an SliverReorderableList object:\n'
            '  https://api.flutter.dev/flutter/widgets/SliverReorderableListState-class.html',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [ManualSliverReorderableList] item widgets that
  /// insert or remove items in response to user input.
  ///
  /// If no [ManualSliverReorderableList] surrounds the context given, this function
  /// will return null.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// See also:
  ///
  ///  * [of], a similar function that will throw if no [ManualSliverReorderableList]
  ///    ancestor is found.
  static ManualSliverReorderableListState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ManualSliverReorderableListState>();
  }
}

/// The state for a sliver list that allows the user to interactively reorder
/// the list items.
///
/// An app that needs to start a new item drag or cancel an existing one
/// can refer to the [ManualSliverReorderableList]'s state with a global key:
///
/// ```dart
/// // (e.g. in a stateful widget)
/// GlobalKey<SliverReorderableListState> listKey = GlobalKey<SliverReorderableListState>();
///
/// // ...
///
/// @override
/// Widget build(BuildContext context) {
///   return SliverReorderableList(
///     key: listKey,
///     itemBuilder: (BuildContext context, int index) => const SizedBox(height: 10.0),
///     itemCount: 5,
///     onReorder: (int oldIndex, int newIndex) {
///        // ...
///     },
///   );
/// }
///
/// // ...
///
/// void _stop() {
///   listKey.currentState!.cancelReorder();
/// }
/// ```
///
/// [ManualReorderableDragStartListener] and [ManualReorderableDelayedDragStartListener]
/// refer to their [ManualSliverReorderableList] with the static
/// [ManualSliverReorderableList.of] method.
class ManualSliverReorderableListState
    extends State<ManualSliverReorderableList> with TickerProviderStateMixin {
  // Map of index -> child state used manage where the dragging item will need
  // to be inserted.
  final Map<int, _ManualReorderableItemState> _items =
      <int, _ManualReorderableItemState>{};

  OverlayEntry? _overlayEntry;
  int? _dragIndex;
  _DragInfo? _dragInfo;
  int? _insertIndex;
  Offset? _finalDropPosition;
  MultiDragGestureRecognizer? _recognizer;
  int? _recognizerPointer;

  EdgeDraggingAutoScroller? _autoScroller;

  late ScrollableState _scrollable;
  late double _screenSize;

  Axis get _scrollDirection => axisDirectionToAxis(_scrollable.axisDirection);

  bool get _reverse =>
      _scrollable.axisDirection == AxisDirection.up ||
      _scrollable.axisDirection == AxisDirection.left;

  bool _isReordering = false;
  late Animation<double> _animation;
  int? _startIndex;
  int? _endIndex;
  Offset _lastDelta = Offset.zero;
  Offset? _deltaOffset;
  late Offset _startPosition;
  late Offset _endPosition;
  bool _isScrolling = false;
  double? _itemExtent;
  ScrollPosition? _scrollPosition;

  Duration get _itemAnimationDuration => Duration(
      milliseconds: (widget.manualItemAnimationDuration.inMilliseconds *
                  widget.manualItemAnimationFactor +
              _deltaOffset!.dy.abs())
          .round());

  Duration get _scrollAnimationDuration => Duration(
      milliseconds: widget.manualScrollAnimationDurationByIndex.inMilliseconds *
          (_startIndex! - _endIndex!).abs());

  final List<_ActiveItem> _incomingItems = <_ActiveItem>[];
  final List<_ActiveItem> _outgoingItems = <_ActiveItem>[];
  int _itemsCount = 0;

  _ActiveItem? _removeActiveItemAt(List<_ActiveItem> items, int itemIndex) {
    final int i = binarySearch(items, _ActiveItem.index(itemIndex));
    return i == -1 ? null : items.removeAt(i);
  }

  _ActiveItem? _activeItemAt(List<_ActiveItem> items, int itemIndex) {
    final int i = binarySearch(items, _ActiveItem.index(itemIndex));
    return i == -1 ? null : items[i];
  }

  // The insertItem() and removeItem() index parameters are defined as if the
  // removeItem() operation removed the corresponding list/grid entry
  // immediately. The entry is only actually removed from the
  // ListView/GridView when the remove animation finishes. The entry is added
  // to _outgoingItems when removeItem is called and removed from
  // _outgoingItems when the remove animation finishes.

  int _indexToItemIndex(int index) {
    int itemIndex = index;
    for (final _ActiveItem item in _outgoingItems) {
      if (item.itemIndex <= itemIndex) {
        itemIndex += 1;
      } else {
        break;
      }
    }
    return itemIndex;
  }

  int _itemIndexToIndex(int itemIndex) {
    int index = itemIndex;
    for (final _ActiveItem item in _outgoingItems) {
      assert(item.itemIndex != itemIndex);
      if (item.itemIndex < itemIndex) {
        index -= 1;
      } else {
        break;
      }
    }
    return index;
  }

  SliverChildDelegate _createDelegate() {
    return SliverChildBuilderDelegate(
      _itemBuilder,
      childCount: _itemsCount,
      findChildIndexCallback: widget.findChildIndexCallback == null
          ? null
          : (key) {
              final int? index = widget.findChildIndexCallback!(key);
              return index != null ? _indexToItemIndex(index) : null;
            },
    );
  }

  /// Insert an item at [index] and start an animation that will be passed to
  /// [SliverAnimatedGrid.itemBuilder] or [SliverAnimatedList.itemBuilder] when
  /// the item is visible.
  ///
  /// This method's semantics are the same as Dart's [List.insert] method: it
  /// increases the length of the list of items by one and shifts
  /// all items at or after [index] towards the end of the list of items.
  void insertItem(int index, {Duration duration = _defaultAnimationDuration}) {
    assert(index >= 0);

    final int itemIndex = _indexToItemIndex(index);
    assert(itemIndex >= 0 && itemIndex <= _itemsCount);

    // Increment the incoming and outgoing item indices to account
    // for the insertion.
    for (final _ActiveItem item in _incomingItems) {
      if (item.itemIndex >= itemIndex) {
        item.itemIndex += 1;
      }
    }
    for (final _ActiveItem item in _outgoingItems) {
      if (item.itemIndex >= itemIndex) {
        item.itemIndex += 1;
      }
    }

    final AnimationController controller = AnimationController(
      duration: duration,
      vsync: this,
    );
    final _ActiveItem incomingItem = _ActiveItem.incoming(
      controller,
      itemIndex,
    );
    setState(() {
      _incomingItems
        ..add(incomingItem)
        ..sort();
      _itemsCount += 1;
    });

    controller.forward().then<void>((_) {
      _removeActiveItemAt(_incomingItems, incomingItem.itemIndex)!
          .controller!
          .dispose();
    });
  }

  /// Insert multiple items at [index] and start an animation that will be passed
  /// to [AnimatedGrid.itemBuilder] or [AnimatedList.itemBuilder] when the items
  /// are visible.
  void insertAllItems(int index, int length,
      {Duration duration = _defaultAnimationDuration}) {
    for (int i = 0; i < length; i++) {
      insertItem(index + i, duration: duration);
    }
  }

  /// Remove the item at [index] and start an animation that will be passed
  /// to [builder] when the item is visible.
  ///
  /// Items are removed immediately. After an item has been removed, its index
  /// will no longer be passed to the subclass' [SliverAnimatedGrid.itemBuilder]
  /// or [SliverAnimatedList.itemBuilder]. However the item will still appear
  /// for [duration], and during that time [builder] must construct its widget
  /// as needed.
  ///
  /// This method's semantics are the same as Dart's [List.remove] method: it
  /// decreases the length of items by one and shifts
  /// all items at or before [index] towards the beginning of the list of items.
  void removeItem(int index, AnimatedRemovedItemBuilder builder,
      {Duration duration = _defaultAnimationDuration}) {
    assert(index >= 0);

    final int itemIndex = _indexToItemIndex(index);
    assert(itemIndex >= 0 && itemIndex < _itemsCount);
    assert(_activeItemAt(_outgoingItems, itemIndex) == null);

    final _ActiveItem? incomingItem =
        _removeActiveItemAt(_incomingItems, itemIndex);
    final AnimationController controller = incomingItem?.controller ??
        AnimationController(duration: duration, value: 1, vsync: this);
    final _ActiveItem outgoingItem =
        _ActiveItem.outgoing(controller, itemIndex, builder);
    setState(() {
      _outgoingItems
        ..add(outgoingItem)
        ..sort();
    });

    controller.reverse().then<void>((value) {
      _removeActiveItemAt(_outgoingItems, outgoingItem.itemIndex)!
          .controller!
          .dispose();

      // Decrement the incoming and outgoing item indices to account
      // for the removal.
      for (final _ActiveItem item in _incomingItems) {
        if (item.itemIndex > outgoingItem.itemIndex) {
          item.itemIndex -= 1;
        }
      }
      for (final _ActiveItem item in _outgoingItems) {
        if (item.itemIndex > outgoingItem.itemIndex) {
          item.itemIndex -= 1;
        }
      }

      setState(() => _itemsCount -= 1);
    });
  }

  /// Remove all the items and start an animation that will be passed to
  /// `builder` when the items are visible.
  ///
  /// Items are removed immediately. However, the
  /// items will still appear for `duration` and during that time
  /// `builder` must construct its widget as needed.
  ///
  /// This method's semantics are the same as Dart's [List.clear] method: it
  /// removes all the items in the list.
  void removeAllItems(AnimatedRemovedItemBuilder builder,
      {Duration duration = _defaultAnimationDuration}) {
    for (int i = _itemsCount - 1; i >= 0; i--) {
      removeItem(i, builder, duration: duration);
    }
  }

  @override
  void initState() {
    _itemsCount = widget.itemCount;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollable = widget.scrollableState ?? Scrollable.of(context);
    if (_autoScroller?.scrollable != _scrollable) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        _scrollable,
        onScrollViewScrolled: _handleScrollableAutoScrolled,
        velocityScalar: widget.autoScrollerVelocityScalar,
      );
    }
    _screenSize = switch (_scrollDirection) {
      Axis.horizontal => MediaQuery.sizeOf(context).width,
      Axis.vertical => MediaQuery.sizeOf(context).height,
    };
  }

  @override
  void didUpdateWidget(covariant ManualSliverReorderableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount) {
      cancelReorder();
    }

    if (widget.autoScrollerVelocityScalar !=
        oldWidget.autoScrollerVelocityScalar) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        _scrollable,
        onScrollViewScrolled: _handleScrollableAutoScrolled,
        velocityScalar: widget.autoScrollerVelocityScalar,
      );
    }
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    _scrollPosition?.removeListener(_dragUpdateItems);
    widget.manualAnimationController?.removeListener(_updateDragItemPosition);
    widget.manualAnimationController
        ?.removeStatusListener(_resetWhenAnimationCompleted);
    for (final _ActiveItem item in _incomingItems.followedBy(_outgoingItems)) {
      item.controller!.dispose();
    }
    super.dispose();
  }

  /// Initiate the dragging of the item at [index] that was started with
  /// the pointer down [event].
  ///
  /// The given [recognizer] will be used to recognize and start the drag
  /// item tracking and lead to either an item reorder, or a canceled drag.
  ///
  /// Most applications will not use this directly, but will wrap the item
  /// (or part of the item, like a drag handle) in either a
  /// [ManualReorderableDragStartListener] or [ManualReorderableDelayedDragStartListener]
  /// which call this method when they detect the gesture that triggers a drag
  /// start.
  void startItemDragReorder({
    required int index,
    required PointerDownEvent event,
    required MultiDragGestureRecognizer recognizer,
  }) {
    assert(0 <= index && index < widget.itemCount);
    if (!widget.canStartReorder) return;
    final canStart = switch (widget.reorderType) {
      ReorderType.all || ReorderType.drag => true,
      _ => false,
    };
    if (_isReordering || !canStart) return;
    setState(() {
      if (_dragInfo != null) {
        cancelReorder();
      } else if (_recognizer != null && _recognizerPointer != event.pointer) {
        _recognizer!.dispose();
        _recognizer = null;
        _recognizerPointer = null;
      }

      if (_items.containsKey(index)) {
        _dragIndex = index;
        _recognizer = recognizer
          ..onStart = _dragStart
          ..addPointer(event);
        _recognizerPointer = event.pointer;
      } else {
        // TODO(darrenaustin): Can we handle this better, maybe scroll to the item?
        throw Exception('Attempting to start a drag on a non-visible item');
      }
    });
  }

  /// MANUAL API
  /// Initiate the dragging of the item at [startIndex] to [endIndex]
  /// [doBefore] - function which execute before reordering
  /// [scrollDuration] - duration for scroll from [startIndex] to [endIndex]
  /// [itemAnimationDuration] - duration for dragging animation item`s to [endIndex] after scrolling
  Future<void> startItemManualReorder(
    int startIndex,
    int endIndex, {
    Future<void> Function(int startIndex, int endIndex)? doBefore,
    Duration? scrollDuration,
    Duration? itemAnimationDuration,
  }) async {
    assert(
      0 <= startIndex &&
          startIndex < widget.itemCount &&
          0 <= endIndex &&
          endIndex < widget.itemCount,
      'Start index and end index must be greater or equal zero and less than item count',
    );
    assert(startIndex != endIndex, 'Start index and end index can`t be equals');
    assert(
      widget.manualAnimationController != null,
      'Animation controller can`t be null for manual reordering',
    );
    if (!widget.canStartReorder) return;
    final canStart = switch (widget.reorderType) {
      ReorderType.all || ReorderType.manual => true,
      _ => false,
    };

    final animationController = widget.manualAnimationController;

    if (animationController == null) return;

    if (_isReordering || !canStart) return;

    await doBefore?.call(startIndex, endIndex);

    _itemExtent = widget.itemExtent;
    _scrollPosition = _scrollable.position;
    _isReordering = true;
    _startIndex = startIndex;
    _endIndex = endIndex;
    _dragIndex = startIndex;

    // Need widget to drag is located on screen
    if (_items[_startIndex] == null ||
        !(_items[_startIndex]?.mounted ?? false)) {
      _dragReset();
      return;
    }

    // Set up
    _startPosition = _calculateItemPosition(_startIndex!);

    _autoScroller?.stopAutoScroll();
    _dragStart(_startPosition);

    _lastDelta = Offset.zero;

    _endPosition = _calculateItemPosition(_endIndex!);
    final endPositionDelta =
        _endIndex! > _startIndex! ? _dragInfo!.itemExtent : 0;
    _endPosition = Offset(
      _endPosition.dx,
      _endPosition.dy + endPositionDelta,
    );

    // Scroll item to item has endIndex if need
    await _scrollToEndItemIfNeed(scrollDuration);

    // Start current item dragging animation to item has endIndex
    await _animateItemToEndItem(
      animationController,
      itemAnimationDuration: itemAnimationDuration,
    );
  }

  void _resetWhenAnimationCompleted(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _isScrolling = false;
      _dragInfo!.end(DragEndDetails());
      _scrollPosition?.removeListener(_dragUpdateItems);
    }
  }

  // Update dragInfo position
  void _updateDragItemPosition() {
    final curDelta = _calculateCurrentPositionDelta(_scrollDirection);
    final delta =
        _calculatePositionDeltaForDragging(_scrollDirection, curDelta);
    _lastDelta = curDelta;
    _dragInfo!.update(
      DragUpdateDetails(globalPosition: _dragInfo!.dragPosition, delta: delta),
    );
  }

  // Calculate current delta by animation
  Offset _calculateCurrentPositionDelta(Axis scrollDirection) {
    return switch (scrollDirection) {
      Axis.horizontal =>
        Offset(_deltaOffset!.dy * _animation.value, _deltaOffset!.dy),
      Axis.vertical =>
        Offset(_deltaOffset!.dx, _deltaOffset!.dy * _animation.value),
    };
  }

  // Calculate position delta for dragging
  Offset _calculatePositionDeltaForDragging(
      Axis scrollDirection, Offset positionDelta) {
    return switch (scrollDirection) {
      Axis.horizontal =>
        Offset(positionDelta.dx - _lastDelta.dx, positionDelta.dy),
      Axis.vertical =>
        Offset(_deltaOffset!.dx, positionDelta.dy - _lastDelta.dy),
    };
  }

  // Calculate position delta between dragInfo and end item after scrolling
  Offset _calculatePositionDelta(
      Axis scrollDirection, Offset startPosition, Offset endPosition) {
    return switch (scrollDirection) {
      Axis.horizontal =>
        Offset(endPosition.dx - startPosition.dx, endPosition.dy),
      Axis.vertical =>
        Offset(endPosition.dx, endPosition.dy - startPosition.dy),
    };
  }

  // Calculate item position
  Offset _calculateItemPosition(int index) {
    final position = _itemOffsetTopLeftAt(index);
    final itemIndex =
        _items.entries.firstWhere((element) => element.value.mounted).key;

    _itemExtent ??= _itemExtentAt(position != null ? index : itemIndex);

    final scrollOffset = _scrollPosition!.pixels;

    if (position != null) {
      return switch (_scrollDirection) {
        Axis.horizontal => Offset(position.dx, position.dy + scrollOffset),
        Axis.vertical => Offset(position.dx + scrollOffset, position.dy),
      };
    }

    return switch (_scrollDirection) {
      Axis.horizontal =>
        Offset(_itemExtent! * index, _itemOffsetTopLeftAt(itemIndex)!.dy),
      Axis.vertical =>
        Offset(_itemOffsetTopLeftAt(itemIndex)!.dx, _itemExtent! * index),
    };
  }

  // Scroll from start item to end item if need
  Future<void> _scrollToEndItemIfNeed(Duration? scrollDuration) async {
    final endDy = _endPosition.dy.abs();
    final startDy = _startPosition.dy;
    final isEndItemExist = _items[_endIndex!]?.mounted ?? false;
    final scrollPixels = _scrollPosition!.pixels;

    final isToEnd = _isToEnd();
    final isToStart = _isToStart();

    // Return if no need scroll
    if (!isToEnd && !isToStart) return;

    double? positionToScroll;

    if (isToEnd) {
      positionToScroll = isEndItemExist
          ? endDy - (endDy - startDy - scrollPixels) + _itemExtent! * 2
          : (endDy) +
              kBottomNavigationBarHeight -
              kToolbarHeight -
              (startDy - scrollPixels).abs();
    } else if (isToStart) {
      positionToScroll = isEndItemExist
          ? startDy - (startDy - endDy) - _itemExtent! * 2
          : endDy - (_endIndex == 0 ? 0 : _itemExtent!);
    }

    if (positionToScroll == null) return;

    positionToScroll = min(positionToScroll, _scrollPosition!.maxScrollExtent);

    _scrollPosition?.addListener(_dragUpdateItems);

    _isScrolling = true;

    await _scrollPosition?.animateTo(
      positionToScroll,
      duration: scrollDuration ?? _scrollAnimationDuration,
      curve: widget.manualScrollAnimationCurve,
    );

    _isScrolling = false;

    final endItemPosition = isToStart
        ? _itemOffsetTopLeftAt(_endIndex!)!
        : _itemOffsetBottomLeftAt(_endIndex!)!;
    final dy = endItemPosition.dy +
        _scrollPosition!.pixels +
        (_endIndex == widget.itemCount - 1 ? _itemExtent! / 6 : 0);
    _endPosition = Offset(endItemPosition.dx, dy);
    _startPosition = Offset(
      _startPosition.dx,
      startDy + _scrollPosition!.pixels,
    );
  }

  // Is item located in end? (vertical - end item below start item)
  bool _isToEnd() {
    final pixels = _scrollPosition!.pixels;
    final endDy = _endPosition.dy.abs();
    final scrollPixels = pixels < _itemExtent!
        ? pixels
        : (_startPosition.dy - _scrollPosition!.pixels).abs();

    return _endIndex! > _startIndex! &&
        endDy > _screenSize - kBottomNavigationBarHeight + scrollPixels;
  }

  // Is item located in start? (vertical - end item is higher than start item)
  bool _isToStart() {
    final endDy = _endPosition.dy.abs();
    final scrollPixels = _scrollPosition!.pixels;

    return _endIndex! < _startIndex! &&
        endDy - _itemExtent! * 1.5 < scrollPixels;
  }

  // Animate dragInfo to endIndex from position
  Future<void> _animateItemToEndItem(
    AnimationController animationController, {
    Duration? itemAnimationDuration,
  }) async {
    _deltaOffset = _calculatePositionDelta(
      _scrollDirection,
      Offset(_startPosition.dx, _startPosition.dy + _itemExtent!),
      _endPosition,
    );

    _deltaOffset = _deltaOffset!.dy < 0
        ? Offset(_deltaOffset!.dx, _deltaOffset!.dy + _itemExtent!)
        : _deltaOffset;

    _animation = CurvedAnimation(
      parent: animationController,
      curve: widget.manualItemAnimationCurve,
    );

    animationController
      ..duration = itemAnimationDuration ?? _itemAnimationDuration
      ..reset()
      ..addListener(_updateDragItemPosition)
      ..addStatusListener(_resetWhenAnimationCompleted);
    await animationController.forward();
  }

  /// Cancel any item drag in progress.
  ///
  /// This should be called before any major changes to the item list
  /// occur so that any item drags will not get confused by
  /// changes to the underlying list.
  ///
  /// If a drag operation is in progress, this will immediately reset
  /// the list to back to its pre-drag state.
  ///
  /// If no drag is active, this will do nothing.
  void cancelReorder() {
    setState(() {
      _dragReset();
    });
  }

  void _registerItem(_ManualReorderableItemState item) {
    if (_dragInfo != null && _items[item.index] != item) {
      item.updateForGap(_dragInfo!.index, _dragInfo!.index,
          _dragInfo!.itemExtent, false, _reverse);
    }
    _items[item.index] = item;
    if (item.index == _dragInfo?.index) {
      item.dragging = true;
      item.rebuild();
    }
  }

  void _unregisterItem(int index, _ManualReorderableItemState item) {
    final _ManualReorderableItemState? currentItem = _items[index];
    if (currentItem == item) {
      //_items.remove(index);
    }
  }

  Drag? _dragStart(Offset position) {
    assert(_dragInfo == null);
    final _ManualReorderableItemState item = _items[_dragIndex!]!;
    item.dragging = true;
    widget.onReorderStart?.call(_dragIndex!);
    item.rebuild();

    _insertIndex = item.index;
    _dragInfo = _DragInfo(
      item: item,
      initialPosition: position,
      scrollDirection: _scrollDirection,
      onUpdate: _dragUpdate,
      onCancel: _dragCancel,
      onEnd: _dragEnd,
      onDropCompleted: _dropCompleted,
      proxyDecorator: widget.proxyDecorator,
      tickerProvider: this,
    );
    _dragInfo!.startDrag();

    final OverlayState overlay = Overlay.of(context, debugRequiredFor: widget);
    assert(_overlayEntry == null);
    _overlayEntry = OverlayEntry(builder: _dragInfo!.createProxy);
    overlay.insert(_overlayEntry!);

    for (final _ManualReorderableItemState childItem in _items.values) {
      if (childItem == item || !childItem.mounted) {
        continue;
      }
      childItem.updateForGap(
          _insertIndex!, _insertIndex!, _dragInfo!.itemExtent, false, _reverse);
    }
    return _dragInfo;
  }

  void _dragUpdate(_DragInfo item, Offset position, Offset delta) {
    setState(() {
      _overlayEntry?.markNeedsBuild();
      _dragUpdateItems();
      if (_isScrolling) return;
      _autoScroller?.startAutoScrollIfNecessary(_dragTargetRect);
    });
  }

  void _dragCancel(_DragInfo item) {
    setState(() {
      _dragReset();
    });
  }

  void _dragEnd(_DragInfo item) {
    setState(() {
      if (_insertIndex == item.index) {
        _finalDropPosition = _itemOffsetTopLeftAt(_insertIndex!);
      } else if (_reverse) {
        if (_insertIndex! >= _items.length) {
          // Drop at the starting position of the last element and offset its own extent
          _finalDropPosition = _itemOffsetTopLeftAt(_items.length - 1)! -
              _extentOffset(item.itemExtent, _scrollDirection);
        } else {
          // Drop at the end of the current element occupying the insert position
          _finalDropPosition = _itemOffsetTopLeftAt(_insertIndex!)! +
              _extentOffset(_itemExtentAt(_insertIndex!), _scrollDirection);
        }
      } else {
        if (_insertIndex! == 0) {
          // Drop at the starting position of the first element and offset its own extent
          _finalDropPosition = _itemOffsetTopLeftAt(0)! -
              _extentOffset(item.itemExtent, _scrollDirection);
        } else {
          // Drop at the end of the previous element occupying the insert position
          final int atIndex = _insertIndex! - 1;
          _finalDropPosition = _itemOffsetTopLeftAt(atIndex)! +
              _extentOffset(_itemExtentAt(atIndex), _scrollDirection);
        }
      }
    });
    widget.onReorderEnd?.call(_insertIndex!);
  }

  void _dropCompleted() {
    final int fromIndex = _dragIndex!;
    final int toIndex = _insertIndex!;
    if (fromIndex != toIndex) {
      widget.onReorder.call(fromIndex, toIndex);
    }
    setState(() {
      _dragReset();
    });
  }

  void _dragReset() {
    if (_dragInfo != null) {
      if (_dragIndex != null && _items.containsKey(_dragIndex)) {
        final _ManualReorderableItemState dragItem = _items[_dragIndex!]!;
        dragItem._dragging = false;
        dragItem.rebuild();
        _dragIndex = null;
      }
      _dragInfo?.dispose();
      _dragInfo = null;
      _autoScroller?.stopAutoScroll();
      _resetItemGap();
      _recognizer?.dispose();
      _recognizer = null;
      _overlayEntry?.remove();
      _overlayEntry?.dispose();
      _overlayEntry = null;
      _finalDropPosition = null;
    }
    _isReordering = false;
    _startIndex = null;
    _endIndex = null;
    _lastDelta = Offset.zero;
    _deltaOffset = null;
    _isScrolling = false;
    _itemExtent = null;
  }

  void _resetItemGap() {
    for (final _ManualReorderableItemState item in _items.values) {
      item.resetGap();
    }
  }

  void _handleScrollableAutoScrolled() {
    if (_dragInfo == null) {
      return;
    }
    _dragUpdateItems();
    // Continue scrolling if the drag is still in progress.
    if (_isScrolling) return;
    _autoScroller?.startAutoScrollIfNecessary(_dragTargetRect);
  }

  void _dragUpdateItems() {
    assert(_dragInfo != null);
    final double gapExtent = _dragInfo!.itemExtent;
    final double proxyItemStart = _offsetExtent(
        _dragInfo!.dragPosition - _dragInfo!.dragOffset, _scrollDirection);
    final double proxyItemEnd = proxyItemStart + gapExtent;

    // Find the new index for inserting the item being dragged.
    int newIndex = _insertIndex!;
    for (final _ManualReorderableItemState item in _items.values) {
      if (item.index == _dragIndex! || !item.mounted) {
        continue;
      }

      final Rect geometry = item.targetGeometry();
      final double itemStart =
          _scrollDirection == Axis.vertical ? geometry.top : geometry.left;
      final double itemExtent =
          _scrollDirection == Axis.vertical ? geometry.height : geometry.width;
      final double itemEnd = itemStart + itemExtent;
      final double itemMiddle = itemStart + itemExtent / 2;

      if (_reverse) {
        if (itemEnd >= proxyItemEnd && proxyItemEnd >= itemMiddle) {
          // The start of the proxy is in the beginning half of the item, so
          // we should swap the item with the gap and we are done looking for
          // the new index.
          newIndex = item.index;
          break;
        } else if (itemMiddle >= proxyItemStart &&
            proxyItemStart >= itemStart) {
          // The end of the proxy is in the ending half of the item, so
          // we should swap the item with the gap and we are done looking for
          // the new index.
          newIndex = item.index + 1;
          break;
        } else if (itemStart > proxyItemEnd && newIndex < (item.index + 1)) {
          newIndex = item.index + 1;
        } else if (proxyItemStart > itemEnd && newIndex > item.index) {
          newIndex = item.index;
        }
      } else {
        if (itemStart <= proxyItemStart && proxyItemStart <= itemMiddle) {
          // The start of the proxy is in the beginning half of the item, so
          // we should swap the item with the gap and we are done looking for
          // the new index.
          newIndex = item.index;
          break;
        } else if (itemMiddle <= proxyItemEnd && proxyItemEnd <= itemEnd) {
          // The end of the proxy is in the ending half of the item, so
          // we should swap the item with the gap and we are done looking for
          // the new index.
          newIndex = item.index + 1;
          break;
        } else if (itemEnd < proxyItemStart && newIndex < (item.index + 1)) {
          newIndex = item.index + 1;
        } else if (proxyItemEnd < itemStart && newIndex > item.index) {
          newIndex = item.index;
        }
      }
    }

    if (newIndex != _insertIndex) {
      _insertIndex = newIndex;
      for (final _ManualReorderableItemState item in _items.values) {
        if (item.index == _dragIndex! || !item.mounted) {
          continue;
        }
        item.updateForGap(_dragIndex!, newIndex, gapExtent, true, _reverse);
      }
    }
  }

  Rect get _dragTargetRect {
    final Offset origin = _dragInfo!.dragPosition - _dragInfo!.dragOffset;
    return Rect.fromLTWH(origin.dx, origin.dy, _dragInfo!.itemSize.width,
        _dragInfo!.itemSize.height);
  }

  Offset? _itemOffsetTopLeftAt(int index) {
    final item = _items[index];

    if (item == null) return null;
    if (!item.mounted) return null;

    return item.targetGeometry().topLeft;
  }

  Offset? _itemOffsetBottomLeftAt(int index) {
    final item = _items[index];

    if (item == null) return null;
    if (!item.mounted) return null;

    return item.targetGeometry().bottomLeft;
  }

  double _itemExtentAt(int index) {
    return _sizeExtent(_items[index]!.targetGeometry().size, _scrollDirection);
  }

  Widget _itemBuilder(BuildContext context, int index) {
    if (_dragInfo != null && index >= widget.itemCount) {
      return switch (_scrollDirection) {
        Axis.horizontal => SizedBox(width: _dragInfo!.itemExtent),
        Axis.vertical => SizedBox(height: _dragInfo!.itemExtent),
      };
    }
    final _ActiveItem? outgoingItem = _activeItemAt(_outgoingItems, index);
    if (outgoingItem != null) {
      return outgoingItem.removedItemBuilder!(
        context,
        outgoingItem.controller!.view,
      );
    }

    final _ActiveItem? incomingItem = _activeItemAt(_incomingItems, index);
    final Animation<double> animation =
        incomingItem?.controller?.view ?? kAlwaysCompleteAnimation;

    final Widget child = widget.itemBuilder(
      context,
      _itemIndexToIndex(index),
      animation,
    );
    assert(child.key != null, 'All list items must have a key');
    final OverlayState overlay = Overlay.of(context, debugRequiredFor: widget);
    return ManualReorderableDelayedDragStartListener(
      key: child.key,
      index: index,
      child: _ManualReorderableItem(
        key: _ManualReorderableItemGlobalKey(child.key!, index, this),
        index: index,
        capturedThemes:
            InheritedTheme.capture(from: context, to: overlay.context),
        child: _wrapWithSemantics(child, index),
      ),
    );
  }

  Widget _wrapWithSemantics(Widget child, int index) {
    void reorder(int startIndex, int endIndex) {
      if (startIndex != endIndex) {
        widget.onReorder(startIndex, endIndex);
      }
    }

    // First, determine which semantics actions apply.
    final Map<CustomSemanticsAction, VoidCallback> semanticsActions =
        <CustomSemanticsAction, VoidCallback>{};

    // Create the appropriate semantics actions.
    void moveToStart() => reorder(index, 0);
    void moveToEnd() => reorder(index, widget.itemCount);
    void moveBefore() => reorder(index, index - 1);
    // To move after, go to index+2 because it is moved to the space
    // before index+2, which is after the space at index+1.
    void moveAfter() => reorder(index, index + 2);

    final WidgetsLocalizations localizations = WidgetsLocalizations.of(context);
    final bool isHorizontal = _scrollDirection == Axis.horizontal;
    // If the item can move to before its current position in the list.
    if (index > 0) {
      semanticsActions[
              CustomSemanticsAction(label: localizations.reorderItemToStart)] =
          moveToStart;
      String reorderItemBefore = localizations.reorderItemUp;
      if (isHorizontal) {
        reorderItemBefore = Directionality.of(context) == TextDirection.ltr
            ? localizations.reorderItemLeft
            : localizations.reorderItemRight;
      }
      semanticsActions[CustomSemanticsAction(label: reorderItemBefore)] =
          moveBefore;
    }

    // If the item can move to after its current position in the list.
    if (index < widget.itemCount - 1) {
      String reorderItemAfter = localizations.reorderItemDown;
      if (isHorizontal) {
        reorderItemAfter = Directionality.of(context) == TextDirection.ltr
            ? localizations.reorderItemRight
            : localizations.reorderItemLeft;
      }
      semanticsActions[CustomSemanticsAction(label: reorderItemAfter)] =
          moveAfter;
      semanticsActions[
              CustomSemanticsAction(label: localizations.reorderItemToEnd)] =
          moveToEnd;
    }

    // Pass toWrap with a GlobalKey into the item so that when it
    // gets dragged, the accessibility framework can preserve the selected
    // state of the dragging item.
    //
    // Also apply the relevant custom accessibility actions for moving the item
    // up, down, to the start, and to the end of the list.
    return Semantics(
      container: true,
      customSemanticsActions: semanticsActions,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasOverlay(context));
    final SliverChildDelegate childrenDelegate = _createDelegate();
    if (widget.itemExtent != null) {
      return SliverFixedExtentList(
        delegate: childrenDelegate,
        itemExtent: widget.itemExtent!,
      );
    } else if (widget.itemExtentBuilder != null) {
      return SliverVariedExtentList(
        delegate: childrenDelegate,
        itemExtentBuilder: widget.itemExtentBuilder!,
      );
    } else if (widget.prototypeItem != null) {
      return SliverPrototypeExtentList(
        delegate: childrenDelegate,
        prototypeItem: widget.prototypeItem!,
      );
    }
    return SliverList(delegate: childrenDelegate);
  }
}

class _ManualReorderableItem extends StatefulWidget {
  const _ManualReorderableItem({
    required Key key,
    required this.index,
    required this.child,
    required this.capturedThemes,
  }) : super(key: key);

  final int index;
  final Widget child;
  final CapturedThemes capturedThemes;

  @override
  _ManualReorderableItemState createState() => _ManualReorderableItemState();
}

class _ManualReorderableItemState extends State<_ManualReorderableItem> {
  late ManualSliverReorderableListState _listState;

  Offset _startOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  AnimationController? _offsetAnimation;

  Key get key => widget.key!;

  int get index => widget.index;

  bool get dragging => _dragging;

  set dragging(bool dragging) {
    if (mounted) {
      setState(() {
        _dragging = dragging;
      });
    }
  }

  bool _dragging = false;

  @override
  void initState() {
    _listState = ManualSliverReorderableList.of(context);
    _listState._registerItem(this);
    super.initState();
  }

  @override
  void dispose() {
    _offsetAnimation?.dispose();
    _offsetAnimation = null;
    _listState._unregisterItem(index, this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ManualReorderableItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _listState._unregisterItem(oldWidget.index, this);
      _listState._registerItem(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dragging) {
      final Size size = _extentSize(
          _listState._dragInfo!.itemExtent, _listState._scrollDirection);
      return SizedBox.fromSize(size: size);
    }
    _listState._registerItem(this);
    return Transform(
      transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
      child: widget.child,
    );
  }

  @override
  void deactivate() {
    _listState._unregisterItem(index, this);
    super.deactivate();
  }

  Offset get offset {
    if (_offsetAnimation != null) {
      final double animValue =
          Curves.easeInOut.transform(_offsetAnimation!.value);
      return Offset.lerp(_startOffset, _targetOffset, animValue)!;
    }
    return _targetOffset;
  }

  void updateForGap(int dragIndex, int gapIndex, double gapExtent, bool animate,
      bool reverse) {
    // An offset needs to be added to create a gap when we are between the
    // moving element (dragIndex) and the current gap position (gapIndex).
    // For how to update the gap position, refer to [_dragUpdateItems].
    final Offset newTargetOffset;
    if (gapIndex < dragIndex && index < dragIndex && index >= gapIndex) {
      newTargetOffset = _extentOffset(
          reverse ? -gapExtent : gapExtent, _listState._scrollDirection);
    } else if (gapIndex > dragIndex && index > dragIndex && index < gapIndex) {
      newTargetOffset = _extentOffset(
          reverse ? gapExtent : -gapExtent, _listState._scrollDirection);
    } else {
      newTargetOffset = Offset.zero;
    }
    if (newTargetOffset != _targetOffset) {
      _targetOffset = newTargetOffset;
      if (animate) {
        if (_offsetAnimation == null) {
          _offsetAnimation = AnimationController(
            vsync: _listState,
            duration: const Duration(milliseconds: 250),
          )
            ..addListener(rebuild)
            ..addStatusListener((status) {
              if (status == AnimationStatus.completed) {
                _startOffset = _targetOffset;
                _offsetAnimation!.dispose();
                _offsetAnimation = null;
              }
            })
            ..forward();
        } else {
          _startOffset = offset;
          _offsetAnimation!.forward(from: 0);
        }
      } else {
        if (_offsetAnimation != null) {
          _offsetAnimation!.dispose();
          _offsetAnimation = null;
        }
        _startOffset = _targetOffset;
      }
      rebuild();
    }
  }

  void resetGap() {
    if (_offsetAnimation != null) {
      _offsetAnimation!.dispose();
      _offsetAnimation = null;
    }
    _startOffset = Offset.zero;
    _targetOffset = Offset.zero;
    rebuild();
  }

  Rect targetGeometry() {
    final RenderBox itemRenderBox = context.findRenderObject()! as RenderBox;
    final Offset itemPosition =
        itemRenderBox.localToGlobal(Offset.zero) + _targetOffset;
    return itemPosition & itemRenderBox.size;
  }

  void rebuild() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _ActiveItem implements Comparable<_ActiveItem> {
  _ActiveItem.incoming(this.controller, this.itemIndex)
      : removedItemBuilder = null;

  _ActiveItem.outgoing(
      this.controller, this.itemIndex, this.removedItemBuilder);

  _ActiveItem.index(this.itemIndex)
      : controller = null,
        removedItemBuilder = null;

  final AnimationController? controller;
  final AnimatedRemovedItemBuilder? removedItemBuilder;
  int itemIndex;

  @override
  int compareTo(_ActiveItem other) => itemIndex - other.itemIndex;
}

typedef _DragItemUpdate = void Function(
    _DragInfo item, Offset position, Offset delta);
typedef _DragItemCallback = void Function(_DragInfo item);

class _DragInfo extends Drag {
  _DragInfo({
    required _ManualReorderableItemState item,
    Offset initialPosition = Offset.zero,
    this.scrollDirection = Axis.vertical,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
    this.onDropCompleted,
    this.proxyDecorator,
    required this.tickerProvider,
  }) {
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectCreated(
        library: 'package:flutter/widgets.dart',
        className: '$_DragInfo',
        object: this,
      );
    }
    final RenderBox itemRenderBox =
        item.context.findRenderObject()! as RenderBox;
    listState = item._listState;
    index = item.index;
    child = item.widget.child;
    capturedThemes = item.widget.capturedThemes;
    dragPosition = initialPosition;
    dragOffset = itemRenderBox.globalToLocal(initialPosition);
    itemSize = item.context.size!;
    itemExtent = _sizeExtent(itemSize, scrollDirection);
    scrollable = Scrollable.of(item.context);
  }

  final Axis scrollDirection;
  final _DragItemUpdate? onUpdate;
  final _DragItemCallback? onEnd;
  final _DragItemCallback? onCancel;
  final VoidCallback? onDropCompleted;
  final ManualReorderItemProxyDecorator? proxyDecorator;
  final TickerProvider tickerProvider;

  late ManualSliverReorderableListState listState;
  late int index;
  late Widget child;
  late Offset dragPosition;
  late Offset dragOffset;
  late Size itemSize;
  late double itemExtent;
  late CapturedThemes capturedThemes;
  ScrollableState? scrollable;
  AnimationController? _proxyAnimation;

  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }
    _proxyAnimation?.dispose();
  }

  void startDrag() {
    _proxyAnimation = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: 250),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          _dropCompleted();
        }
      })
      ..forward();
  }

  @override
  void update(DragUpdateDetails details) {
    final Offset delta = _restrictAxis(details.delta, scrollDirection);
    dragPosition += delta;
    onUpdate?.call(this, dragPosition, details.delta);
  }

  @override
  void end(DragEndDetails details) {
    _proxyAnimation!.reverse();
    onEnd?.call(this);
  }

  @override
  void cancel() {
    _proxyAnimation?.dispose();
    _proxyAnimation = null;
    onCancel?.call(this);
  }

  void _dropCompleted() {
    _proxyAnimation?.dispose();
    _proxyAnimation = null;
    onDropCompleted?.call();
  }

  Widget createProxy(BuildContext context) {
    return capturedThemes.wrap(
      _DragItemProxy(
        listState: listState,
        index: index,
        size: itemSize,
        animation: _proxyAnimation!,
        position: dragPosition - dragOffset - _overlayOrigin(context),
        proxyDecorator: proxyDecorator,
        child: child,
      ),
    );
  }
}

Offset _overlayOrigin(BuildContext context) {
  final OverlayState overlay =
      Overlay.of(context, debugRequiredFor: context.widget);
  final RenderBox overlayBox = overlay.context.findRenderObject()! as RenderBox;
  return overlayBox.localToGlobal(Offset.zero);
}

class _DragItemProxy extends StatelessWidget {
  const _DragItemProxy({
    required this.listState,
    required this.index,
    required this.child,
    required this.position,
    required this.size,
    required this.animation,
    required this.proxyDecorator,
  });

  final ManualSliverReorderableListState listState;
  final int index;
  final Widget child;
  final Offset position;
  final Size size;
  final AnimationController animation;
  final ManualReorderItemProxyDecorator? proxyDecorator;

  @override
  Widget build(BuildContext context) {
    final Widget proxyChild =
        proxyDecorator?.call(child, index, animation.view) ?? child;
    final Offset overlayOrigin = _overlayOrigin(context);

    return MediaQuery(
      // Remove the top padding so that any nested list views in the item
      // won't pick up the scaffold's padding in the overlay.
      data: MediaQuery.of(context).removePadding(removeTop: true),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          Offset effectivePosition = position;
          final Offset? dropPosition = listState._finalDropPosition;
          if (dropPosition != null) {
            effectivePosition = Offset.lerp(dropPosition - overlayOrigin,
                effectivePosition, Curves.easeOut.transform(animation.value))!;
          }
          return Positioned(
            left: effectivePosition.dx,
            top: effectivePosition.dy,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          );
        },
        child: proxyChild,
      ),
    );
  }
}

double _sizeExtent(Size size, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => size.width,
    Axis.vertical => size.height,
  };
}

Size _extentSize(double extent, Axis scrollDirection) {
  switch (scrollDirection) {
    case Axis.horizontal:
      return Size(extent, 0);
    case Axis.vertical:
      return Size(0, extent);
  }
}

double _offsetExtent(Offset offset, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => offset.dx,
    Axis.vertical => offset.dy,
  };
}

Offset _extentOffset(double extent, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => Offset(extent, 0),
    Axis.vertical => Offset(0, extent),
  };
}

Offset _restrictAxis(Offset offset, Axis scrollDirection) {
  return switch (scrollDirection) {
    Axis.horizontal => Offset(offset.dx, 0),
    Axis.vertical => Offset(0, offset.dy),
  };
}

class ManualReorderableDragStartListener extends StatelessWidget {
  /// Creates a listener for a drag immediately following a pointer down
  /// event over the given child widget.
  ///
  /// This is most commonly used to wrap part of a list item like a drag
  /// handle.
  const ManualReorderableDragStartListener({
    super.key,
    required this.child,
    required this.index,
    this.enabled = true,
  });

  /// The widget for which the application would like to respond to a tap and
  /// drag gesture by starting a reordering drag on a reorderable list.
  final Widget child;

  /// The index of the associated item that will be dragged in the list.
  final int index;

  /// Whether the [child] item can be dragged and moved in the list.
  ///
  /// If true, the item can be moved to another location in the list when the
  /// user taps on the child. If false, tapping on the child will be ignored.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled ? (event) => _startDragging(context, event) : null,
      child: child,
    );
  }

  MultiDragGestureRecognizer createRecognizer() {
    return ImmediateMultiDragGestureRecognizer(debugOwner: this);
  }

  void _startDragging(BuildContext context, PointerDownEvent event) {
    final DeviceGestureSettings? gestureSettings =
        MediaQuery.maybeGestureSettingsOf(context);
    final ManualSliverReorderableListState? list =
        ManualSliverReorderableList.maybeOf(context);
    list?.startItemDragReorder(
      index: index,
      event: event,
      recognizer: createRecognizer()..gestureSettings = gestureSettings,
    );
  }
}

/// A wrapper widget that will recognize the start of a drag operation by
/// looking for a long press event. Once it is recognized, it will start
/// a drag operation on the wrapped item in the reorderable list.
class ManualReorderableDelayedDragStartListener
    extends ManualReorderableDragStartListener {
  /// Creates a listener for an drag following a long press event over the
  /// given child widget.
  ///
  /// This is most commonly used to wrap an entire list item in a reorderable
  /// list.
  const ManualReorderableDelayedDragStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(debugOwner: this);
  }
}

// A global key that takes its identity from the object and uses a value of a
// particular type to identify itself.
//
// The difference with GlobalObjectKey is that it uses [==] instead of [identical]
// of the objects used to generate widgets.
@optionalTypeArgs
class _ManualReorderableItemGlobalKey extends GlobalObjectKey {
  const _ManualReorderableItemGlobalKey(this.subKey, this.index, this.state)
      : super(subKey);

  final Key subKey;
  final int index;
  final ManualSliverReorderableListState state;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _ManualReorderableItemGlobalKey &&
        other.subKey == subKey &&
        other.index == index &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(subKey, index, state);
}
