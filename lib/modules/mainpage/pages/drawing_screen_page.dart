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
  'orders': ['attack', 'defend', 'waypoint', 'rally_point', 'observe'],
  'enemy': ['enemy_infantry', 'enemy_vehicle', 'mine'],
  'support': ['medic', 'ammo', 'artillery'],
  'infantry': ['infantry', 'manpad', 'rpg', 'anti_tank', 'machine_gunner'],
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
                                  // null when not drawing, so the InteractiveViewer can pan
                                  onPanStart: _draw ? (e) {
                                    setState(() {
                                      _strokes.add(Stroke(teams[_team], team: _team)..points.add(e.localPosition));
                                    });
                                  } : null,
                                  onPanUpdate: _draw ? (e) {
                                    setState(() {
                                      _strokes.last.points.add(e.localPosition);
                                    });
                                  } : null,
                                  onTapUp: _placing == null ? null : (e) {
                                    setState(() {
                                      _icons.add(PlacedIcon(_placing!, e.localPosition, _team));
                                      _placing = null;
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
                                    })
                                  },
                                  icon: Image.asset('assets/icons/draw_arrow.png', width: 24, height: 24,),
                                ),
                                // pan mode: stop drawing / placing
                                IconButton.filled(
                                  tooltip: 'pan',
                                  style: _buttonStyle(!_draw && _placing == null),
                                  onPressed: () {
                                    setState(() {
                                      _showMenu = false;
                                      _draw = false;
                                      _placing = null;
                                    });
                                  },
                                  icon: const Icon(Icons.pan_tool, size: 24),
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

// plain 10x10 grid, A-J across, 1-10 down
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white24..strokeWidth = 2;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10, y = size.height * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
