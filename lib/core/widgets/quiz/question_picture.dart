import 'package:flutter/material.dart';

/// One picture attached to a question, tappable to open zoomed.
///
/// A picture that fails to load is dropped rather than shown broken: it is
/// supporting material, and an error box in its place only gets in the way.
class QuestionPicture extends StatelessWidget {
  const QuestionPicture({super.key, required this.url});

  final String url;

  void _openZoom(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(maxScale: 5, child: Image.network(url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openZoom(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }
}
