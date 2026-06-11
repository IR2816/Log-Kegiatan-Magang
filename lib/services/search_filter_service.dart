import '../models/models.dart';

class SearchFilterService {
  /// Cari entry berdasarkan keyword dalam activity description
  static List<ActivityEntry> searchByKeyword(
    List<ActivityEntry> entries,
    String keyword,
  ) {
    if (keyword.trim().isEmpty) return entries;
    
    final lowerKeyword = keyword.toLowerCase();
    return entries
        .where((entry) => entry.activity.toLowerCase().contains(lowerKeyword))
        .toList();
  }

  /// Filter entry berdasarkan date range
  static List<ActivityEntry> filterByDateRange(
    List<ActivityEntry> entries,
    DateTime startDate,
    DateTime endDate,
  ) {
    return entries
        .where((entry) =>
            entry.date.isAfter(startDate) && entry.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();
  }

  /// Filter entry berdasarkan kategori
  static List<ActivityEntry> filterByCategory(
    List<ActivityEntry> entries,
    ActivityCategory category,
  ) {
    return entries.where((entry) => entry.category == category).toList();
  }

  /// Filter entry berdasarkan multiple categories
  static List<ActivityEntry> filterByCategories(
    List<ActivityEntry> entries,
    List<ActivityCategory> categories,
  ) {
    if (categories.isEmpty) return entries;
    return entries
        .where((entry) => categories.contains(entry.category))
        .toList();
  }

  /// Filter entry berdasarkan tag
  static List<ActivityEntry> filterByTag(
    List<ActivityEntry> entries,
    String tag,
  ) {
    return entries
        .where((entry) => entry.tags.contains(tag.toLowerCase()))
        .toList();
  }

  /// Filter entry berdasarkan duration minimal
  static List<ActivityEntry> filterByMinDuration(
    List<ActivityEntry> entries,
    double minHours,
  ) {
    return entries
        .where((entry) => entry.durationHours >= minHours)
        .toList();
  }

  /// Kombinasi filter: keyword + date range + categories + min duration
  static List<ActivityEntry> advancedSearch(
    List<ActivityEntry> entries, {
    String keyword = '',
    DateTime? startDate,
    DateTime? endDate,
    List<ActivityCategory> categories = const [],
    double minDuration = 0.0,
  }) {
    List<ActivityEntry> result = entries;

    if (keyword.isNotEmpty) {
      result = searchByKeyword(result, keyword);
    }

    if (startDate != null && endDate != null) {
      result = filterByDateRange(result, startDate, endDate);
    }

    if (categories.isNotEmpty) {
      result = filterByCategories(result, categories);
    }

    if (minDuration > 0) {
      result = filterByMinDuration(result, minDuration);
    }

    return result;
  }

  /// Hitung statistik entries
  static Map<String, dynamic> calculateStats(List<ActivityEntry> entries) {
    if (entries.isEmpty) {
      return <String, dynamic>{
        'totalEntries': 0,
        'totalHours': 0.0,
        'averageHoursPerDay': 0.0,
        'averageHoursPerEntry': 0.0,
        'categoryStats': <String, double>{},
        'longestDay': 0.0,
      };
    }

    double totalHours = 0;
    final Map<ActivityCategory, double> categoryHours = {};
    final Map<DateTime, double> dailyHours = {};

    for (final entry in entries) {
      totalHours += entry.durationHours;
      
      final category = entry.category;
      categoryHours[category] = (categoryHours[category] ?? 0) + entry.durationHours;

      final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
      dailyHours[dateKey] = (dailyHours[dateKey] ?? 0) + entry.durationHours;
    }

    final uniqueDays = dailyHours.keys.length;
    final longestDay = dailyHours.values.isEmpty ? 0.0 : dailyHours.values.reduce((a, b) => a > b ? a : b);

    // Build categoryStats as explicit Map<String, double> to avoid LinkedMap on web
    final Map<String, double> catStats = {};
    categoryHours.forEach((category, hours) {
      catStats[category.label] = hours;
    });

    return <String, dynamic>{
      'totalEntries': entries.length,
      'totalHours': totalHours,
      'averageHoursPerDay': uniqueDays > 0 ? totalHours / uniqueDays : 0.0,
      'averageHoursPerEntry': totalHours / entries.length,
      'categoryStats': catStats,
      'longestDay': longestDay,
      'uniqueDays': uniqueDays,
    };
  }

  /// Hitung statistik per minggu
  static Map<String, dynamic> getWeeklyStats(
    List<ActivityEntry> entries,
    DateTime week,
  ) {
    final startOfWeek = week.subtract(Duration(days: week.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final weekEntries = filterByDateRange(entries, startOfWeek, endOfWeek);
    final stats = calculateStats(weekEntries);

    return {
      ...stats,
      'weekStart': startOfWeek,
      'weekEnd': endOfWeek,
    };
  }

  /// Hitung statistik per bulan
  static Map<String, dynamic> getMonthlyStats(
    List<ActivityEntry> entries,
    int year,
    int month,
  ) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = month == 12
        ? DateTime(year + 1, 1, 0)
        : DateTime(year, month + 1, 0);

    final monthEntries = filterByDateRange(entries, startOfMonth, endOfMonth);
    final stats = calculateStats(monthEntries);

    return {
      ...stats,
      'monthStart': startOfMonth,
      'monthEnd': endOfMonth,
      'month': month,
      'year': year,
    };
  }

  /// Dapatkan semua tag unik dari entries
  static List<String> getAllTags(List<ActivityEntry> entries) {
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags);
    }
    return tags.toList()..sort();
  }

  /// Dapatkan heatmap data untuk visualisasi (hours per day of week)
  static Map<String, double> getHeatmapData(List<ActivityEntry> entries) {
    const daysOfWeek = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final heatmap = <String, double>{};

    for (final day in daysOfWeek) {
      heatmap[day] = 0.0;
    }

    for (final entry in entries) {
      final dayIndex = entry.date.weekday - 1; // Monday = 1, Sunday = 7
      final dayName = daysOfWeek[dayIndex];
      heatmap[dayName] = (heatmap[dayName] ?? 0) + entry.durationHours;
    }

    return heatmap;
  }
}
