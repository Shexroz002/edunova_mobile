import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand.dart';
import '../../domain/chat_models.dart';

/// Avatar for a chat row or header, with an optional presence dot.
///
/// A group shows the indigo people tile; a private chat shows the peer's
/// avatar. [online] `null` hides the dot entirely (groups, pickers).
///
/// The dot keeps a 2.5 dp ring in the card colour so it stays readable even
/// when [UserAvatar] happens to pick a green tint for the initials.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.kind = ChatKind.private,
    this.size = 48,
    this.online,
  });

  final String name;
  final String? imageUrl;
  final ChatKind kind;
  final double size;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avatar = kind.isGroup
        ? _GroupTile(size: size)
        : UserAvatar(name: name, imageUrl: imageUrl, size: size);

    if (online == null) return avatar;

    final dot = (size * 0.26).clamp(10.0, 16.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: online! ? AppColors.success : c.textMuted,
                shape: BoxShape.circle,
                border: Border.all(color: c.bgCard, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indigo gradient tile standing in for a group's picture.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet, AppColors.brand],
        ),
      ),
      child: Icon(Icons.groups_rounded, size: size * 0.52, color: Colors.white),
    );
  }
}
