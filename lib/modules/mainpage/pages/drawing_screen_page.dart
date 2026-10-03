import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DrawingScreenPage extends StatefulWidget {
  const DrawingScreenPage({super.key});

  @override
  State<DrawingScreenPage> createState() => DrawingScreenPageState();
}

const maps = {
  'Bakurani': 'assets/hd/bakurani_map.webp',
  'Ozeti': 'assets/hd/ozeti_map.webp',
  'Zesty': 'assets/hd/zesty_map.webp',
};

class Stroke {
  Stroke(this.color);
  final List<Offset> points = [];
  var color;
}

class DrawingScreenPageState extends State<DrawingScreenPage> {
  String mapValue = maps.values.first;
  final List<Stroke> _strokes = [];
  bool _showMenu = false;
  bool _draw = false;
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
              child: GestureDetector(
                onTertiaryTapDown: (e) {
                  setState(() {
                    _showMenu = true;
                    _showMenuX = e.localPosition.dx;
                    _showMenuY = e.localPosition.dy;
                  });
                },
                onTapDown: (e) {
                  setState(() {
                    _draw = false;
                  });
                },
                child: Stack(
                  children: [
                    InteractiveViewer(
                      panEnabled: !_draw,
                      maxScale: 30.0,
                      child: FittedBox(
                        child: SizedBox(
                            width: 8192,
                            height: 8192,
                            child: GestureDetector(
                              onPanStart: (e) {
                                if (_draw){
                                  setState(() {
                                    _strokes.add(Stroke(Colors.red)..points.add(e.localPosition));
                                  });
                                }
                              },
                              onPanUpdate: (e) {
                                if (_draw){
                                  setState(() {
                                    _strokes.last.points.add(e.localPosition);
                                  });
                                }
                              },
                              child: Stack(children: [
                                Image.asset(mapValue),
                                CustomPaint(painter: StrokePainter(_strokes),)
                              ]),
                            ),
                        )
                      ),
                    ),
                    if (_showMenu)
                      Positioned(
                        left: _showMenuX,
                        top: _showMenuY,
                        child: Row(
                          spacing: 6,
                          children: [
                            IconButton.filled(
                              onPressed: () => {
                                setState(() {
                                  _showMenu = false;
                                  _draw = true;
                                })
                              },
                              icon: Image.asset('assets/icons/draw_arrow.png', width: 24, height: 24,),
                            )
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class StrokePainter extends CustomPainter {
  StrokePainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(s.points.first, s.points.last, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}