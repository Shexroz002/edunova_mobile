import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../data/groups_repository.dart';
import '../domain/group_models.dart';

/// How the group list is ordered.
enum _GroupSort {
  name("Nom bo'yicha"),
  subject("Fan bo'yicha"),
  activity("Faollik bo'yicha");

  const _GroupSort(this.label);

  final String label;
}

/// Groups the student belongs to, laid out like the web `StudentGroupsPage.tsx`:
/// a heading, a controls card (search + sort) and the group cards.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _search = '';
  _GroupSort _sort = _GroupSort.name;

  List<StudentGroup> _sorted(List<StudentGroup> groups) {
    final list = [...groups];
    switch (_sort) {
      case _GroupSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _GroupSort.subject:
        list.sort((a, b) => (a.subject ?? '').compareTo(b.subject ?? ''));
      case _GroupSort.activity:
        list.sort((a, b) {
          final x = a.lastActivity, y = b.lastActivity;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repository = ref.watch(groupsRepositoryProvider);

    return Scaffold(
      // The page already carries "Mening guruhlarim" as its own heading, so
      // the bar keeps the short tab name at every size.
      appBar: const PageAppBar(title: Text('Guruhlar')),
      body: ContentConstraint(
        maxWidth: 860,
        child: PagedListView<StudentGroup>(
          reloadKey: '$_search|${_sort.name}',
          // The web puts group cards side by side from its tablet width up.
          columns: context.isTablet ? 2 : 1,
          padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 28),
          fetchPage: (page) => repository.fetchGroups(search: _search, page: page),
          transform: _sorted,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mening guruhlarim',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                "Siz a'zo bo'lgan barcha guruhlar",
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: context.isTablet
                    ? Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SearchField(
                              hint: "Guruhlar bo'yicha qidirish...",
                              initialValue: _search,
                              onChanged: (value) => setState(() => _search = value),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SortDropdown(
                              value: _sort,
                              onChanged: (value) => setState(() => _sort = value),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          SearchField(
                            hint: "Guruhlar bo'yicha qidirish...",
                            initialValue: _search,
                            onChanged: (value) => setState(() => _search = value),
                          ),
                          const SizedBox(height: 10),
                          _SortDropdown(
                            value: _sort,
                            onChanged: (value) => setState(() => _sort = value),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
            ],
          ),
          empty: EmptyView(
            icon: Icons.school_outlined,
            title: _search.isEmpty ? "Siz hech qaysi guruhda yo'qsiz" : 'Guruh topilmadi',
            subtitle: _search.isEmpty
                ? "O'qituvchingiz sizni guruhga qo'shgach shu yerda ko'rinadi"
                : "Boshqa so'z bilan qidirib ko'ring",
          ),
          itemBuilder: (context, group) => GroupCard(
            group: group,
            onOpen: () => context.push('/groups/${group.id}'),
          ),
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final _GroupSort value;
  final ValueChanged<_GroupSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.sort_rounded, size: 18, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_GroupSort>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                dropdownColor: c.bgCard,
                icon: Icon(Icons.expand_more_rounded, color: c.textSecondary),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                items: [
                  for (final sort in _GroupSort.values)
                    DropdownMenuItem(value: sort, child: Text(sort.label)),
                ],
                onChanged: (selected) => selected == null ? null : onChanged(selected),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Group card: coloured tile, name, subject, description, three stats and the
/// last-activity footer.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, required this.onOpen});

  final StudentGroup group;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = group.color.color;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.tint(accent, 0x24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.school_rounded, size: 24, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (group.subject != null) ...[
                              Icon(Icons.menu_book_rounded, size: 14, color: accent),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  group.subject!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _StatusDot(status: group.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (group.description != null && group.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  group.description!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GroupStat(label: "O'quvchilar", value: '${group.studentsCount}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _GroupStat(label: 'Testlar', value: '${group.testsCount}')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GroupStat(
                      label: "O'rtacha",
                      value: formatPercent(group.averageScore),
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      group.lastActivity == null
                          ? 'Faollik yo‘q'
                          : formatRelative(group.lastActivity!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ),
                  Text(
                    'Batafsil',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final GroupStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tint(status.color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color),
          ),
        ],
      ),
    );
  }
}

class _GroupStat extends StatelessWidget {
  const _GroupStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
