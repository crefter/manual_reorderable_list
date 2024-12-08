A Flutter package to create reorderable list, which can manual reordering!

<img alt="Example video" src="https://raw.githubusercontent.com/crefter/manual_reorderable_list/master/assets/example.mov" width="300"/>

## Features

Use this package in your Flutter app to:
- Usual reordering by drag
- Create manual reorderable list
- Create manual reorderable list with animations! (Like AnimatedList)

## Getting started

Add this to your package's pubspec.yaml file:
```
dependencies:
  manual_reorderable_list: ^1.0.0
```

## Usage

First, create global key to have access for manual reorderable list state (ex. start manual reordering or animated remove/insert):

```dart
final gk = GlobalKey<ManualReorderableListState>();
```

Second, create animation controller in your widget:

```dart
late final AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
```

Third, create ManualReorderableList (example):

```dart
ManualReorderableList(
            key: gk,
            shrinkWrap: false,
            manualAnimationController: animationController,
            manualItemAnimationCurve: Curves.easeInOut,
            manualScrollAnimationCurve: Curves.easeInOut,
            itemCount: ints.length,
            reorderType: ReorderType.all,
            proxyDecorator: (child, index, animation) {
              return Material(
                type: MaterialType.transparency,
                child: Ink(
                  color: Colors.red,
                  child: child,
                ),
              );
            },
            itemBuilder: (context, index, animation) {
              final element = ints[index];
              return KeyedSubtree(
                key: ValueKey(element),
                child: AnimatedListTile(
                  element: element,
                  index: index,
                  animation: animation,
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              print('onReorder');
              var oldElement = ints.removeAt(oldIndex);
              final indexTo = newIndex > oldIndex ? newIndex - 1 : newIndex;
              ints.insert(indexTo, oldElement);
            },
            onReorderStart: (index) {
              print('onReorderStart, index = $index');
            },
            onReorderEnd: (index) {
              print('onReorderEnd, index = $index');
            },
          ),
```

Fourth, start manual reordering:

```dart
FloatingActionButton(
              onPressed: () {
                gk.currentState!.startItemManualReorder(3, 10);
              },
              tooltip: 'Test manual reordering',
              child: const Icon(Icons.start),
            ),
```

That`s all!

Also you can use methods like in AnimatedList to insert\remove items:

```dart
Positioned(
            bottom: 50,
            left: 20,
            child: FloatingActionButton(
              onPressed: () {
                ints.insert(10, 100);
                gk.currentState!.insertItem(10);
                ints.remove(10);
                gk.currentState!.removeItem(
                  10,
                  (context, animation) {
                    return AnimatedListTile(
                      element: ints[10],
                      index: 10,
                      animation: animation,
                    );
                  },
                  duration: const Duration(milliseconds: 1000),
                );
              },
              tooltip: 'Test animation',
              child: const Icon(Icons.add),
            ),
          ),
```

For more info see <a href="https://github.com/crefter/app_onboarding/blob/master/example/lib/main.dart">example</a>