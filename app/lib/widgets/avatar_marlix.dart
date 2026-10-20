import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// What the avatar is doing. Each state is a pose the widget eases into.
enum AvatarState { idle, listening, thinking, speaking, happy }

/// Mouth layer (`boca_1` to `boca_3`) for a volume from 0.0 to 1.0.
/// `boca_0`, the closed smile, is the resting mouth and never comes from here.
int mouthForVolume(double volume) {
  if (volume < 0.2) return 1;
  if (volume < 0.6) return 2;
  return 3;
}

/// The avatar, assembled from the SVG layers in [folder] and animated in code
/// (docs/avatar.md). Any avatar whose folder holds the template's layer names
/// works without touching this widget. Fills the largest square it is given.
class AvatarMarlix extends StatefulWidget {
  const AvatarMarlix({super.key, required this.state, required this.folder, this.volume = 0});

  final AvatarState state;

  /// 0.0 to 1.0. Only read while [state] is [AvatarState.speaking].
  final double volume;

  /// Asset folder of the layers, e.g. `assets/avatars/marlix`.
  final String folder;

  @override
  State<AvatarMarlix> createState() => _AvatarMarlixState();
}

/// Every layer shares this canvas (S5-1), so all offsets below are in its units.
const _canvas = 512.0;

// The artwork is drawn in a design space and shrunk by [_fit] around its middle
// when exported, so it never clips while it bobs. Pivots and effects below are
// in design coordinates; [_at] and [_EffectsPainter] apply the same shrink.
const _fit = 0.92;
const _fitCenter = 270.0;

/// Alignment of a design-space point inside the square canvas.
Alignment _at(double x, double y) =>
    Alignment((256 + (x - 256) * _fit) / 256 - 1, (_fitCenter + (y - _fitCenter) * _fit) / 256 - 1);

// A cycle of the clock is 12 s. Every period below divides it, so the loop
// restarts without a jump.
const _cycleSeconds = 12;

class _AvatarMarlixState extends State<AvatarMarlix> with SingleTickerProviderStateMixin {
  // Where the ears and the tail join the body, and the middle of the eyes.
  static final _leftEarBase = _at(128, 93);
  static final _rightEarBase = _at(384, 93);
  static final _tailBase = _at(388, 442);
  static final _eyeCenter = _at(256, 172);

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cycleSeconds),
  );

  late _Layers _layers = _Layers(widget.folder);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With "remove animations" on, the avatar keeps its pose and only eases
    // between states: no floating, blinking or wagging.
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void didUpdateWidget(AvatarMarlix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder != widget.folder) _layers = _Layers(widget.folder);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  String get _mouth => switch (widget.state) {
    AvatarState.idle || AvatarState.listening => 'boca_0',
    AvatarState.thinking => 'boca_pensando',
    AvatarState.speaking => 'boca_${mouthForVolume(widget.volume)}',
    AvatarState.happy => 'boca_3',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'marlix',
      image: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final unit = constraints.biggest.shortestSide / _canvas;
            // Eases from wherever the pose is now, so a state change never jumps.
            return TweenAnimationBuilder<_Pose>(
              tween: _PoseTween(end: _Pose.of(widget.state)),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              builder: (context, pose, _) => AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => _buildFrame(pose, _clock.value * _cycleSeconds, unit),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrame(_Pose pose, double t, double unit) {
    final bob = -math.sin(2 * math.pi * t / 4) * 6 * pose.float;
    final bounce = -math.sin(math.pi * t / 0.4).abs() * 26 * pose.bounce;

    final earAngle = 0.35 * pose.earLift;
    final sway = math.sin(2 * math.pi * t / 4) * 0.03;
    final wag = math.sin(2 * math.pi * t / 0.75) * 0.12 * pose.wag;

    // Blinks for 0.3 s every 4 s: a triangle wave closes the eyes and reopens them.
    final blinkPhase = (t % 4 - 3.7) / 0.3;
    final blink = blinkPhase < 0 || blinkPhase > 1 ? 0.0 : 1 - (2 * blinkPhase - 1).abs();

    return Stack(
      fit: StackFit.expand,
      children: [
        // The ring of listening goes behind the character.
        IgnorePointer(
          child: CustomPaint(
            painter: _EffectsPainter(pose: pose, t: t, unit: unit, front: false),
          ),
        ),
        Transform.translate(
          offset: Offset(0, (bob + bounce) * unit),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.rotate(angle: wag, alignment: _tailBase, child: _layers.tail),
              _layers.body,
              _ear(_layers.leftEar, earAngle + sway, _leftEarBase),
              _ear(_layers.rightEar, -earAngle - sway, _rightEarBase),
              _layers.cheeks,
              Opacity(
                opacity: 1 - pose.happy,
                child: Transform(
                  alignment: _eyeCenter,
                  transform: Matrix4.diagonal3Values(1, 1 - 0.9 * blink, 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _layers.eyeRings,
                      // The pupils look up inside their rings.
                      Transform.translate(
                        offset: Offset(5 * pose.lookUp * unit, -13 * pose.lookUp * unit),
                        child: _layers.pupils,
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(opacity: pose.happy, child: _layers.happyEyes),
              _layers.nose,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 90),
                child: KeyedSubtree(
                  key: ValueKey(_mouth),
                  child: _layers.mouths[_mouth] ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _EffectsPainter(pose: pose, t: t, unit: unit, front: true),
          ),
        ),
      ],
    );
  }

  Widget _ear(Widget layer, double angle, Alignment pivot) =>
      Transform.rotate(angle: angle, alignment: pivot, child: layer);
}

/// The layer widgets, built once per folder: the static ones are not rebuilt on
/// every frame and are cached as one picture.
class _Layers {
  _Layers(String folder)
    : tail = _layer(folder, 'cola'),
      body = RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final name in const [
              'pies',
              'cuerpo',
              'panza',
              'brazo_izq',
              'brazo_der',
              'cabeza',
            ])
              _layer(folder, name),
          ],
        ),
      ),
      leftEar = _layer(folder, 'oreja_izq'),
      rightEar = _layer(folder, 'oreja_der'),
      cheeks = _layer(folder, 'mejillas'),
      eyeRings = _layer(folder, 'ojos_abiertos'),
      pupils = _layer(folder, 'pupilas'),
      happyEyes = _layer(folder, 'ojos_felices'),
      nose = _layer(folder, 'nariz'),
      mouths = {
        for (final name in const ['boca_0', 'boca_1', 'boca_2', 'boca_3', 'boca_pensando'])
          name: _layer(folder, name),
      };

  final Widget tail;
  final Widget body;
  final Widget leftEar;
  final Widget rightEar;
  final Widget cheeks;
  final Widget eyeRings;
  final Widget pupils;
  final Widget happyEyes;
  final Widget nose;
  final Map<String, Widget> mouths;

  // A missing layer leaves a gap instead of a red error screen.
  static Widget _layer(String folder, String name) => SvgPicture.asset(
    '$folder/$name.svg',
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
  );
}

/// How much of each movement is on, from 0 to 1. The widget turns them into
/// offsets, and easing between two poses is what makes a state change smooth.
class _Pose {
  const _Pose({
    this.float = 1,
    this.wag = 0.4,
    this.earLift = 0,
    this.lookUp = 0,
    this.happy = 0,
    this.bounce = 0,
    this.ring = 0,
    this.dots = 0,
    this.hearts = 0,
  });

  factory _Pose.of(AvatarState state) => switch (state) {
    AvatarState.idle => const _Pose(),
    AvatarState.listening => const _Pose(float: 0.5, wag: 0.2, earLift: 1, ring: 1),
    AvatarState.thinking => const _Pose(float: 0.5, wag: 0.2, lookUp: 1, dots: 1),
    AvatarState.speaking => const _Pose(float: 0.5, wag: 0.2),
    AvatarState.happy => const _Pose(float: 0, wag: 1, happy: 1, bounce: 1, hearts: 1),
  };

  final double float;
  final double wag;
  final double earLift;
  final double lookUp;
  final double happy;
  final double bounce;
  final double ring;
  final double dots;
  final double hearts;

  static _Pose lerp(_Pose a, _Pose b, double t) {
    double mix(double x, double y) => x + (y - x) * t;
    return _Pose(
      float: mix(a.float, b.float),
      wag: mix(a.wag, b.wag),
      earLift: mix(a.earLift, b.earLift),
      lookUp: mix(a.lookUp, b.lookUp),
      happy: mix(a.happy, b.happy),
      bounce: mix(a.bounce, b.bounce),
      ring: mix(a.ring, b.ring),
      dots: mix(a.dots, b.dots),
      hearts: mix(a.hearts, b.hearts),
    );
  }
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({required super.end});

  @override
  _Pose lerp(double t) => _Pose.lerp(begin ?? end!, end!, t);
}

/// The blue ring, thought bubbles and hearts, drawn on the same canvas as the
/// layers. [front] picks what goes over the character and what goes behind it.
class _EffectsPainter extends CustomPainter {
  _EffectsPainter({required this.pose, required this.t, required this.unit, required this.front});

  final _Pose pose;
  final double t;
  final double unit;
  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    // The layers are centered when the box is not square.
    canvas.translate((size.width - _canvas * unit) / 2, (size.height - _canvas * unit) / 2);
    canvas.scale(unit);
    // Same shrink as the exported layers.
    canvas.translate(256, _fitCenter);
    canvas.scale(_fit);
    canvas.translate(-256, -_fitCenter);

    if (!front) {
      if (pose.ring > 0.01) _ring(canvas);
      return;
    }
    if (pose.dots > 0.01) _thoughtBubbles(canvas);
    if (pose.hearts > 0.01) _hearts(canvas);
  }

  void _ring(Canvas canvas) {
    final paint = Paint()
      ..color = AppColors.listening.withValues(alpha: 0.55 * pose.ring)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final pulse = 1 + 0.015 * math.sin(2 * math.pi * t / 1.5);
    canvas.drawCircle(const Offset(256, 190), 188 * pulse, paint);
  }

  void _thoughtBubbles(Canvas canvas) {
    // Three bubbles growing away from the head, lighting up one after another.
    const bubbles = [(Offset(404, 105), 9.0), (Offset(427, 70), 14.0), (Offset(449, 26), 21.0)];
    for (var i = 0; i < bubbles.length; i++) {
      final pulse = math.max(0.0, math.sin(2 * math.pi * (t / 1.5 - i / 3)));
      final paint = Paint()
        ..color = AppColors.tanLight.withValues(alpha: pose.dots * (0.55 + 0.45 * pulse));
      canvas.drawCircle(bubbles[i].$1, bubbles[i].$2, paint);
    }
  }

  void _hearts(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final phase = (t / 2.4 + i / 3) % 1;
      final center = Offset(
        256 + (i - 1) * 84 + math.sin(2 * math.pi * phase) * 10,
        108 - phase * 92,
      );
      final paint = Paint()
        ..color = AppColors.crisis.withValues(alpha: pose.hearts * math.sin(math.pi * phase));
      canvas.drawPath(_heart(center, 15 + 6 * math.sin(math.pi * phase)), paint);
    }
  }

  Path _heart(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy + r * 0.9)
    ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.1, c.dx - r * 0.8, c.dy - r * 1.3, c.dx, c.dy - r * 0.4)
    ..cubicTo(c.dx + r * 0.8, c.dy - r * 1.3, c.dx + r * 1.6, c.dy - r * 0.1, c.dx, c.dy + r * 0.9)
    ..close();

  @override
  bool shouldRepaint(_EffectsPainter old) =>
      old.pose != pose || old.t != t || old.unit != unit || old.front != front;
}
