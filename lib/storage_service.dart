import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';

import 'helpers.dart';
import 'models.dart';

class LocalStorageService {
  static const _dataFileName = 'log_magang_data.json';
  static const _csvSubFolder = 'Log Kegiatan';

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
      if (map is Map<String, dynamic>) {
        return AppData.fromMap(map);
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
}
