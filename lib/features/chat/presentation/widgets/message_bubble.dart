import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/message_models.dart';
import '../chat_time.dart';
import 'attachment_view.dart';
import 'chat_avatar.dart';

const _maxBubbleWidth = 280.0;

/// One message row: optional avatar, the bubble, and its reaction pills.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.outgoing,
    required this.currentUserId,
    this.senderName,
    this.senderImage,
    this.showAvatar = false,
    this.tail = true,
    this.onLongPress,
    this.onReactionTap,
    this.onReplyTap,
  });

  final Message message;

  /// Sent by this device's user.
  final bool outgoing;
  final int currentUserId;

  /// Shown above the bubble in groups.
  final String? senderName;
  final String? senderImage;
  final bool showAvatar;

  /// First bubble of a run gets the pointed corner.
  final bool tail;

  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    if (message.deleted) return _DeletedBubble(outgoing: outgoing, message: message);

    final c = context.colors;
    final align = outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
        padding: _padding,
        decoration: BoxDecoration(
          color: outgoing ? AppColors.brandDark : c.bgCard,
          borderRadius: _radius,
          border: Border.all(color: outgoing ? Colors.transparent : c.border),
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.forwardedFrom != null) _ForwardedHeader(from: message.forwardedFrom!, outgoing: outgoing),
            if (senderName != null && !outgoing) _SenderLabel(name: senderName!),
            if (message.replyPreview != null)
              _ReplyQuote(
                preview: message.replyPreview!,
                outgoing: outgoing,
                currentUserId: currentUserId,
                onTap: onReplyTap,
              ),
            for (final attachment in message.attachments)
              Padding(
                padding: EdgeInsets.only(bottom: message.hasText ? 6 : 0),
                child: AttachmentView(attachment: attachment, outgoing: outgoing),
              ),
            if (message.hasText)
              Text(
                message.text!,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.42,
                  color: outgoing ? Colors.white : c.textPrimary,
                ),
              ),
            _Meta(message: message, outgoing: outgoing),
          ],
        ),
      ),
    );

    final column = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        if (message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: _Reactions(
              reactions: message.reactions,
              currentUserId: currentUserId,
              onTap: onReactionTap,
            ),
          ),
      ],
    );

    if (!outgoing && showAvatar) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChatAvatar(name: senderName ?? '?', imageUrl: senderImage, size: 30),
          const SizedBox(width: 8),
          Flexible(child: column),
        ],
      );
    }

    return Row(
      mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!outgoing && !showAvatar) const SizedBox(width: 38),
        Flexible(child: column),
      ],
    );
  }

  EdgeInsets get _padding => message.attachments.isEmpty
      ? const EdgeInsets.fromLTRB(12, 9, 12, 7)
      : const EdgeInsets.all(5);

  BorderRadius get _radius => BorderRadius.only(
        topLeft: Radius.circular(!outgoing && tail ? 4 : 16),
        topRight: Radius.circular(outgoing && tail ? 4 : 16),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      );
}

/// `Uzatilgan: <kim>` strip.
class _ForwardedHeader extends StatelessWidget {
  const _ForwardedHeader({required this.from, required this.outgoing});

  final ForwardedFrom from;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = outgoing ? Colors.white : c.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shortcut_rounded, size: 14, color: accent),
          const SizedBox(width: 5),
          Text(
            'Uzatilgan: ',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
          ),
          Flexible(
            child: Text(
              from.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: outgoing ? const Color(0xB3FFFFFF) : c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sender name above the first bubble of a run in a group chat.
class _SenderLabel extends StatelessWidget {
  const _SenderLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: context.colors.accent,
        ),
      ),
    );
  }
}

/// The quoted message a reply points at.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.preview,
    required this.outgoing,
    required this.currentUserId,
    this.onTap,
  });

  final ReplyPreview preview;
  final bool outgoing;
  final int currentUserId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = outgoing ? Colors.white : c.accent;
    final label = preview.senderId == currentUserId ? 'Siz' : 'Javob';
    final text = preview.text.trim().isEmpty ? 'Biriktirma' : preview.text;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: outgoing ? const Color(0x2E000000) : c.bgInner,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: outgoing ? Colors.white : c.accent,
                      ),
                    ),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: outgoing ? const Color(0xB3FFFFFF) : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Time, the edited marker and delivery ticks.
class _Meta extends StatelessWidget {
  const _Meta({required this.message, required this.outgoing});

  final Message message;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = outgoing ? const Color(0x9EFFFFFF) : c.textMuted;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (message.edited) ...[
            Text('tahrirlangan', style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(width: 4),
            Text('·', style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(width: 4),
          ],
          Text(formatMessageClock(message.createdAt), style: TextStyle(fontSize: 11, color: color)),
          if (outgoing) ...[
            const SizedBox(width: 4),
            _Ticks(state: message.deliveryState, onBrand: true),
          ],
        ],
      ),
    );
  }
}

/// Clock (queued) → single check (stored) → double check (read).
class _Ticks extends StatelessWidget {
  const _Ticks({required this.state, this.onBrand = false});

  final DeliveryState? state;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (state) {
      DeliveryState.pending =>
        Icon(Icons.schedule_rounded, size: 13, color: onBrand ? const Color(0x9EFFFFFF) : c.textMuted),
      DeliveryState.failed => const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFFECACA)),
      DeliveryState.sent =>
        Icon(Icons.done_rounded, size: 15, color: onBrand ? const Color(0x9EFFFFFF) : c.textMuted),
      DeliveryState.read => const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFFA5F3FC)),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Reaction pills under a bubble.
class _Reactions extends StatelessWidget {
  const _Reactions({required this.reactions, required this.currentUserId, this.onTap});

  final List<MessageReaction> reactions;
  final int currentUserId;
  final void Function(String emoji)? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final reaction in reactions)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(reaction.emoji),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: reaction.reactedBy(currentUserId) ? c.accentMuted : c.bgInner,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: reaction.reactedBy(currentUserId) ? c.accent : c.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reaction.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '${reaction.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A soft-deleted message keeps its slot so the thread does not jump.
class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({required this.outgoing, required this.message});

  final bool outgoing;
  final Message message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!outgoing) const SizedBox(width: 38),
        Container(
          constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, style: BorderStyle.solid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 14, color: c.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Xabar o\'chirildi',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                formatMessageClock(message.createdAt),
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
