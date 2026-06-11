import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import '../helpers/helpers.dart';
import '../helpers/web_download.dart' as web_download;
import '../models/models.dart';

class LocalStorageService {
  static const _dataFileName = 'log_magang_data.json';
  static const _csvSubFolder = 'Log Kegiatan';
  static const _draftFileName = 'activity_draft.json';

  // Simple in-memory storage for Web fallback
  static AppData? _webDataBuffer;

  Future<String?> _getBasePath() async {
    if (kIsWeb) return null;
    try {
      final directory = await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
      );
      return directory.path;
    } catch (_) {
      return null;
    }
  }

  /// Returns the path to the public Downloads/Log Kegiatan folder.
  /// Tries the hardcoded public path first, then falls back to app docs.
  Future<String?> _getCsvExportPath() async {
    if (kIsWeb) return null;
    try {
      // Primary: hardcoded public Downloads path (works on all Android versions)
      const publicDownloads = '/storage/emulated/0/Download';
      final pubDir = io.Directory(publicDownloads);
      if (await pubDir.exists()) {
        final exportDir = io.Directory('$publicDownloads/$_csvSubFolder');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        return exportDir.path;
      }

      // Secondary: use path_provider's external storage, walk up to Downloads
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          // extDir is like /storage/emulated/0/Android/data/.../files
          // Walk up 4 levels to reach /storage/emulated/0
          var current = extDir.parent;
          for (var i = 0; i < 3; i++) {
            current = current.parent;
          }
          final candidate = io.Directory('${current.path}/Download/$_csvSubFolder');
          if (!await candidate.exists()) await candidate.create(recursive: true);
          return candidate.path;
        }
      } catch (_) {}

      // Final fallback: app documents dir
      final docs = await getApplicationDocumentsDirectory();
      final fallback = io.Directory('${docs.path}/$_csvSubFolder');
      if (!await fallback.exists()) await fallback.create(recursive: true);
      return fallback.path;
    } catch (_) {
      return await _getBasePath();
    }
  }

  Future<AppData> load() async {
    if (kIsWeb) {
      return _webDataBuffer ?? const AppData.empty();
    }

    try {
      final path = await _getBasePath();
      if (path == null) return const AppData.empty();
      
      final file = io.File('$path/$_dataFileName');
      if (!await file.exists()) {
        return const AppData.empty();
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const AppData.empty();
      }

      final map = jsonDecode(content);
      if (map is Map) {
        return AppData.fromMap(Map<String, dynamic>.from(map));
      }

      return const AppData.empty();
    } catch (_) {
      return const AppData.empty();
    }
  }

  Future<void> save(AppData data) async {
    if (kIsWeb) {
      _webDataBuffer = data;
      return;
    }

    try {
      final path = await _getBasePath();
      if (path == null) return;
      
      final file = io.File('$path/$_dataFileName');
      await file.writeAsString(jsonEncode(data.toMap()));
    } catch (_) {
      // Silent error
    }
  }

  /// Save activity editor draft
  Future<void> saveDraft(Map<String, dynamic> draft) async {
    if (kIsWeb) return;
    try {
      final path = await _getBasePath();
      if (path == null) return;
      final file = io.File('$path/$_draftFileName');
      await file.writeAsString(jsonEncode(draft));
    } catch (_) {}
  }

  /// Load activity editor draft, returns null if none
  Future<Map<String, dynamic>?> loadDraft() async {
    if (kIsWeb) return null;
    try {
      final path = await _getBasePath();
      if (path == null) return null;
      final file = io.File('$path/$_draftFileName');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// Clear saved draft
  Future<void> clearDraft() async {
    if (kIsWeb) return;
    try {
      final path = await _getBasePath();
      if (path == null) return;
      final file = io.File('$path/$_draftFileName');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Saves CSV to Downloads/Log Magang and returns the full file path.
  /// Includes UTF-8 BOM so Excel opens it correctly without character issues.
  Future<String?> saveCsv(AppData data) async {
    final fileName = '${buildExportFileName(data.profile)}.csv';
    final content = buildCsvContent(
      data.profile,
      data.entries,
      is24Hour: data.settings.use24HourFormat,
    );

    if (kIsWeb) {
      return 'web_export_$fileName';
    }

    try {
      final exportPath = await _getCsvExportPath();
      if (exportPath == null) return null;

      final file = io.File('$exportPath/$fileName');

      // Write UTF-8 BOM + content for proper Excel rendering
      final bom = Uint8List.fromList([0xEF, 0xBB, 0xBF]);
      final contentBytes = Uint8List.fromList(utf8.encode(content));
      await file.writeAsBytes([...bom, ...contentBytes]);

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Copies an image to the app's documents directory so it is preserved.
  Future<String> saveImageInApp(String originalPath) async {
    if (kIsWeb) return originalPath;
    try {
      final base = await _getBasePath();
      if (base == null) return originalPath;

      final imagesDir = io.Directory('$base/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalPath)}';
      final newPath = '${imagesDir.path}/$fileName';
      
      final file = io.File(originalPath);
      await file.copy(newPath);
      return newPath;
    } catch (_) {
      return originalPath;
    }
  }

  /// Backups the JSON data and images folder into a zip file at the specified export path.
  /// On web, triggers a browser download instead.
  Future<String?> backupData(String exportDirectory) async {
    try {
      if (kIsWeb) {
        // Create ZIP in memory and trigger browser download
        final archive = Archive();

        // Add JSON data to archive
        if (_webDataBuffer != null) {
          final jsonStr = jsonEncode(_webDataBuffer!.toMap());
          final bytes = utf8.encode(jsonStr);
          archive.addFile(ArchiveFile('data.json', bytes.length, bytes));
        }

        if (archive.isEmpty) return null;

        final zipBytes = ZipEncoder().encode(archive);
        if (zipBytes == null) return null;

        final fileName = 'log_magang_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
        web_download.triggerWebDownload(fileName, zipBytes);
        return fileName;
      }

      final base = await _getBasePath();
      if (base == null) return null;

      final encoder = ZipFileEncoder();
      final zipPath = '$exportDirectory/log_magang_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
      encoder.create(zipPath);

      final dataFile = io.File('$base/$_dataFileName');
      if (await dataFile.exists()) {
        encoder.addFile(dataFile);
      }

      final imagesDir = io.Directory('$base/images');
      if (await imagesDir.exists()) {
        encoder.addDirectory(imagesDir);
      }

      encoder.close();
      return zipPath;
    } catch (_) {
      return null;
    }
  }

  /// Restores data from ZIP bytes (for web) or a zip file path (for mobile).
  Future<bool> restoreData(String zipFilePath, {Uint8List? bytes}) async {
    try {
      final zipBytes = bytes ?? await io.File(zipFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      if (kIsWeb) {
        // On web, parse data.json from ZIP and update in-memory buffer
        for (final file in archive) {
          if (file.isFile && file.name == 'data.json') {
            final data = file.content as List<int>;
            final jsonStr = utf8.decode(data);
            final map = jsonDecode(jsonStr);
            if (map is Map) {
              _webDataBuffer = AppData.fromMap(Map<String, dynamic>.from(map));
              return true;
            }
          }
        }
        return false;
      }

      final base = await _getBasePath();
      if (base == null) return false;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = io.File('$base/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          final outDir = io.Directory('$base/$filename');
          await outDir.create(recursive: true);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Parses CSV content string and returns imported entries + profile.
  /// Works on all platforms including web.
  Future<CsvImportResult> importCsvFromString(String content, bool is24Hour) async {
    try {
      final rows = const CsvToListConverter(eol: '\n').convert(content);

      final List<ActivityEntry> entries = [];
      InternshipProfile? profile;

      // Try to extract profile from CSV header
      String? studentName, studentId, university, internshipPlace;
      DateTime? startDate, endDate;

      for (final row in rows) {
        if (row.length < 2) continue;
        final label = row[0].toString().trim();
        final value = row[1].toString().trim();

        if (label == 'Nama Lengkap' && value.isNotEmpty) {
          studentName = value;
        } else if (label == 'NIM' && value.isNotEmpty) {
          studentId = value;
        } else if (label == 'Universitas / Institusi' && value.isNotEmpty) {
          university = value;
        } else if (label == 'Tempat Magang' && value.isNotEmpty) {
          internshipPlace = value;
        } else if (label == 'Periode Magang' && value.isNotEmpty) {
          // Parse "19 Feb 2026 - 19 Jun 2026"
          final periodParts = value.split(' - ');
          if (periodParts.length == 2) {
            startDate = _parseIndonesianDate(periodParts[0].trim());
            endDate = _parseIndonesianDate(periodParts[1].trim());
          }
        }
      }

      if (studentName != null) {
        profile = InternshipProfile(
          studentName: studentName,
          studentId: studentId ?? '',
          university: university ?? '',
          internshipPlace: internshipPlace ?? '',
          startDate: startDate,
          endDate: endDate,
        );
      }

      // Parse activity entries
      for (final row in rows) {
        if (row.length >= 7) {
          final noStr = row[0].toString().trim();
          if (int.tryParse(noStr) != null) {
            final dateStr = row[2].toString().trim();
            final startStr = row[3].toString().trim();
            final endStr = row[4].toString().trim();
            final activityStr = row[6].toString().trim();

            final date = _parseIndonesianDate(dateStr);
            final start = _parseTimeMinutes(startStr, is24Hour);
            final end = _parseTimeMinutes(endStr, is24Hour);

            if (date != null && start != null && end != null) {
              entries.add(ActivityEntry(
                id: DateTime.now().microsecondsSinceEpoch.toString() + entries.length.toString(),
                date: date,
                startMinutes: start,
                endMinutes: end,
                activity: activityStr,
                imagePaths: [],
              ));
            }
          }
        }
      }

      return CsvImportResult(entries: entries, profile: profile);
    } catch (_) {
      return const CsvImportResult(entries: []);
    }
  }

  /// Parses an imported CSV file and returns a list of ActivityEntry.
  /// For mobile/desktop only. On web, use importCsvFromString instead.
  Future<List<ActivityEntry>> importCsv(String csvFilePath, bool is24Hour) async {
    if (kIsWeb) return [];
    try {
      final file = io.File(csvFilePath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final result = await importCsvFromString(content, is24Hour);
      return result.entries;
    } catch (_) {
      return [];
    }
  }

  int _parseMonthName(String month) {
    const months = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember',
                    'Jan','Feb','Mar','Apr','Jun','Jul','Agu','Sep','Okt','Nov','Des']; // short months just in case
    final idx = months.indexWhere((m) => m.toLowerCase() == month.toLowerCase());
    if (idx >= 12) return idx - 12 + 1; // short month fallback
    return idx == -1 ? 1 : idx + 1;
  }

  DateTime? _parseIndonesianDate(String dateStr) {
    final parts = dateStr.trim().split(' ');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _parseMonthName(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  int? _parseTimeMinutes(String timeStr, bool is24Hour) {
    timeStr = timeStr.trim();
    if (is24Hour) {
      final parts = timeStr.split(timeStr.contains('.') ? '.' : ':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return h * 60 + m;
    } else {
      final spaceParts = timeStr.split(' ');
      if (spaceParts.length != 2) return null;
      final timeParts = spaceParts[0].split(':');
      if (timeParts.length != 2) return null;
      int h = int.tryParse(timeParts[0]) ?? 0;
      int m = int.tryParse(timeParts[1]) ?? 0;
      final period = spaceParts[1].toUpperCase();
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
      return h * 60 + m;
    }
  }
}

/// Result of CSV import containing activity entries and optional profile.
class CsvImportResult {
  const CsvImportResult({
    required this.entries,
    this.profile,
  });

  final List<ActivityEntry> entries;
  final InternshipProfile? profile;
}
