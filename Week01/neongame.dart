import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/scheduler.dart';

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeonDashApp());
}

class NeonDashApp extends StatelessWidget {
  const NeonDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neon Dash',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyanAccent),
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // Game state
  final Random _rng = Random();
  double _playerX = 0.5; // 0..1 normalized across width
  double _playerY = 0.85; // fixed lane height near bottom
  double _playerVelX = 0.0;
  double _speed = 300.0; // px per second, base obstacle speed
  double _time = 0.0;
  int _score = 0;
  int _best = 0;
  bool _running = false;
  bool _gameOver = false;
  double _difficultyTimer = 0.0;

  // Objects
  final List<Obstacle> _obstacles = [];
  final List<Pickup> _pickups = [];
  final List<Particle> _particles = [];
  final List<Star> _stars = [];

  // Input
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _spawnInitialStars();
  }

  void _spawnInitialStars() {
    _stars.clear();
    for (int i = 0; i < 120; i++) {
      _stars.add(Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        depth: _rng.nextDouble() * 0.9 + 0.1,
      ));
    }
  }

  void _start() {
    setState(() {
      _running = true;
      _gameOver = false;
      _score = 0;
      _time = 0.0;
      _speed = 300.0;
      _difficultyTimer = 0.0;
      _obstacles.clear();
      _pickups.clear();
      _particles.clear();
      _playerX = 0.5;
      _playerVelX = 0.0;
      _ticker.start();
    });
  }

  void _pause() {
    setState(() {
      _running = false;
    });
    _ticker.stop();
  }

  void _resume() {
    setState(() {
      _running = true;
    });
    _ticker.start();
  }

  void _endGame() {
    setState(() {
      _gameOver = true;
      _running = false;
      _best = max(_best, _score);
    });
    _ticker.stop();
  }

  double? _lastTick;
  void _tick(Duration elapsed) {
    final double t = elapsed.inMicroseconds / 1e6;
    _lastTick ??= t;
    double dt = (t - _lastTick!).clamp(0.0, 0.05); // cap to avoid jumps
    _lastTick = t;

    setState(() {
      _update(dt);
    });
  }

  void _update(double dt) {
    _time += dt;
    _difficultyTimer += dt;

    // Difficulty ramp
    if (_difficultyTimer > 2.0) {
      _difficultyTimer = 0.0;
      _speed += 18; // gradually faster
    }

    // Move background stars for parallax
    for (final s in _stars) {
      s.y += dt * (0.03 + 0.2 * (1.0 - s.depth));
      if (s.y > 1.0) {
        s.y -= 1.0;
        s.x = _rng.nextDouble();
        s.depth = _rng.nextDouble() * 0.9 + 0.1;
      }
    }

    // Spawn obstacles
    if (_obstacles.isEmpty || _obstacles.last.y > 0.2) {
      // spawn a row with random gaps
      final double w = 0.12 + _rng.nextDouble() * 0.1;
      final double x = _rng.nextDouble() * (1.0 - w);
      _obstacles.add(Obstacle(x: x, y: -0.1, w: w, h: 0.04 + _rng.nextDouble() * 0.05, hue: _rng.nextDouble()));
    }

    // Occasionally spawn pickups
    if (_rng.nextDouble() < 0.02) {
      _pickups.add(Pickup(x: _rng.nextDouble() * 0.8 + 0.1, y: -0.05, hue: _rng.nextDouble()));
    }

    // Update obstacles & pickups positions
    for (final o in _obstacles) {
      o.y += (_speed / 600.0) * dt; // normalized speed (~1 screen / 2s initially)
      o.rot += dt * 1.2;
    }
    for (final c in _pickups) {
      c.y += (_speed / 650.0) * dt;
      c.rot -= dt * 1.5;
    }

    _obstacles.removeWhere((o) => o.y > 1.2);
    _pickups.removeWhere((c) => c.y > 1.2);

    // Update player
    _playerX = (_playerX + _playerVelX * dt).clamp(0.06, 0.94);

    // Collisions
    final Rect pRect = Rect.fromCenter(
      center: Offset(_playerX, _playerY),
      width: 0.08,
      height: 0.08,
    );

    for (final o in _obstacles) {
      final rect = Rect.fromLTWH(o.x, o.y, o.w, o.h);
      if (rect.overlaps(pRect.inflate(-0.015))) {
        _explode(_playerX, _playerY);
        _endGame();
        return;
      }
    }

    for (int i = _pickups.length - 1; i >= 0; i--) {
      final c = _pickups[i];
      final Rect r = Rect.fromCenter(center: Offset(c.x, c.y), width: 0.05, height: 0.05);
      if (r.overlaps(pRect)) {
        _score += 10;
        _spawnRing(c.x, c.y);
        _pickups.removeAt(i);
      }
    }

    // Score increments with survival time
    _score += (dt * 6).floor();

    // Particle updates
    for (final p in _particles) {
      p.vy += dt * -0.2; // slight upward drift
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt + dt * 0.2; // fall a bit
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _explode(double x, double y) {
    for (int i = 0; i < 50; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final s = _rng.nextDouble() * 0.8 + 0.2;
      _particles.add(Particle(
        x: x,
        y: y,
        vx: cos(a) * s,
        vy: sin(a) * s,
        life: _rng.nextDouble() * 0.6 + 0.4,
        hue: _rng.nextDouble(),
      ));
    }
  }

  void _spawnRing(double x, double y) {
    for (int i = 0; i < 24; i++) {
      final a = (i / 24.0) * 2 * pi;
      _particles.add(Particle(
        x: x + cos(a) * 0.02,
        y: y + sin(a) * 0.02,
        vx: cos(a) * 0.6,
        vy: sin(a) * 0.6,
        life: 0.5,
        hue: _rng.nextDouble(),
      ));
    }
  }

  void _onPanStart(DragStartDetails d, Size size) {
    _dragStart = d.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_dragStart == null) return;
    final dx = d.localPosition.dx - _dragStart!.dx;
    _playerVelX = dx / size.width * 4.0; // sensitivity
  }

  void _onPanEnd(DragEndDetails d) {
    _dragStart = null;
    _playerVelX = 0.0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Scaffold(
          body: SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: (d) => _onPanStart(d, size),
                  onPanUpdate: (d) => _onPanUpdate(d, size),
                  onPanEnd: _onPanEnd,
                  onTap: () {
                    if (!_running && !_gameOver) _start();
                    if (_gameOver) _start();
                  },
                  child: CustomPaint(
                    painter: _GamePainter(
                      time: _time,
                      playerX: _playerX,
                      playerY: _playerY,
                      running: _running,
                      gameOver: _gameOver,
                      obstacles: _obstacles,
                      pickups: _pickups,
                      particles: _particles,
                      stars: _stars,
                      score: _score,
                      best: _best,
                    ),
                    size: Size.infinite,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _running
                      ? ElevatedButton.icon(
                          onPressed: _pause,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _gameOver ? _start : (_running ? _pause : _resume),
                          icon: Icon(_gameOver ? Icons.restart_alt : Icons.play_arrow),
                          label: Text(_gameOver ? 'Restart' : (_running ? 'Pause' : 'Resume')),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.time,
    required this.playerX,
    required this.playerY,
    required this.running,
    required this.gameOver,
    required this.obstacles,
    required this.pickups,
    required this.particles,
    required this.stars,
    required this.score,
    required this.best,
  });

  final double time;
  final double playerX;
  final double playerY;
  final bool running;
  final bool gameOver;
  final List<Obstacle> obstacles;
  final List<Pickup> pickups;
  final List<Particle> particles;
  final List<Star> stars;
  final int score;
  final int best;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();

    // Helpers to convert normalized (0..1) to pixels
    double px(double nx) => nx * size.width;
    double py(double ny) => ny * size.height;

    // Background gradient
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF0B1020), Color(0xFF05070F)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Nebula glow
    for (int i = 0; i < 3; i++) {
      final cx = px(0.2 + 0.6 * (i / 2.0));
      final cy = py(0.25 + 0.2 * sin(time + i));
      final r = min(size.width, size.height) * (0.35 + 0.1 * i);
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
        ..color = HSVColor.fromAHSV(0.15, (time * 30 + i * 120) % 360, 0.7, 1.0).toColor());
    }

    // Stars parallax
    for (final s in stars) {
      final starPaint = Paint()..color = Colors.white.withOpacity(0.5 + 0.5 * (1 - s.depth));
      final r = (1.0 - s.depth) * 1.8 + 0.6;
      canvas.drawCircle(Offset(px(s.x), py(s.y)), r, starPaint);
    }

    // Lane glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px(0.05), py(0.1), px(0.9), py(0.85)), const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withOpacity(0.05),
    );

    // Obstacles
    for (final o in obstacles) {
      final Color c = HSVColor.fromAHSV(1.0, (o.hue * 360) % 360, 0.8, 0.9).toColor();
      final rect = Rect.fromLTWH(px(o.x), py(o.y), px(o.w), py(o.h));
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(o.rot);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: rect.width, height: rect.height), const Radius.circular(12));
      canvas.drawRRect(r, Paint()..color = c.withOpacity(0.85));
      canvas.drawRRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = c.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.restore();
    }

    // Pickups
    for (final c in pickups) {
      final Color col = HSVColor.fromAHSV(1.0, (c.hue * 360) % 360, 0.6, 1.0).toColor();
      canvas.save();
      canvas.translate(px(c.x), py(c.y));
      canvas.rotate(c.rot);
      final Path diamond = Path()
        ..moveTo(0, -px(0.018))
        ..lineTo(px(0.018), 0)
        ..lineTo(0, px(0.018))
        ..lineTo(-px(0.018), 0)
        ..close();
      canvas.drawPath(diamond, Paint()..color = col.withOpacity(0.9));
      canvas.drawPath(diamond, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = col
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.restore();
    }

    // Particles
    for (final s in particles) {
      final col = HSVColor.fromAHSV(
  max(s.life, 0).clamp(0.0, 1.0).toDouble(),
  (s.hue * 360) % 360,
  0.8,
  1.0,
).toColor();

      canvas.drawCircle(Offset(px(s.x), py(s.y)), px(0.007), Paint()
        ..color = col
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    // Player ship
    final shipX = px(playerX);
    final shipY = py(playerY);

    Path ship = Path();
    final double body = px(0.028);
    ship.moveTo(shipX, shipY - body);
    ship.lineTo(shipX + body * 0.8, shipY + body);
    ship.lineTo(shipX, shipY + body * 0.6);
    ship.lineTo(shipX - body * 0.8, shipY + body);
    ship.close();

    final Color shipColor = Colors.cyanAccent;
    canvas.drawPath(ship, Paint()..color = shipColor.withOpacity(0.95));
    canvas.drawPath(ship, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = shipColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // HUD
    final textPainter = (String text, double size, FontWeight w, Color c) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: w, color: c)),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    };

    final sTP = textPainter('Score: $score', 18, FontWeight.w600, Colors.white.withOpacity(0.95));
    sTP.paint(canvas, const Offset(16, 16));
    final bTP = textPainter('Best: $best', 16, FontWeight.w400, Colors.white70);
    bTP.paint(canvas, const Offset(16, 16 + 22));

    if (!running && !gameOver) {
      final title = textPainter('NEON DASH', 42, FontWeight.w800, Colors.white);
      title.paint(canvas, Offset(size.width / 2 - title.width / 2, size.height * 0.28));
      final hint = textPainter('Drag left/right to dodge. Tap to start', 16, FontWeight.w400, Colors.white70);
      hint.paint(canvas, Offset(size.width / 2 - hint.width / 2, size.height * 0.28 + 54));
    }
    if (gameOver) {
      final over = textPainter('GAME OVER', 36, FontWeight.w800, Colors.white);
      over.paint(canvas, Offset(size.width / 2 - over.width / 2, size.height * 0.35));
      final sc = textPainter('Score: $score', 20, FontWeight.w600, Colors.white70);
      sc.paint(canvas, Offset(size.width / 2 - sc.width / 2, size.height * 0.35 + 44));
      final tap = textPainter('Tap to Restart', 16, FontWeight.w500, Colors.white60);
      tap.paint(canvas, Offset(size.width / 2 - tap.width / 2, size.height * 0.35 + 72));
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}

class Obstacle {
  double x, y, w, h, rot, hue;
  Obstacle({required this.x, required this.y, required this.w, required this.h, required this.hue}) : rot = 0.0;
}

class Pickup {
  double x, y, rot, hue;
  Pickup({required this.x, required this.y, required this.hue}) : rot = 0.0;
}

class Particle {
  double x, y, vx, vy, life, hue;
  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.life, required this.hue});
}

class Star {
  double x, y, depth;
  Star({required this.x, required this.y, required this.depth});
}
