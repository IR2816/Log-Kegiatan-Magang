import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../helpers/helpers.dart';

const _pdfSubFolder = 'Log Kegiatan';

/// Returns the path to the public Downloads/Log Kegiatan folder for PDF files.
Future<String?> _getPdfExportPath() async {
  if (kIsWeb) return null;
  try {
    const publicDownloads = '/storage/emulated/0/Download';
    final pubDir = Directory(publicDownloads);
    if (await pubDir.exists()) {
      final exportDir = Directory('$publicDownloads/$_pdfSubFolder');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      return exportDir.path;
    }
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        var current = extDir.parent;
        for (var i = 0; i < 3; i++) {
          current = current.parent;
        }
        final candidate = Directory('${current.path}/Download/$_pdfSubFolder');
        if (!await candidate.exists()) await candidate.create(recursive: true);
        return candidate.path;
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final fallback = Directory('${docs.path}/$_pdfSubFolder');
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return fallback.path;
  } catch (_) {
    return null;
  }
}

class PdfExportService {
  /// Export ke PDF dengan opsi tambahan (foto, signature, footer)
  static Future<String?> exportToPdf(
    AppData data, {
    String? supervisorName,
    String? supervisorSignaturePath,
    bool includeImages = true,
    bool includeReflections = false,
  }) async {
    if (kIsWeb) return null;
    
    final pdf = pw.Document();

    final profile = data.profile;
    final entries = List<ActivityEntry>.from(data.entries);
    entries.sort((a, b) => a.date.compareTo(b.date));

    // Load university logo if exists
    pw.ImageProvider? uniLogo;
    if (profile.universityLogoPath != null) {
      final logoFile = File(profile.universityLogoPath!);
      if (await logoFile.exists()) {
        uniLogo = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }

    // Load profile picture if exists
    pw.ImageProvider? profilePic;
    if (profile.profilePicturePath != null) {
      final picFile = File(profile.profilePicturePath!);
      if (await picFile.exists()) {
        profilePic = pw.MemoryImage(await picFile.readAsBytes());
      }
    }

    // Load signature if exists
    pw.ImageProvider? signature;
    if (supervisorSignaturePath != null) {
      final sigFile = File(supervisorSignaturePath);
      if (await sigFile.exists()) {
        signature = pw.MemoryImage(await sigFile.readAsBytes());
      }
    }

    // Generate PDF pages
    int pageIndex = 0;
    const entriesPerPage = 10;

    for (int i = 0; i < entries.length; i += entriesPerPage) {
      final pageEntries = entries.sublist(
        i,
        i + entriesPerPage > entries.length ? entries.length : i + entriesPerPage,
      );
      pageIndex++;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Logo universitas
                  if (uniLogo != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(uniLogo),
                    ),
                  // Title & Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'LOG KEGIATAN MAGANG',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          profile.university,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Profile picture
                  if (profilePic != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Image(profilePic),
                    ),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),

              // Student Information Box
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Nama: ${profile.studentName}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('NIM: ${profile.studentId}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Universitas: ${profile.university}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Tempat Magang: ${profile.internshipPlace}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Periode: ${formatDateRange(profile.startDate, profile.endDate)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Activity Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
                cellHeight: 25,
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(0.9),
                  3: const pw.FlexColumnWidth(0.9),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(2),
                },
                data: [
                  ['No', 'Tanggal', 'Jam Masuk', 'Jam Keluar', 'Total Jam', 'Uraian Kegiatan'],
                  ...pageEntries.asMap().entries.map((e) {
                    final idx = i + e.key + 1;
                    final item = e.value;
                    return [
                      idx.toString(),
                      formatDate(item.date),
                      formatMinutes(item.startMinutes, is24Hour: data.settings.use24HourFormat),
                      formatMinutes(item.endMinutes, is24Hour: data.settings.use24HourFormat),
                      (item.durationHours.toStringAsFixed(1)),
                      item.activity.substring(0, item.activity.length > 80 ? 80 : item.activity.length),
                    ];
                  }),
                ],
              ),

              pw.SizedBox(height: 12),

              // Page footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Halaman $pageIndex',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Dicetak: ${formatDate(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ];
          },
          footer: (pw.Context context) {
            return pw.SizedBox.expand(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      // Pembimbing / Supervisor
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(
                            'Pembimbing Magang',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 40),
                          if (signature != null)
                            pw.Container(
                              width: 60,
                              height: 30,
                              child: pw.Image(signature),
                            )
                          else
                            pw.Text('(...........................)', style: const pw.TextStyle(fontSize: 8)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            supervisorName ?? '(...........................)',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                      // Mahasiswa
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Mahasiswa,', style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(height: 40),
                          pw.Text('(...........................)', style: const pw.TextStyle(fontSize: 8)),
                          pw.SizedBox(height: 4),
                          pw.Text(profile.studentName, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Halaman Refleksi (optional)
    if (includeReflections && data.reflections.isNotEmpty) {
      final reflections = List<DailyReflection>.from(data.reflections);
      reflections.sort((a, b) => a.date.compareTo(b.date));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Text(
                'CATATAN REFLEKSI & PERKEMBANGAN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              ...reflections.map((reflection) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            formatDate(reflection.date),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            'Mood: ${reflection.mood.emoji} ${reflection.mood.label}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      if (reflection.reflection.isNotEmpty) ...[
                        pw.Text('Refleksi:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Text(reflection.reflection, style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 4),
                      ],
                      if (reflection.lessonsLearned.isNotEmpty) ...[
                        pw.Text('Pelajaran:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Text(reflection.lessonsLearned, style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );
    }

    // Save to Downloads/Log Kegiatan folder (persistent, not temp)
    final exportPath = await _getPdfExportPath();
    final outputDir = exportPath ?? (await getTemporaryDirectory()).path;
    final fileName = 'Log_Magang_${profile.studentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('$outputDir/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Export PDF dengan format yang sederhana (quick export)
  static Future<String?> quickExportToPdf(AppData data) async {
    return exportToPdf(
      data,
      includeImages: true,
      includeReflections: false,
    );
  }

  /// Export PDF dengan semua detail (refleksi, foto, dll)
  static Future<String?> fullExportToPdf(
    AppData data, {
    String? supervisorName,
    String? supervisorSignaturePath,
  }) async {
    return exportToPdf(
      data,
      supervisorName: supervisorName,
      supervisorSignaturePath: supervisorSignaturePath,
      includeImages: true,
      includeReflections: true,
    );
  }
}
