import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../helpers/animations.dart';
import '../helpers/helpers.dart';
import '../models/models.dart';

enum EntryAction { edit, delete }

class ActivityEntryCard extends StatelessWidget {
  const ActivityEntryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    this.is24Hour = true,
    this.isMultiSelecting = false,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
  });

  final ActivityEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool is24Hour;
  final bool isMultiSelecting;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: PressableCard(
      onTap: onTap != null ? null : onEdit,
      borderRadius: 20,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : (theme.cardTheme.shape is RoundedRectangleBorder
                ? Border.fromBorderSide((theme.cardTheme.shape as RoundedRectangleBorder).side)
                : null),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMultiSelecting) ...[                    
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 10, top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(entry.category.icon, size: 16, color: entry.category.color),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(entry.category.label),
                                backgroundColor: entry.category.color.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: entry.category.color,
                                  fontSize: 11,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Badge(
                                icon: Icons.schedule_rounded,
                                label: '${formatMinutes(entry.startMinutes, is24Hour: is24Hour)} - ${formatMinutes(entry.endMinutes, is24Hour: is24Hour)}',
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatHours(entry.durationHours),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            entry.activity,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          // Tags
                          if (entry.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              children: [
                                for (final tag in entry.tags)
                                  Chip(
                                    label: Text(tag),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    labelStyle: const TextStyle(fontSize: 10),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<EntryAction>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 120),
                      onSelected: (action) {
                        if (action == EntryAction.edit) onEdit();
                        if (action == EntryAction.delete) onDelete();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: EntryAction.edit,
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: EntryAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Hapus', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // ── Photo thumbnails ─────────────────────────────────────────
                if (entry.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.imagePaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final path = entry.imagePaths[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(path, width: 72, height: 72, fit: BoxFit.cover)
                              : Image.file(File(path), width: 72, height: 72, fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> buildGroupedEntryWidgets(
  BuildContext context,
  List<ActivityEntry> entries, {
  required ValueChanged<ActivityEntry> onEdit,
  required ValueChanged<ActivityEntry> onDelete,
  bool is24Hour = true,
  bool isMultiSelecting = false,
  Set<String> selectedIds = const {},
  ValueChanged<ActivityEntry>? onLongPress,
  ValueChanged<ActivityEntry>? onTap,
}) {
  final widgets = <Widget>[];
  DateTime? currentDate;

  for (final entry in entries) {
    if (currentDate == null || !isSameDay(currentDate, entry.date)) {
      currentDate = dateOnly(entry.date);
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
      }
      // Group headers use a very short fixed delay to feel crisp
      widgets.add(
        FadeSlideIn(
          delay: const Duration(milliseconds: 50),
          offset: const Offset(0, 10),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  formatDate(entry.date, includeWeekday: true),
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // List items use no delay or extremely short delay for scroll performance
    widgets.add(
      FadeSlideIn(
        duration: const Duration(milliseconds: 300),
        offset: const Offset(0, 8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ActivityEntryCard(
            entry: entry,
            is24Hour: is24Hour,
            isMultiSelecting: isMultiSelecting,
            isSelected: selectedIds.contains(entry.id),
            onLongPress: onLongPress != null ? () => onLongPress(entry) : null,
            onTap: onTap != null ? () => onTap(entry) : null,
            onEdit: () => onEdit(entry),
            onDelete: () => onDelete(entry),
          ),
        ),
      ),
    );
  }

  return widgets;
}

