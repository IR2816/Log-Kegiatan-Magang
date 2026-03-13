import 'package:flutter/material.dart';
import 'models.dart';

int compareActivities(ActivityEntry left, ActivityEntry right) {
  final dateCompare = right.date.compareTo(left.date);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return right.startMinutes.compareTo(left.startMinutes);
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String weekdayName(DateTime date) {
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  return days[date.weekday - 1];
}

String monthName(int month) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return months[month - 1];
}

String formatDate(DateTime date, {bool includeWeekday = false}) {
  final value = '${date.day} ${monthName(date.month)} ${date.year}';
  if (!includeWeekday) {
    return value;
  }
  return '${weekdayName(date)}, $value';
}

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatMinutes(int minutes, {bool is24Hour = true}) {
  final safeMinutes = minutes.clamp(0, 24 * 60);
  int hour = safeMinutes ~/ 60;
  final minute = (safeMinutes % 60).toString().padLeft(2, '0');

  if (is24Hour) {
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr.$minute';
  } else {
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    return '$hour:$minute $period';
  }
}

TimeOfDay minutesToTimeOfDay(int minutes) {
  final safeMinutes = minutes.clamp(0, 24 * 60);
  return TimeOfDay(hour: safeMinutes ~/ 60, minute: safeMinutes % 60);
}

String formatHours(double hours) {
  if (hours == hours.roundToDouble()) {
    return '${hours.toStringAsFixed(0)} jam';
  }
  return '${hours.toStringAsFixed(1)} jam';
}

String formatDateRange(DateTime? startDate, DateTime? endDate) {
  if (startDate == null || endDate == null) {
    return 'Belum diisi';
  }
  return '${formatShortDate(startDate)} - ${formatShortDate(endDate)}';
}

String csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String buildCsvContent(
  InternshipProfile profile,
  List<ActivityEntry> entries, {
  bool is24Hour = true,
}) {
  final sortedEntries = [...entries]..sort(compareActivities);

  // Calculate stats
  final totalHours = entries.fold<double>(0, (sum, e) => sum + e.durationHours);
  final totalDays = sortedEntries.map((e) => e.date).toSet().length;

  final generatedAt = formatDate(DateTime.now(), includeWeekday: true);

  final buffer = StringBuffer();

  // ─── REPORT HEADER ───────────────────────────────────────────────────────────
  buffer.writeln(csvCell('LOG KEGIATAN MAGANG'));
  buffer.writeln(csvCell('Laporan Aktivitas Harian Mahasiswa'));
  buffer.writeln(csvCell('Dibuat pada: $generatedAt'));
  buffer.writeln();

  // ─── IDENTITY BLOCK ──────────────────────────────────────────────────────────
  buffer.writeln(
    '${csvCell('IDENTITAS MAHASISWA')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Nama Lengkap')},${csvCell(profile.studentName)},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('NIM')},${csvCell(profile.studentId)},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Universitas / Institusi')},${csvCell(profile.university)},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Tempat Magang')},${csvCell(profile.internshipPlace)},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Periode Magang')},${csvCell(formatDateRange(profile.startDate, profile.endDate))},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln();

  // ─── SUMMARY STATS ───────────────────────────────────────────────────────────
  buffer.writeln(
    '${csvCell('RINGKASAN')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Total Hari Efektif')},${csvCell('$totalDays hari')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Total Jam Kerja')},${csvCell(formatHours(totalHours))},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln(
    '${csvCell('Jumlah Entri Aktivitas')},${csvCell('${entries.length} catatan')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );
  buffer.writeln();

  // ─── ACTIVITY TABLE ──────────────────────────────────────────────────────────
  buffer.writeln(
    '${csvCell('LOG AKTIVITAS HARIAN')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );

  // Column headers
  buffer.writeln(
    [
      csvCell('No.'),
      csvCell('Hari'),
      csvCell('Tanggal'),
      csvCell('Jam Masuk'),
      csvCell('Jam Keluar'),
      csvCell('Durasi'),
      csvCell('Uraian Kegiatan'),
      csvCell('Foto Terlampir'),
      csvCell('Nama File Foto'),
    ].join(','),
  );

  int seq = 1;
  DateTime? prevDate;
  for (final entry in sortedEntries) {
    // Blank separator row between different dates for readability
    if (prevDate != null && !isSameDay(prevDate, entry.date)) {
      buffer.writeln(
        [
          csvCell(''),
          csvCell(''),
          csvCell(''),
          csvCell(''),
          csvCell(''),
          csvCell(''),
          csvCell(''),
        ].join(','),
      );
    }
    prevDate = entry.date;

    buffer.writeln(
      [
        csvCell('${seq++}'),
        csvCell(weekdayName(entry.date)),
        csvCell(formatDate(entry.date)),
        csvCell(formatMinutes(entry.startMinutes, is24Hour: is24Hour)),
        csvCell(formatMinutes(entry.endMinutes, is24Hour: is24Hour)),
        csvCell(formatHours(entry.durationHours)),
        csvCell(entry.activity),
        csvCell(entry.imagePaths.isEmpty ? 'Tidak ada' : '${entry.imagePaths.length} foto'),
        csvCell(entry.imagePaths.isEmpty ? '-' : entry.imagePaths.map((p) => p.split('/').last).join('; ')),
      ].join(','),
    );
  }

  buffer.writeln();

  // ─── FOOTER ──────────────────────────────────────────────────────────────────
  buffer.writeln(
    '${csvCell('Dokumen ini dibuat secara otomatis oleh aplikasi Log Kegiatan Magang.')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')},${csvCell('')}',
  );

  return buffer.toString();
}

String buildExportFileName(InternshipProfile profile) {
  final safeName = profile.studentName.trim().isEmpty
      ? 'log_magang'
      : profile.studentName.trim().toLowerCase().replaceAll(' ', '_');
  return '${safeName}_log_magang';
}

Color colorWithOpacity(Color color, double opacity) {
  final alpha = (opacity * 255).round().clamp(0, 255);
  return color.withAlpha(alpha);
}
