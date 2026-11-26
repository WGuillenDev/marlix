import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/app_theme.dart';

class CredentialField extends StatelessWidget {
  const CredentialField({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.helper,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    // Merged so screen readers announce the label with the field.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: !obscureText,
            style: AppText.body.copyWith(fontSize: 17),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
              helperText: error == null ? helper : null,
              helperMaxLines: 2,
              errorText: error,
              errorMaxLines: 3,
              errorStyle: AppText.bodyStrong.copyWith(fontSize: 14, color: AppColors.crisis),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              suffixIcon: suffix,
              enabledBorder: border(AppColors.line),
              focusedBorder: border(AppColors.tanDark),
              errorBorder: border(AppColors.crisis, 2),
              focusedErrorBorder: border(AppColors.crisis, 2),
            ),
          ),
        ],
      ),
    );
  }
}
