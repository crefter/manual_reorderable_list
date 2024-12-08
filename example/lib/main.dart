import 'dart:math';

import 'package:flutter/material.dart';
import 'package:manual_reorderable_list/manual_reorderable_list.dart';

final _random = Random();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Example reordering list',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Example reordering list'),
    );
  }
}

final gk = GlobalKey<ManualReorderableListState>();

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'aaa'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'bbb'),
        ],
      ),
      body: const ReorderableList(),
    );
  }
}

class ReorderableList extends StatefulWidget {
  const ReorderableList({
    super.key,
  });

  @override
  State<ReorderableList> createState() => _ReorderableListState();
}

class _ReorderableListState extends State<ReorderableList>
    with SingleTickerProviderStateMixin {
  var ints = List.generate(40, (index) => index);
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
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
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                gk.currentState!.startItemManualReorder(6, 20);
              },
              tooltip: 'Test manual reordering',
              child: const Icon(Icons.start),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              onPressed: () {
                ints.insert(10, _random.nextInt(1000) + 10);
                gk.currentState!.insertItem(10);
              },
              tooltip: 'Insert animation',
              child: const Icon(Icons.add),
            ),
          ),
          Positioned(
            bottom: 90,
            left: 20,
            child: FloatingActionButton(
              onPressed: () {
                ints.removeAt(10);
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
              tooltip: 'Remove animation',
              child: const Icon(Icons.delete),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedListTile extends StatelessWidget {
  const AnimatedListTile({
    super.key,
    required this.element,
    required this.index,
    required this.animation,
  });

  final int element;
  final int index;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: ListTile(
          title: Text("Item $element"),
          subtitle: Text('Subtitle item $index'),
        ),
      ),
    );
  }
}
