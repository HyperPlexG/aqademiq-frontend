import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';

/// Filled form field (v11 input): `bg` fill, radius 14, 1.5px border, accent
/// border on focus, 17 text. Reused across auth, onboarding, subjects, settings.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.autofocus = false,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.rowInput),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      // A password reads as the design's bold, spaced dots.
      style: obscureText
          ? AppText.sans(size: 17, weight: FontWeight.w700, letterSpacing: 3, color: colors.text)
          : AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.bg,
        hintText: hint,
        hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        enabledBorder: border(colors.border),
        focusedBorder: border(colors.accent),
        border: border(colors.border),
      ),
    );
  }
}

/// The small uppercase field label above an [AppTextField] (v11 `SLabel`:
/// 12/800, 0.12em, dim).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text.toUpperCase(),
        style: AppText.sans(
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: AppText.em(0.12, 12),
          color: context.colors.textDim,
        ),
      ),
    );
  }
}
