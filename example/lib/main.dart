import 'package:flutter/material.dart';
import 'package:scrollable_draggable_bottom_sheet/scrollable_draggable_bottom_sheet.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ScrollableDraggableBottomSheetController _controller;

  double _value = 200;

  @override
  void initState() {
    super.initState();
    _controller = ScrollableDraggableBottomSheetController();
  }

  @override
  Widget build(BuildContext context) {
    Widget initialChild = ListView.builder(
      primary: false,
      shrinkWrap: true,
      itemCount: 10,
      itemBuilder: (context, index) => const ListTile(
        title: Text("test text"),
        isThreeLine: true,
        subtitle: Text("subtitle"),
      ),
    );

    Widget _secondChild = ListView.builder(
      primary: false,
      shrinkWrap: true,
      itemCount: 10,
      itemBuilder: (context, index) => const ListTile(
        title: Text("second screen"),
        isThreeLine: true,
        subtitle: Text("2nd subtitle"),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          const Placeholder(),
          Positioned(
            top: 20,
            left: 20,
            child: ElevatedButton(
              onPressed: () async {
                _controller.animateSheetToNewMinMax(
                  minHeight: 200,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  child: _secondChild,
                );
              },
              child: const Text("No snap"),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () async {
                _controller.animateBackToSnap(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: initialChild);
              },
              child: const Text("Snap mode"),
            ),
          ),
          Positioned(
            top: 60,
            right: 60,
            child: ElevatedButton(
              onPressed: () async {
                _controller.openSheet(duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack);
              },
              child: const Text("open sheet"),
            ),
          ),
          Positioned(bottom: _value, right: 20, child: IconButton(onPressed: () {}, icon: const Icon(Icons.ac_unit))),
          ScrollableDraggableBottomSheet(
            controller: _controller,
            minHeight: MediaQuery.of(context).size.height * 0.1,
            snapHeights: [MediaQuery.of(context).size.height * 0.3, MediaQuery.of(context).size.height * 0.5],
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            onPanelSlide: (height, value) {
              setState(() {
                _value = height + 20;
              });
            },
            onPanelSlideWithoutSnap: (height, value) {
              print("the value of this non snap is ---------> $value, $height");
            },
            snappingListener: SnappingListener(
              fromIndex: 0,
              toIndex: 2,
              onPanleSlide: (height, value) {
                print("in the state of 1 & 2");
              },
            ),
            initialChild: initialChild,
            header: Container(
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
            ),
            headerHeight: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.5), blurRadius: 4, offset: Offset(0, -2))],
            ),
          ),
        ],
      ),
    );
  }
}
