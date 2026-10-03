import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DrawingScreenPage extends StatefulWidget {
  const DrawingScreenPage({super.key});

  @override
  State<DrawingScreenPage> createState() => DrawingScreenPageState();
}

const maps = {
  'Bakurani': 'assets/bakurani_map.webp',
  'Ozeti': 'assets/ozeti_map.webp',
  'Zesty': 'assets/zesty_map.webp',
};

class Stroke {
  Stroke(this.color);
  final List<Offset> points = [];
  var color;
}

class DrawingScreenPageState extends State<DrawingScreenPage> {
  String mapValue = maps.values.first;
  final List<Stroke> _strokes = [];
  var _showMenu = false;
  var _showMenuX;
  var _showMenuY;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          children: [
            Card(
              color: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.all(Radius.circular(8)),
              ),
              child: (DropdownButton<String>(
                padding: EdgeInsets.all(5),
                value: mapValue,
                onChanged: (String? value) {
                  setState(() {
                    mapValue = value!;
                  });
                },
                items: [
                  for (final e in maps.entries)
                    DropdownMenuItem(value: e.value, child: Text(e.key)),
                ],
              )),
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 20.0,
                child: GestureDetector(
                  onTertiaryTapDown: (e) {
                    setState(() {
                      _showMenu = true;
                      _showMenuX = e.localPosition.dx;
                      _showMenuY = e.localPosition.dy;
                    });
                  },
                  child: Stack(
                    children: [
                      Image.asset(mapValue),
                      if (_showMenu)
                      Positioned(
                        left: _showMenuX,
                        top: _showMenuY,
                        child: Row(
                          children: [
                            IconButton(
                                onPressed: () => {

                                },
                                icon:
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
