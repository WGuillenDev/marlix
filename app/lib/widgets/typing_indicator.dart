import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown while marlix is replying. The dots stay still when the system asks
/// for reduced motion.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'marlix está pensando',
      child: ExcludeSemantics(
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (var dot = 0; dot < 3; dot++) _dot(dot)],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'marlix está pensando…',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Each dot is darkest in its own third of the cycle.
  Widget _dot(int index) {
    final phase = (_controller.value * 3 - index) % 3;
    final strength = phase < 1 ? 1 - phase : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.line, AppColors.textSecondary, 0.3 + 0.7 * strength),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
