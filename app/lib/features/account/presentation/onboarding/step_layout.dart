import 'package:flutter/material.dart';

import '../../../../shared/presentation/app_theme.dart';

class OnboardingStep extends StatelessWidget {
  const OnboardingStep({super.key, required this.children, required this.actions});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          const SizedBox(height: 16),
          ...actions,
        ],
      ),
    );
  }
}

class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.tanDark,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.tanDark.withValues(alpha: 0.4),
        disabledForegroundColor: AppColors.white,
        textStyle: AppText.button.copyWith(fontSize: 18),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.white),
            )
          : Text(label),
    );
  }
}

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.child, this.color = AppColors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
