import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';

class ImageCleanupService {
  static const _imagesSubFolder = 'images';

  /// Mendapatkan path ke folder images di app documents
  static Future<String?> _getImagesPath() async {
    if (kIsWeb) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$_imagesSubFolder';
    } catch (_) {
      return null;
    }
  }

  /// Dapatkan semua file image yang ada di folder images
  static Future<List<String>> getAllImageFiles() async {
    final imagesPath = await _getImagesPath();
    if (imagesPath == null) return [];

    try {
      final imagesDir = io.Directory(imagesPath);
      if (!await imagesDir.exists()) return [];

      final files = await imagesDir.list().toList();
      return files
          .whereType<io.File>()
          .map((f) => f.path)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Dapatkan semua image paths yang digunakan dalam entries
  static Set<String> getUsedImagePaths(List<ActivityEntry> entries) {
    final usedPaths = <String>{};
    for (final entry in entries) {
      usedPaths.addAll(entry.imagePaths);
    }
    return usedPaths;
  }

  /// Cari gambar yang tidak terpakai (orphaned images)
  static Future<List<String>> findOrphanedImages(List<ActivityEntry> entries) async {
    final allImages = await getAllImageFiles();
    final usedPaths = getUsedImagePaths(entries);

    return allImages
        .where((imagePath) => !usedPaths.contains(imagePath))
        .toList();
  }

  /// Hapus file gambar yang orphaned
  static Future<int> cleanupOrphanedImages(List<ActivityEntry> entries) async {
    final orphanedImages = await findOrphanedImages(entries);
    int deletedCount = 0;

    for (final imagePath in orphanedImages) {
      try {
        final file = io.File(imagePath);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        }
      } catch (_) {
        // Silently skip if delete fails
      }
    }

    return deletedCount;
  }

  /// Hapus gambar tertentu dari file system
  static Future<bool> deleteImageFile(String imagePath) async {
    try {
      final file = io.File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Dapatkan informasi storage
  static Future<Map<String, dynamic>> getStorageInfo() async {
    final imagesPath = await _getImagesPath();
    if (imagesPath == null) {
      return {
        'totalImages': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': 0.0,
        'imageList': [],
      };
    }

    try {
      final imagesDir = io.Directory(imagesPath);
      if (!await imagesDir.exists()) {
        return {
          'totalImages': 0,
          'totalSizeBytes': 0,
          'totalSizeMB': 0.0,
          'imageList': [],
        };
      }

      final files = await imagesDir.list().toList();
      final imageFiles = files.whereType<io.File>().toList();

      int totalSizeBytes = 0;
      final imageList = <Map<String, dynamic>>[];

      for (final file in imageFiles) {
        final stat = await file.stat();
        final sizeBytes = stat.size;
        totalSizeBytes += sizeBytes;

        imageList.add({
          'path': file.path,
          'name': p.basename(file.path),
          'sizeBytes': sizeBytes,
          'sizeMB': sizeBytes / (1024 * 1024),
          'modified': stat.modified,
        });
      }

      return {
        'totalImages': imageFiles.length,
        'totalSizeBytes': totalSizeBytes,
        'totalSizeMB': totalSizeBytes / (1024 * 1024),
        'imageList': imageList,
      };
    } catch (_) {
      return {
        'totalImages': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': 0.0,
        'imageList': [],
      };
    }
  }

  /// Dapatkan informasi image tertentu
  static Future<Map<String, dynamic>?> getImageInfo(String imagePath) async {
    try {
      final file = io.File(imagePath);
      if (await file.exists()) {
        final stat = await file.stat();
        return {
          'path': imagePath,
          'name': p.basename(imagePath),
          'sizeBytes': stat.size,
          'sizeMB': stat.size / (1024 * 1024),
          'modified': stat.modified,
          'exists': true,
        };
      }
      return {
        'path': imagePath,
        'exists': false,
      };
    } catch (_) {
      return null;
    }
  }

  /// Hapus semua gambar (use dengan hati-hati!)
  static Future<int> deleteAllImages() async {
    final imagesPath = await _getImagesPath();
    if (imagesPath == null) return 0;

    try {
      final imagesDir = io.Directory(imagesPath);
      if (!await imagesDir.exists()) return 0;

      int deletedCount = 0;
      final files = await imagesDir.list().toList();

      for (final file in files) {
        if (file is io.File) {
          try {
            await file.delete();
            deletedCount++;
          } catch (_) {}
        }
      }

      return deletedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Export image ke external storage (copy untuk backup)
  static Future<bool> exportImageToExternalStorage(
    String imagePath,
    String destinationDirectory,
  ) async {
    if (kIsWeb) return false;

    try {
      final sourceFile = io.File(imagePath);
      if (!await sourceFile.exists()) return false;

      final fileName = p.basename(imagePath);
      final destinationPath = '$destinationDirectory/$fileName';
      final destinationFile = io.File(destinationPath);

      await sourceFile.copy(destinationFile.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
