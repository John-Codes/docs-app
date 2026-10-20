import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A custom painter that draws a rotating conic gradient border around a rounded rectangle.
/// Used for the loading animation on the chat input box.
class ChatInputBorderPainter extends CustomPainter {
  ChatInputBorderPainter({
    required this.animation,
    required this.borderRadius,
    required this.strokeWidth,
    required this.gradientColors,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // Create a path for the rounded rectangle border
    final path = Path()..addRRect(rrect);

    // Calculate the rotation angle (0 to 2*pi)
    final rotation = animation.value * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: rotation - math.pi / 2, // Start from top
        endAngle: rotation + 3 * math.pi / 2,
        colors: gradientColors,
        stops: const [0.0, 0.33, 0.66, 1.0],
        tileMode: TileMode.clamp,
      ).createShader(rect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ChatInputBorderPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradientColors != gradientColors;
  }
}

/// A widget that displays an animated gradient border around its child.
/// Used for the loading state of the chat input box.
class AnimatedGradientBorder extends StatefulWidget {
  const AnimatedGradientBorder({
    super.key,
    required this.child,
    required this.isLoading,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.strokeWidth = 2.5,
    this.gradientColors,
    this.animationDuration = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final bool isLoading;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final List<Color>? gradientColors;
  final Duration animationDuration;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedGradientBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = widget.gradientColors ??
        [
          scheme.primary,
          scheme.secondary,
          scheme.tertiary,
          scheme.primary,
        ];

    return Stack(
      children: [
        // The child content
        widget.child,
        // The animated border overlay (only visible when loading)
        if (widget.isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: ChatInputBorderPainter(
                    animation: _controller,
                    borderRadius: widget.borderRadius,
                    strokeWidth: widget.strokeWidth,
                    gradientColors: colors,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
      ],
    );
  }
}