import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/message_models.dart';
import '../chat_list_controller.dart';
import 'chat_avatar.dart';

/// Picks the chats to forward [message] into. Returns the chosen chat ids.
Future<List<int>?> showForwardSheet(BuildContext context, {required Message message}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => ForwardSheet(message: message),
  );
}

/// Multi-select over the existing chat list.
///
/// Forwarding needs membership in both the source and the target chat, so only
/// chats we are already in are offered.
class ForwardSheet extends ConsumerStatefulWidget {
  const ForwardSheet({super.key, required this.message});

  final Message message;

  @override
  ConsumerState<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<ForwardSheet> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chats = ref.watch(chatListProvider).valueOrNull?.chats ?? const [];
    final preview = widget.message.text?.trim();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Text(
                  'Uzatish',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.accentBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shortcut_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Uzatilayotgan xabar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  preview == null || preview.isEmpty ? 'Biriktirma' : preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          Expanded(
            child: chats.isEmpty
                ? const EmptyView(
                    icon: Icons.forum_outlined,
                    title: 'Uzatadigan suhbat yo\'q',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: chats.length,
                    itemBuilder: (_, index) {
                      final chat = chats[index];
                      final checked = _selected.contains(chat.id);
                      return InkWell(
                        onTap: () => setState(() {
                          checked ? _selected.remove(chat.id) : _selected.add(chat.id);
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          child: Row(
                            children: [
                              ChatAvatar(
                                name: chat.title,
                                imageUrl: chat.avatar,
                                kind: chat.kind,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  chat.title.trim().isEmpty ? 'Suhbat' : chat.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                              _CheckBox(checked: checked),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: c.bgCard,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Suhbat tanlang'
                          : '${_selected.length} ta suhbat tanlandi',
                      style: TextStyle(fontSize: 13.5, color: c.textSecondary),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selected.toList()),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Uzatish'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round check box matching the design.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? AppColors.brand : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: checked ? AppColors.brand : c.border, width: 2),
      ),
      child: checked ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
    );
  }
}
