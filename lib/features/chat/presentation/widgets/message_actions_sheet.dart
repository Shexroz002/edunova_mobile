import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/message_models.dart';

/// What the user picked in the long-press sheet.
enum MessageAction { reply, edit, copy, forward, delete }

/// Either an action or a reaction emoji.
class MessageActionResult {
  const MessageActionResult.action(this.action) : emoji = null;

  const MessageActionResult.reaction(this.emoji) : action = null;

  final MessageAction? action;
  final String? emoji;
}

/// The six reactions offered up front; any other emoji still renders fine.
const _quickReactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

/// Long-press menu for one message.
///
/// Editing and deleting are only offered on our own messages — the server
/// rejects anything else with a `403`, so showing them would be a lie.
Future<MessageActionResult?> showMessageActions(
  BuildContext context, {
  required Message message,
  required bool isOwn,
  required int currentUserId,
}) {
  return showModalBottomSheet<MessageActionResult>(
    context: context,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (sheetContext) => _MessageActionsSheet(
      message: message,
      isOwn: isOwn,
      currentUserId: currentUserId,
    ),
  );
}

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({
    required this.message,
    required this.isOwn,
    required this.currentUserId,
  });

  final Message message;
  final bool isOwn;
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReactionBar(
              message: message,
              currentUserId: currentUserId,
              onPick: (emoji) => Navigator.of(context).pop(MessageActionResult.reaction(emoji)),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: c.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
                boxShadow: c.cardShadow,
              ),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.reply_rounded,
                    label: 'Javob berish',
                    onTap: () => Navigator.of(context)
                        .pop(const MessageActionResult.action(MessageAction.reply)),
                  ),
                  if (isOwn && message.hasText)
                    _ActionRow(
                      icon: Icons.edit_rounded,
                      label: 'Tahrirlash',
                      onTap: () => Navigator.of(context)
                          .pop(const MessageActionResult.action(MessageAction.edit)),
                    ),
                  if (message.hasText)
                    _ActionRow(
                      icon: Icons.copy_rounded,
                      label: 'Nusxa olish',
                      onTap: () => Navigator.of(context)
                          .pop(const MessageActionResult.action(MessageAction.copy)),
                    ),
                  _ActionRow(
                    icon: Icons.shortcut_rounded,
                    label: 'Uzatish',
                    onTap: () => Navigator.of(context)
                        .pop(const MessageActionResult.action(MessageAction.forward)),
                  ),
                  if (isOwn)
                    _ActionRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'O\'chirish',
                      color: AppColors.error,
                      last: true,
                      onTap: () => Navigator.of(context)
                          .pop(const MessageActionResult.action(MessageAction.delete)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of quick reactions; the one we already gave is highlighted.
class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.message,
    required this.currentUserId,
    required this.onPick,
  });

  final Message message;
  final int currentUserId;
  final void Function(String emoji) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final emoji in _quickReactions)
            GestureDetector(
              onTap: () => onPick(emoji),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _reactedWith(emoji) ? c.accentMuted : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 23)),
              ),
            ),
        ],
      ),
    );
  }

  bool _reactedWith(String emoji) =>
      message.reactions.any((r) => r.emoji == emoji && r.reactedBy(currentUserId));
}

/// One row of the action list.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tint),
            ),
          ],
        ),
      ),
    );
  }
}
