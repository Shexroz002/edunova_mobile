import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded search input with a clear button and debounced [onChanged].
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Qidirish...',
    this.initialValue = '',
    this.debounce = const Duration(milliseconds: 300),
  });

  /// Called with the trimmed query after the user stops typing for [debounce].
  final ValueChanged<String> onChanged;
  final String hint;
  final String initialValue;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {}); // toggles the clear button
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
  }

  void _clear() {
    _controller.clear();
    _timer?.cancel();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c.border),
    );

    return TextField(
      controller: _controller,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 14, color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.bgCard,
        hintText: widget.hint,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.textMuted),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Tozalash',
                icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
                onPressed: _clear,
              ),
        border: border,
        enabledBorder: border,
        focusedBorder:
            border.copyWith(borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
      ),
    );
  }
}
