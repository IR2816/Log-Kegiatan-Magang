import '../models/models.dart';
import '../helpers/helpers.dart';

class GamificationService {
  /// Calculate current streak (consecutive days with at least one entry)
  static int calculateStreak(List<ActivityEntry> entries) {
    if (entries.isEmpty) return 0;

    final daysWithEntries = <DateTime>{};
    for (final entry in entries) {
      daysWithEntries.add(dateOnly(entry.date));
    }

    int streak = 0;
    DateTime current = dateOnly(DateTime.now());

    while (daysWithEntries.contains(current)) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    }

    // If today doesn't have entries, check from yesterday
    if (streak == 0) {
      current = dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      while (daysWithEntries.contains(current)) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      }
    }

    return streak;
  }

  /// Calculate longest streak ever
  static int calculateLongestStreak(List<ActivityEntry> entries) {
    if (entries.isEmpty) return 0;

    final daysWithEntries = <DateTime>{};
    for (final entry in entries) {
      daysWithEntries.add(dateOnly(entry.date));
    }

    final sortedDays = daysWithEntries.toList()..sort();
    int longest = 1;
    int current = 1;

    for (int i = 1; i < sortedDays.length; i++) {
      if (sortedDays[i].difference(sortedDays[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
  }

  /// Get all available badge definitions
  static List<Map<String, dynamic>> getBadgeDefinitions() {
    return [
      {'id': 'first_entry', 'title': 'Langkah Pertama', 'desc': 'Buat catatan aktivitas pertama', 'icon': '🌟', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.isNotEmpty},
      {'id': 'ten_entries', 'title': 'Rajin Mencatat', 'desc': 'Buat 10 catatan aktivitas', 'icon': '📝', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.length >= 10},
      {'id': 'fifty_entries', 'title': 'Konsisten', 'desc': 'Buat 50 catatan aktivitas', 'icon': '🏆', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.length >= 50},
      {'id': 'hundred_entries', 'title': 'Legenda', 'desc': 'Buat 100 catatan aktivitas', 'icon': '👑', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.length >= 100},
      {'id': 'streak_3', 'title': 'Tiga Hari Berturut', 'desc': 'Streak 3 hari berturut-turut', 'icon': '🔥', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => calculateLongestStreak(e) >= 3},
      {'id': 'streak_7', 'title': 'Seminggu Penuh', 'desc': 'Streak 7 hari berturut-turut', 'icon': '⚡', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => calculateLongestStreak(e) >= 7},
      {'id': 'streak_30', 'title': 'Sebulan Konsisten', 'desc': 'Streak 30 hari berturut-turut', 'icon': '💎', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => calculateLongestStreak(e) >= 30},
      {'id': 'hours_50', 'title': '50 Jam Kerja', 'desc': 'Total 50 jam kerja tercatat', 'icon': '⏰', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.fold<double>(0, (s, e) => s + e.durationHours) >= 50},
      {'id': 'hours_100', 'title': '100 Jam Kerja', 'desc': 'Total 100 jam kerja tercatat', 'icon': '🎯', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.fold<double>(0, (s, e) => s + e.durationHours) >= 100},
      {'id': 'hours_500', 'title': '500 Jam Magang', 'desc': 'Total 500 jam kerja tercatat', 'icon': '🎓', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.fold<double>(0, (s, e) => s + e.durationHours) >= 500},
      {'id': 'first_reflection', 'title': 'Refleksi Pertama', 'desc': 'Buat refleksi harian pertama', 'icon': '💭', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => r.isNotEmpty},
      {'id': 'ten_reflections', 'title': 'Pemikir Dalam', 'desc': 'Buat 10 refleksi harian', 'icon': '🧠', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => r.length >= 10},
      {'id': 'all_categories', 'title': 'Serba Bisa', 'desc': 'Gunakan semua kategori aktivitas', 'icon': '🌈', 'check': (List<ActivityEntry> e, List<DailyReflection> r) => e.map((e) => e.category).toSet().length >= ActivityCategory.values.length},
    ];
  }

  /// Check for newly unlocked badges and return them
  static List<AppBadge> checkNewBadges(
    List<ActivityEntry> entries,
    List<DailyReflection> reflections,
    List<AppBadge> existingBadges,
  ) {
    final existingIds = existingBadges.map((b) => b.id).toSet();
    final definitions = getBadgeDefinitions();
    final newBadges = <AppBadge>[];

    for (final def in definitions) {
      final id = def['id'] as String;
      if (existingIds.contains(id)) continue;

      final check = def['check'] as bool Function(List<ActivityEntry>, List<DailyReflection>);
      if (check(entries, reflections)) {
        newBadges.add(AppBadge(
          id: id,
          title: def['title'] as String,
          description: def['desc'] as String,
          icon: def['icon'] as String,
          unlockedAt: DateTime.now(),
        ));
      }
    }

    return newBadges;
  }

  /// Get total hours
  static double getTotalHours(List<ActivityEntry> entries) {
    return entries.fold<double>(0, (sum, e) => sum + e.durationHours);
  }
}
