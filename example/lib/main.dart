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
                  child: const Text("hello everyone"),
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
                    duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, child: initialChild);
              },
              child: const Text("Snap mode"),
            ),
          ),
          ScrollableDraggableBottomSheet(
            controller: _controller,
            minHeight: MediaQuery.of(context).size.height * 0.2,
            snapHeight: MediaQuery.of(context).size.height * 0.4,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            onPanelSlideFromSnapPointToMax: (value) {
              // print("the value of this is ------------------> $value");
            },
            initialChild: initialChild,
          ),
        ],
      ),
    );
  }
}
