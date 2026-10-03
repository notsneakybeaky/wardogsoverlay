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

// WARDOGS has 3 teams, markers and lines are tinted with the team color
const teams = {
  'red': Colors.red,
  'blue': Colors.blue,
  'yellow': Colors.yellow,
};

// Squad style: the menu shows these categories first, clicking one opens its icons.
// Icons load from assets/icons/<name>.png, the first icon is the category's button.
const iconCategories = {
  'orders': ['marker/attack', 'marker/defend', 'marker/observe'],
  'enemy': ['marker/enemy_infantry', 'marker/enemy_vehicle', 'marker/mine'],
  'support': ['marker/ammo', 'marker/artillery'],
  'infantry': ['infantry/infantry', 'infantry/manpad', 'infantry/rpg', 'infantry/anti_tank', 'infantry/machine_gunner'],
};

// UI look: light black at 50% opacity, square corners
const panelColor = Color(0x80202020);
const panelBorder = BorderSide(color: Colors.white24);
const labelStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.2,
);
const menuWidth = 306.0; // 6 buttons of 44 + spacing

class Stroke {
  Stroke(this.color, {this.team = 'red'});
  final List<Offset> points = [];
  var color;
  final String team;

  Map<String, dynamic> toJson() => {
        'type': 'stroke',
        'team': team,
        'x1': points.first.dx, 'y1': points.first.dy,
        'x2': points.last.dx, 'y2': points.last.dy,
      };
  factory Stroke.fromJson(Map<String, dynamic> j) =>
      Stroke(teams[j['team']] ?? Colors.red, team: j['team'])
        ..points.addAll([
          Offset((j['x1'] as num).toDouble(), (j['y1'] as num).toDouble()),
          Offset((j['x2'] as num).toDouble(), (j['y2'] as num).toDouble()),
        ]);
}

class PlacedIcon {
  PlacedIcon(this.name, this.pos, this.team);
  final String name; // 'rally_point' -> assets/icons/rally_point.png
  final Offset pos;  // map pixels, 0..8192
  final String team;

  Map<String, dynamic> toJson() => {'type': 'icon', 'icon': name, 'team': team, 'x': pos.dx, 'y': pos.dy};
  factory PlacedIcon.fromJson(Map<String, dynamic> j) =>
      PlacedIcon(j['icon'], Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()), j['team']);
}

class DrawingScreenPageState extends State<DrawingScreenPage> {
  String mapValue = maps.values.first;
  final List<Stroke> _strokes = [];
  bool _showMenu = false;
  bool _draw = false;
  var _showMenuX;
  var _showMenuY;
  String _team = teams.keys.first;
  final List<PlacedIcon> _icons = [];
  String? _placing; // icon picked from the menu, null = not placing
  bool _erase = false; // eraser mode: tap one of your lines or icons to remove it
  final List<Object> _mine = []; // strokes and icons this player made, oldest first

  // remove one of your own strokes or icons from the map
  void _remove(Object item) {
    _mine.remove(item);
    _strokes.remove(item);
    _icons.remove(item);
  }

  // your newest stroke or icon under the tap, or null
  Object? _mineAt(Offset p) {
    for (final item in _mine.reversed) {
      if (item is PlacedIcon && (item.pos - p).distance < 100) return item;
      if (item is Stroke && _distanceToLine(p, item.points.first, item.points.last) < 60) return item;
    }
    return null;
  }
  String? _category; // open category in the menu, null = top level

  // square, see-through menu buttons; the active one gets a team-colored border
  ButtonStyle _buttonStyle(bool active) => IconButton.styleFrom(
        backgroundColor: panelColor,
        foregroundColor: Colors.white,
        hoverColor: Colors.white24,
        highlightColor: Colors.white38,
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: active
              ? BorderSide(color: teams[_team]!, width: 2)
              : panelBorder,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  color: panelColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.all(Radius.circular(4)),
                    side: panelBorder,
                  ),
                  child: (DropdownButton<String>(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    style: labelStyle,
                    dropdownColor: const Color(0xE0202020),
                    iconEnabledColor: Colors.white70,
                    underline: const SizedBox(),
                    value: mapValue,
                    onChanged: (String? value) {
                      setState(() {
                        mapValue = value!;
                      });
                    },
                    items: [
                      for (final e in maps.entries)
                        DropdownMenuItem(value: e.value, child: Text(e.key.toUpperCase())),
                    ],
                  )),
                ),
                Card(
                  color: panelColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.all(Radius.circular(4)),
                    side: panelBorder,
                  ),
                  child: DropdownButton<String>(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    style: labelStyle,
                    dropdownColor: const Color(0xE0202020),
                    iconEnabledColor: Colors.white70,
                    underline: const SizedBox(),
                    value: _team,
                    onChanged: (String? value) {
                      setState(() {
                        _team = value!;
                      });
                    },
                    items: [
                      for (final t in teams.entries)
                        DropdownMenuItem(
                          value: t.key,
                          child: Text(t.key.toUpperCase(), style: labelStyle.copyWith(color: t.value)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: GestureDetector(
                onTertiaryTapDown: (e) {
                  setState(() {
                    _showMenu = true;
                    _showMenuX = e.localPosition.dx;
                    _showMenuY = e.localPosition.dy;
                    _category = null;
                  });
                },
                onTapDown: (e) {
                  setState(() {
                    _draw = false;
                  });
                },
                child: Stack(
                  children: [
                    // map sits against the right edge of the screen, with a thin border
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38, width: 2),
                        ),
                        child: InteractiveViewer(
                          panEnabled: !_draw,
                          maxScale: 30.0,
                          child: FittedBox(
                            child: SizedBox(
                                width: 8192,
                                height: 8192,
                                child: GestureDetector(
                                  onSecondaryTapDown: _draw ? (e) {
                                    _draw = false;
                                  } : null,
                                  // null when not drawing, so the InteractiveViewer can pan
                                  onPanStart: _draw ? (e) {
                                    setState(() {
                                      final stroke = Stroke(teams[_team], team: _team)..points.add(e.localPosition);
                                      _strokes.add(stroke);
                                      _mine.add(stroke);
                                    });
                                  } : null,
                                  onPanUpdate: _draw ? (e) {
                                    setState(() {
                                      _strokes.last.points.add(e.localPosition);
                                    });
                                  } : null,
                                  onTapUp: (_placing == null && !_erase) ? null : (e) {
                                    setState(() {
                                      if (_erase) {
                                        final hit = _mineAt(e.localPosition);
                                        if (hit != null) _remove(hit);
                                      } else {
                                        final icon = PlacedIcon(_placing!, e.localPosition, _team);
                                        _icons.add(icon);
                                        _mine.add(icon);
                                        _placing = null;
                                      }
                                    });
                                  },
                                  child: Stack(children: [
                                    Image.asset(mapValue),
                                    CustomPaint(size: const Size(8192, 8192), painter: GridPainter()),
                                    CustomPaint(painter: StrokePainter(_strokes),),
                                    for (final i in _icons)
                                      Positioned(
                                        left: i.pos.dx - 100,
                                        top: i.pos.dy - 100,
                                        width: 200,
                                        height: 200,
                                        child: Image.asset('assets/icons/${i.name}.png', color: teams[i.team]),
                                      ),
                                  ]),
                                ),
                            )
                          ),
                        ),
                      ),
                    ),
                    if (_showMenu)
                      Positioned(
                        // keep the menu on screen when you click near the right edge
                        left: (_showMenuX as double).clamp(0.0, MediaQuery.sizeOf(context).width - menuWidth - 16),
                        top: _showMenuY,
                        child: Container(
                          width: menuWidth,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xB0101010),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.fromBorderSide(panelBorder),
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // top level: draw, pan and the categories
                              if (_category == null) ...[
                                IconButton.filled(
                                  tooltip: 'draw',
                                  style: _buttonStyle(_draw),
                                  onPressed: () => {
                                    setState(() {
                                      _showMenu = false;
                                      _draw = true;
                                      _erase = false;
                                    })
                                  },
                                  icon: Icon(Icons.arrow_right_alt, size: 24, color: Colors.white,),
                                ),
                                // pan mode: stop drawing / placing
                                IconButton.filled(
                                  tooltip: 'pan',
                                  style: _buttonStyle(!_draw && !_erase && _placing == null),
                                  onPressed: () {
                                    setState(() {
                                      _showMenu = false;
                                      _draw = false;
                                      _erase = false;
                                      _placing = null;
                                    });
                                  },
                                  icon: const Icon(Icons.pan_tool, size: 24),
                                ),
                                // eraser: tap one of your own lines or icons to remove it
                                IconButton.filled(
                                  tooltip: 'erase',
                                  style: _buttonStyle(_erase),
                                  onPressed: () {
                                    setState(() {
                                      _showMenu = false;
                                      _erase = true;
                                      _draw = false;
                                      _placing = null;
                                    });
                                  },
                                  icon: const Icon(Icons.auto_fix_normal, size: 24),
                                ),
                                // undo: remove the last thing you drew or placed
                                IconButton.filled(
                                  tooltip: 'undo',
                                  style: _buttonStyle(false),
                                  onPressed: _mine.isEmpty ? null : () {
                                    setState(() {
                                      _remove(_mine.last);
                                    });
                                  },
                                  icon: const Icon(Icons.undo, size: 24, color: Colors.white,),
                                ),
                                // clear: remove everything you drew or placed
                                IconButton.filled(
                                  tooltip: 'clear all',
                                  style: _buttonStyle(false),
                                  onPressed: _mine.isEmpty ? null : () {
                                    setState(() {
                                      for (final item in _mine.toList()) {
                                        _remove(item);
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.delete_sweep, size: 24, color: Colors.white),
                                ),
                                for (final c in iconCategories.entries)
                                  IconButton.filled(
                                    tooltip: c.key,
                                    style: _buttonStyle(c.value.contains(_placing)),
                                    onPressed: () {
                                      setState(() {
                                        _category = c.key;
                                      });
                                    },
                                    icon: Image.asset('assets/icons/${c.value.first}.png', width: 24, height: 24),
                                  ),
                              ],
                              // inside a category: back, then its icons
                              if (_category != null) ...[
                                IconButton.filled(
                                  tooltip: 'back',
                                  style: _buttonStyle(false),
                                  onPressed: () {
                                    setState(() {
                                      _category = null;
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back, size: 24),
                                ),
                                for (final name in iconCategories[_category]!)
                                  IconButton.filled(
                                    tooltip: name,
                                    style: _buttonStyle(_placing == name),
                                    onPressed: () {
                                      setState(() {
                                        _placing = name;
                                        _draw = false;
                                        _erase = false;
                                        _showMenu = false;
                                        _category = null;
                                      });
                                    },
                                    icon: Image.asset('assets/icons/$name.png', width: 24, height: 24),
                                  ),
                              ],
                            ],
                          ),
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

// Squad style grid: 10x10 big squares (A-J across, 1-10 down), each split into 3x3 boxes.
// Letters along the top, numbers down the left, and every square has its name (A1, B4...) in its top-left.
class GridPainter extends CustomPainter {
  static const letters = 'ABCDEFGHIJ';

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 10; // one big square, in map pixels
    final small = Paint()..color = Colors.white12..strokeWidth = 2;
    final big = Paint()..color = Colors.white38..strokeWidth = 5;

    // 3x3 boxes inside each square
    for (var i = 1; i < 30; i++) {
      if (i % 3 == 0) continue;
      final x = cell * i / 3, y = size.height * i / 30;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), small);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), small);
    }
    // big squares
    for (var i = 1; i < 10; i++) {
      final x = cell * i, y = size.height * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), big);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), big);
    }

    // letters along the top edge, numbers down the left edge
    for (var i = 0; i < 10; i++) {
      _text(canvas, letters[i], 120, Offset(cell * i + cell / 2, 10), center: true);
      _text(canvas, '${i + 1}', 120, Offset(10, size.height * i / 10 + size.height / 20), center: false, middle: true);
    }

    // name of every square in its top-left corner
    for (var col = 0; col < 10; col++) {
      for (var row = 0; row < 10; row++) {
        _text(canvas, '${letters[col]}${row + 1}', 60,
            Offset(cell * col + 16, size.height * row / 10 + 12));
      }
    }
  }

  void _text(Canvas canvas, String text, double fontSize, Offset at,
      {bool center = false, bool middle = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white70,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(
      center ? at.dx - tp.width / 2 : at.dx,
      middle ? at.dy - tp.height / 2 : at.dy,
    ));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// shortest distance from p to the line a-b, in map pixels
double _distanceToLine(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0).toDouble();
  return (p - (a + ab * t)).distance;
}
