import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Labeled text input matching the web form style (label above, 48px field).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.isPassword = false,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final bool isPassword;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// More than one turns the field into a textarea.
  final int maxLines;
  final int? maxLength;

  /// Shapes the text as it is typed, e.g. to keep a username lowercase.
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    OutlineInputBorder border(Color color, [double width = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          autofocus: widget.autofocus,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          autocorrect: !widget.isPassword,
          enableSuggestions: !widget.isPassword,
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          cursorColor: AppColors.brand,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.bgInner,
            hintText: widget.hint,
            hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
            errorText: widget.errorText,
            errorMaxLines: 2,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            // A multi-line field would centre the icon vertically, so it sits
            // at the top instead.
            prefixIcon: widget.icon == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(bottom: widget.maxLines > 1 ? 44 : 0),
                    child: Icon(widget.icon, size: 18, color: c.textMuted),
                  ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscure ? "Parolni ko'rsatish" : 'Parolni yashirish',
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: c.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            border: border(c.border),
            enabledBorder: border(c.border),
            disabledBorder: border(c.border),
            focusedBorder: border(AppColors.brand),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error),
          ),
        ),
      ],
    );
  }
}
