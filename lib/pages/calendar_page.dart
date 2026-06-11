import 'package:flutter/material.dart';
import '../models/models.dart';
import '../helpers/helpers.dart';

class CalendarPage extends StatefulWidget {
  final List<ActivityEntry> entries;
  final AppSettings settings;
  final ValueChanged<ActivityEntry> onEdit;
  final VoidCallback onAddActivity;

  const CalendarPage({
    super.key,
    required this.entries,
    required this.settings,
    required this.onEdit,
    required this.onAddActivity,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _displayMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Map<DateTime, List<ActivityEntry>> get _entriesByDate {
    final map = <DateTime, List<ActivityEntry>>{};
    for (final entry in widget.entries) {
      final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
      map.putIfAbsent(key, () => []).add(entry);
    }
    return map;
  }

  List<ActivityEntry> get _selectedEntries {
    if (_selectedDate == null) return [];
    final key = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    return _entriesByDate[key] ?? [];
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
      _selectedDate = null;
    });
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _displayMonth = DateTime(now.year, now.month);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entriesByDate = _entriesByDate;

    // Build calendar grid
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    final totalDays = lastDay.day;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender Kegiatan'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('Hari Ini'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // Month selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${monthName(_displayMonth.month)} ${_displayMonth.year}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),

              // Day headers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),

              // Calendar grid
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: 42, // 6 rows * 7 days
                    itemBuilder: (context, index) {
                      final dayNumber = index - startWeekday + 2;
                      if (dayNumber < 1 || dayNumber > totalDays) {
                        return const SizedBox.shrink();
                      }

                      final date = DateTime(_displayMonth.year, _displayMonth.month, dayNumber);
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      final isSelected = _selectedDate != null &&
                          date.year == _selectedDate!.year &&
                          date.month == _selectedDate!.month &&
                          date.day == _selectedDate!.day;
                      final dayEntries = entriesByDate[date] ?? [];
                      final hasEntries = dayEntries.isNotEmpty;
                      final totalHours =
                          dayEntries.fold<double>(0, (s, e) => s + e.durationHours);

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = date);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.2)
                                : isToday
                                    ? theme.colorScheme.primary.withOpacity(0.08)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: theme.colorScheme.primary.withOpacity(0.5),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  fontWeight:
                                      isToday || isSelected ? FontWeight.w900 : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : isToday
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              if (hasEntries) ...[
                                const SizedBox(height: 2),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '${totalHours.toStringAsFixed(0)}h',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Selected day entries
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _selectedDate == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 40,
                                color: theme.colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pilih tanggal untuk melihat aktivitas',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  formatDate(_selectedDate!, includeWeekday: true),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_selectedEntries.length} kegiatan',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedEntries.isEmpty)
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Tidak ada aktivitas',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonalIcon(
                                        onPressed: widget.onAddActivity,
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Tambah aktivitas'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _selectedEntries.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, idx) {
                                    final entry = _selectedEntries[idx];
                                    return _CalendarEntryTile(
                                      entry: entry,
                                      is24Hour: widget.settings.use24HourFormat,
                                      onTap: () => widget.onEdit(entry),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEntryTile extends StatelessWidget {
  final ActivityEntry entry;
  final bool is24Hour;
  final VoidCallback onTap;

  const _CalendarEntryTile({
    required this.entry,
    required this.is24Hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: entry.category.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: entry.category.color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(entry.category.icon, size: 18, color: entry.category.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.activity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${formatMinutes(entry.startMinutes, is24Hour: is24Hour)} - ${formatMinutes(entry.endMinutes, is24Hour: is24Hour)} (${formatHours(entry.durationHours)})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (entry.imagePaths.isNotEmpty)
              Icon(Icons.photo_rounded,
                  size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}
