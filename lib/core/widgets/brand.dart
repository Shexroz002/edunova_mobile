import 'package:flutter/material.dart';

import '../network/media_url.dart';
import '../theme/app_colors.dart';
import 'brand_mark_painter.dart';

/// Gradient logo tile carrying the EduNova mark.
///
/// The web shows a lightning bolt here; the app has its own drawn mark (an open
/// book under a nova spark), which is also the launcher icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.17),
        child: CustomPaint(
          painter: const BrandMarkPainter(color: Colors.white),
          size: Size.square(size * 0.66),
        ),
      ),
    );
  }
}

/// Logo tile + "EduNova" word mark.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        SizedBox(width: size * 0.3),
        Text(
          'EduNova',
          style: TextStyle(
            fontSize: size * 0.56,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Round avatar: network image when available, otherwise colored initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  static const _palette = [
    Color(0xFF6366F1),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    final url = MediaUrl.resolve(imageUrl);

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.tint(color, 0x33), shape: BoxShape.circle),
      child: Text(
        _initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );

    if (url == null) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
