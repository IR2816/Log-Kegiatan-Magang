import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/animations.dart';
import '../widgets/editor_sheet.dart';
import '../pages/analytics_page.dart';
import '../pages/calendar_page.dart';
import '../pages/reflection_sheet.dart';

import '../widgets/entry_widgets.dart';
import '../helpers/helpers.dart';
import '../widgets/layout_widgets.dart';
import '../widgets/layout_widgets_extras.dart';
import '../models/models.dart';
import '../pages/profile_sheet.dart';
import '../pages/settings_page.dart';
import '../services/storage_service.dart';
import '../services/pdf_export_service.dart';
import '../services/template_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';

class InternshipLogHomePage extends StatefulWidget {
  const InternshipLogHomePage({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<InternshipLogHomePage> createState() => _InternshipLogHomePageState();
}

class _InternshipLogHomePageState extends State<InternshipLogHomePage> {
  final LocalStorageService _storageService = LocalStorageService();

  InternshipProfile _profile = const InternshipProfile.empty();
  List<ActivityEntry> _entries = const [];
  List<DailyReflection> _reflections = const [];
  List<ActivityTemplate> _templates = const [];
  List<AppBadge> _badges = const [];
  late AppSettings _settings;

  bool _isSaving = false;
  int _selectedIndex = 0;
  String? _lastExportPath;
  String _searchQuery = '';
  
  // Multi-select state
  bool _isMultiSelecting = false;
  final Set<String> _selectedIds = {};
  
  List<ActivityEntry> get _filteredEntries {
    if (_searchQuery.trim().isEmpty) return _entries;
    final query = _searchQuery.trim().toLowerCase();
    return _entries.where((e) => e.activity.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _loadData();
    // Initialize notifications if enabled
    if (widget.initialSettings.reminderEnabled) {
      NotificationService.initialize().then((_) {
        NotificationService.scheduleDailyReminder();
      });
    }
  }

  Future<void> _loadData() async {
    final data = await _storageService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = data.profile;
      _entries = [...data.entries]..sort(compareActivities);
      _settings = data.settings;
      _reflections = [...data.reflections];
      _templates = [...data.templates];
      _badges = [...data.badges];
    });
    // Sync with app-level settings
    widget.onSettingsChanged(_settings);
  }

  Future<void> _persistData({
    InternshipProfile? profile,
    List<ActivityEntry>? entries,
    List<DailyReflection>? reflections,
    List<ActivityTemplate>? templates,
    List<AppBadge>? badges,
  }) async {
    final nextProfile = profile ?? _profile;
    final nextEntries = [...(entries ?? _entries)]..sort(compareActivities);
    final nextReflections = reflections ?? _reflections;
    final nextTemplates = templates ?? _templates;
    final nextBadges = badges ?? _badges;

    setState(() {
      _profile = nextProfile;
      _entries = nextEntries;
      _reflections = nextReflections;
      _templates = nextTemplates;
      _badges = nextBadges;
    });

    await _storageService.save(
      AppData(
        profile: nextProfile,
        entries: nextEntries,
        settings: _settings,
        reflections: nextReflections,
        templates: nextTemplates,
        badges: nextBadges,
      ),
    );
  }

  Future<void> _updateSettings(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    widget.onSettingsChanged(settings);
    await _storageService.save(
      AppData(
        profile: _profile,
        entries: _entries,
        settings: settings,
        reflections: _reflections,
        templates: _templates,
        badges: _badges,
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SettingsPage(
        settings: _settings,
        onSettingsChanged: _updateSettings,
        onEditProfile: _openProfileEditor,
        onBackup: () => _backupData(sheetContext),
        onRestore: () => _restoreData(sheetContext),
        onImportCsv: () => _importCsvData(sheetContext),
      ),
    );
  }

  Future<void> _backupData([BuildContext? sheetContext]) async {
    if (sheetContext != null) Navigator.of(sheetContext).pop(); // close settings

    String exportDir = '';
    if (!kIsWeb) {
      exportDir = await FilePicker.getDirectoryPath(dialogTitle: 'Pilih folder untuk menyimpan backup') ?? '';
      if (exportDir.isEmpty) return;
    }

    if (!mounted) return;
    _showMessage('Sedang mem-backup data...');
    try {
      final zipPath = await _storageService.backupData(exportDir);
      if (!mounted) return;
      if (zipPath != null) {
        _showMessage(kIsWeb
            ? '✅ Backup berhasil diunduh: $zipPath'
            : '✅ Backup berhasil disimpan di: $zipPath');
      } else {
        _showMessage('❌ Gagal melakukan backup.');
      }
    } catch (e) {
      if (mounted) _showMessage('❌ Gagal backup: $e');
    }
  }

  Future<void> _restoreData([BuildContext? sheetContext]) async {
    if (sheetContext != null) Navigator.of(sheetContext).pop(); // close settings
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Pilih file backup (.zip)',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );

      if (result == null || !mounted) return;
      final file = result.files.single;

      // On web, need bytes; on mobile, need path
      if (kIsWeb && file.bytes == null) return;
      if (!kIsWeb && file.path == null) return;

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Data?'),
          content: const Text('Data saat ini akan tertimpa dengan data dari backup. Lanjutkan?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore')),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      _showMessage('Sedang memulihkan data...');
      final success = kIsWeb
          ? await _storageService.restoreData('', bytes: Uint8List.fromList(file.bytes!))
          : await _storageService.restoreData(file.path!);
      if (!mounted) return;
      if (success) {
        await _loadData(); // reload UI
        _showMessage('✅ Data berhasil dipulihkan!');
      } else {
        _showMessage('❌ Gagal memulihkan data.');
      }
    } catch (e) {
      if (mounted) _showMessage('❌ Gagal restore: $e');
    }
  }

  Future<void> _importCsvData([BuildContext? sheetContext]) async {
    if (sheetContext != null) Navigator.of(sheetContext).pop(); // close settings
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Pilih file CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Always get data so it works on web too
      );

      if (result == null || !mounted) return;
      final file = result.files.single;

      // Read CSV content from bytes or path
      String? csvContent;
      try {
        if (kIsWeb) {
          if (file.bytes == null) return;
          csvContent = utf8.decode(file.bytes!);
        } else {
          if (file.path == null) return;
          csvContent = await File(file.path!).readAsString();
        }
      } catch (e) {
        if (mounted) _showMessage('❌ Gagal membaca file: $e');
        return;
      }

      if (!mounted || csvContent == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import CSV?'),
          content: Text('Catatan dari "${file.name}" akan ditambahkan ke data saat ini. Lanjutkan?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Import')),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      _showMessage('Sedang mengimpor data CSV...');
      final importResult = await _storageService.importCsvFromString(csvContent, _settings.use24HourFormat);
      final importedEntries = importResult.entries;

      if (!mounted) return;

      if (importedEntries.isNotEmpty) {
        final newEntries = [..._entries];
        for (final e in importedEntries) {
          // avoid exact duplicates (same date, same start, same end, same activity)
          final isDuplicate = newEntries.any((existing) =>
              existing.date == e.date &&
              existing.startMinutes == e.startMinutes &&
              existing.endMinutes == e.endMinutes &&
              existing.activity == e.activity);
          if (!isDuplicate) {
            newEntries.add(e);
          }
        }

        // Apply profile from CSV if found and current profile is empty
        InternshipProfile? newProfile;
        if (importResult.profile != null && _profile.isEmpty) {
          newProfile = importResult.profile;
        }

        await _persistData(entries: newEntries, profile: newProfile);

        final profileMsg = newProfile != null ? ' (profil juga diimpor)' : '';
        _showMessage('✅ ${importedEntries.length} data berhasil diimpor!$profileMsg');
      } else {
        _showMessage('❌ Tidak ada data yang berhasil diimpor. Pastikan format CSV sesuai (ekspor dari aplikasi ini).');
      }
    } catch (e) {
      if (mounted) _showMessage('❌ Gagal import CSV: $e');
    }
  }

  double get _totalHours =>
      _entries.fold(0.0, (sum, entry) => sum + entry.durationHours);

  Widget? get _floatingActionButton {
    if (_isMultiSelecting) return null;

    if (_selectedIndex == 0) {
      return FloatingActionButton.extended(
        onPressed: _openProfileEditor,
        icon: const Icon(Icons.badge_rounded),
        label: const Text('Isi profil'),
      );
    }

    if (_selectedIndex == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'template',
            onPressed: _showTemplatePicker,
            tooltip: 'Quick-add dari template',
            child: const Icon(Icons.flash_on_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_activity',
            onPressed: _openActivityEditor,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Tambah aktivitas'),
          ),
        ],
      );
    }

    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openProfileEditor() async {
    final profile = await showModalBottomSheet<InternshipProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileEditorSheet(initialProfile: _profile),
    );

    if (!mounted || profile == null) {
      return;
    }

    await _persistData(profile: profile);
    if (!mounted) {
      return;
    }
    _showMessage('Profil magang berhasil disimpan.');
  }

  Future<void> _openActivityEditor([ActivityEntry? entry]) async {
    final savedEntry = await showModalBottomSheet<ActivityEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityEditorSheet(
        initialEntry: entry,
        is24Hour: _settings.use24HourFormat,
      ),
    );

    if (!mounted || savedEntry == null) {
      return;
    }

    final nextEntries = [..._entries];
    final index = nextEntries.indexWhere((item) => item.id == savedEntry.id);
    if (index >= 0) {
      nextEntries[index] = savedEntry;
    } else {
      nextEntries.add(savedEntry);
    }

    await _persistData(entries: nextEntries);
    if (!mounted) {
      return;
    }
    _showMessage(
      entry == null
          ? 'Aktivitas berhasil ditambahkan.'
          : 'Aktivitas berhasil diperbarui.',
    );
  }

  Future<void> _deleteActivity(ActivityEntry entry) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus aktivitas?'),
            content: Text(
              'Aktivitas pada ${formatDate(entry.date)} akan dihapus.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !confirmed) {
      return;
    }

    final nextEntries = [..._entries]
      ..removeWhere((item) => item.id == entry.id);
    await _persistData(entries: nextEntries);
    if (!mounted) {
      return;
    }

    // Show undo SnackBar
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Aktivitas berhasil dihapus.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Theme.of(context).colorScheme.primary,
            onPressed: () {
              // Restore the deleted entry
              final restored = [..._entries, entry];
              _persistData(entries: restored);
              _showMessage('Aktivitas dipulihkan.');
            },
          ),
        ),
      );
  }

  Future<String?> _ensureExportFile() async {
    if (!_profile.canExport) {
      _showMessage(
        'Lengkapi nama mahasiswa, universitas, dan periode magang terlebih dahulu.',
      );
      return null;
    }

    if (_entries.isEmpty) {
      _showMessage('Belum ada aktivitas harian yang bisa diekspor.');
      return null;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final path = await _storageService.saveCsv(
        AppData(profile: _profile, entries: _entries, settings: _settings),
      );
      if (!mounted) {
        return null;
      }
      setState(() {
        _lastExportPath = path;
      });
      return path;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveCsvOnly() async {
    final path = await _ensureExportFile();
    if (!mounted || path == null) {
      return;
    }
    _showMessage('✅ CSV disimpan di: $path');
  }

  Future<void> _shareCsv() async {
    final path = await _ensureExportFile();
    if (!mounted || path == null) {
      return;
    }

    final fileName = '${buildExportFileName(_profile)}.csv';
    
    if (kIsWeb) {
      // On web, we generate content and share it as bytes/string
      final content = buildCsvContent(_profile, _entries, is24Hour: _settings.use24HourFormat);
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(utf8.encode(content)),
          name: fileName,
          mimeType: 'text/csv',
        ),
      ], text: 'Log kegiatan magang ${_profile.studentName}');
    } else {
      await Share.shareXFiles([
        XFile(path, mimeType: 'text/csv'),
      ], text: 'Log kegiatan magang ${_profile.studentName}');
    }
  }

  Future<String?> _exportPdf() async {
    if (!_profile.canExport) {
      _showMessage('Lengkapi nama mahasiswa, universitas, dan periode magang terlebih dahulu.');
      return null;
    }
    if (_entries.isEmpty) {
      _showMessage('Belum ada aktivitas harian yang bisa diekspor.');
      return null;
    }

    setState(() => _isSaving = true);
    try {
      final path = await PdfExportService.exportToPdf(
        AppData(profile: _profile, entries: _entries, settings: _settings),
      );
      if (mounted) setState(() => _lastExportPath = path);
      return path;
    } catch (e) {
      if (mounted) _showMessage('Gagal ekspor PDF: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePdfOnly() async {
    final path = await _exportPdf();
    if (!mounted || path == null) return;
    _showMessage('✅ PDF disimpan di: $path');
  }

  Future<void> _sharePdf() async {
    final path = await _exportPdf();
    if (!mounted || path == null) return;

    if (!kIsWeb) {
      await Share.shareXFiles([
        XFile(path, mimeType: 'application/pdf'),
      ], text: 'Log kegiatan magang ${_profile.studentName} (PDF)');
    }
  }

  // ─── Reflection Methods ────────────────────────────────────────────
  Future<void> _openReflectionSheet([DailyReflection? existing]) async {
    final today = dateOnly(DateTime.now());
    final existingForToday = _reflections.where((r) => isSameDay(r.date, today)).firstOrNull;
    
    final reflection = await showModalBottomSheet<DailyReflection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReflectionSheet(
        existingReflection: existing ?? existingForToday,
      ),
    );

    if (!mounted || reflection == null) return;

    final nextReflections = [..._reflections];
    final index = nextReflections.indexWhere((r) => isSameDay(r.date, reflection.date));
    if (index >= 0) {
      nextReflections[index] = reflection;
    } else {
      nextReflections.add(reflection);
    }
    await _persistData(reflections: nextReflections);
    
    // Check for new badges
    _checkBadges();
    
    if (mounted) _showMessage('Refleksi berhasil disimpan.');
  }

  // ─── Template Quick-Add ────────────────────────────────────────────
  Future<void> _showTemplatePicker() async {
    final allTemplates = TemplateService.getAllTemplates(_templates);
    
    final selected = await showModalBottomSheet<ActivityTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TemplatePickerSheet(templates: allTemplates),
    );

    if (!mounted || selected == null) return;

    final entry = TemplateService.createEntryFromTemplate(
      selected,
      DateTime.now(),
      8 * 60, // Default start at 08:00
    );

    final nextEntries = [..._entries, entry];
    await _persistData(entries: nextEntries);
    _checkBadges();
    
    if (mounted) _showMessage('Aktivitas dari template berhasil ditambahkan.');
  }

  // ─── Badge Checking ──────────────────────────────────────────────
  void _checkBadges() {
    final newBadges = GamificationService.checkNewBadges(
      _entries,
      _reflections,
      _badges,
    );
    if (newBadges.isNotEmpty) {
      final allBadges = [..._badges, ...newBadges];
      _persistData(badges: allBadges);
      
      // Show badge notification
      if (mounted) {
        for (final badge in newBadges) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${badge.icon} Badge baru: ${badge.title}!'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // ─── Multi-Select Methods ──────────────────────────────────────
  void _toggleMultiSelect() {
    setState(() {
      _isMultiSelecting = !_isMultiSelecting;
      if (!_isMultiSelecting) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus terpilih?'),
        content: Text('${_selectedIds.length} aktivitas akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final nextEntries = _entries.where((e) => !_selectedIds.contains(e.id)).toList();
    await _persistData(entries: nextEntries);
    
    setState(() {
      _isMultiSelecting = false;
      _selectedIds.clear();
    });
    
    if (mounted) _showMessage('${_selectedIds.length} aktivitas dihapus.');
  }

  // ─── Open Calendar (kept for programmatic use) ──────────────────
  // ignore: unused_element
  void _openCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CalendarPage(
          entries: _entries,
          settings: _settings,
          onEdit: _openActivityEditor,
          onAddActivity: _openActivityEditor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isMultiSelecting
              ? '${_selectedIds.length} dipilih'
              : switch (_selectedIndex) {
                  0 => 'Dashboard',
                  1 => 'Catatan',
                  2 => 'Kalender',
                  3 => 'Laporan',
                  _ => 'Ekspor',
                },
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            fontFamily: 'Serif',
            color: theme.colorScheme.onSurface,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _isMultiSelecting
            ? IconButton(
                onPressed: _toggleMultiSelect,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Batal',
              )
            : null,
        actions: [
          if (_isMultiSelecting)
            IconButton(
              onPressed: _bulkDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Hapus terpilih',
              color: const Color(0xFFDC2626),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: isDark 
                      ? Colors.white.withOpacity(0.05) 
                      : theme.colorScheme.primary.withOpacity(0.05),
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                tooltip: 'Pengaturan',
              ),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.light
                ? [const Color(0xFFFBF9F6), const Color(0xFFF0F4F8)]
                : [const Color(0xFF121212), const Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: switch (_selectedIndex) {
                0 => _buildProfilePage(context),
                1 => _buildActivityPage(context),
                2 => CalendarPage(
                  entries: _entries,
                  settings: _settings,
                  onEdit: _openActivityEditor,
                  onAddActivity: () => _openActivityEditor(),
                ),
                3 => AnalyticsPage(
                  entries: _entries,
                  settings: _settings,
                  profile: _profile,
                ),
                _ => _buildExportPage(context),
              },
            ),
          ),
        ),
      ),
      floatingActionButton: _floatingActionButton,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Aktivitas',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Kalender',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'Laporan',
            ),
            NavigationDestination(
              icon: Icon(Icons.file_download_outlined),
              selectedIcon: Icon(Icons.file_download_rounded),
              label: 'Ekspor',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final totalPhotos = _entries.fold<int>(0, (s, e) => s + e.imagePaths.length);
    final recentEntries = (List<ActivityEntry>.from(_entries)
      ..sort(compareActivities))
      .take(3)
      .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      children: [
        // ─── GRADIENT PROFILE BANNER ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
                  : [primary, primary.withOpacity(0.75)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture or Initials
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _profile.profilePicturePath != null
                        ? Image.file(File(_profile.profilePicturePath!), fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              _profile.studentName.isEmpty
                                  ? '?'
                                  : _profile.studentName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile.studentName.isEmpty ? 'Nama Mahasiswa' : _profile.studentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile.studentId.isEmpty ? 'NIM belum diisi' : _profile.studentId,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile.university.isEmpty ? 'Universitas belum diisi' : _profile.university,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // University Logo Overlay
                  if (_profile.universityLogoPath != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(_profile.universityLogoPath!), fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              // Quick stat bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _BannerStat(value: '${_entries.length}', label: 'Log')),
                    _divider(),
                    Expanded(child: _BannerStat(value: '${_totalHours.toInt()}', label: 'Jam')),
                    _divider(),
                    Expanded(
                      child: _BannerStat(
                        value: _entries.isEmpty
                            ? '-'
                            : '${_entries.map((e) => e.date).toSet().length}',
                        label: 'Hari',
                      ),
                    ),
                    _divider(),
                    Expanded(child: _BannerStat(value: '$totalPhotos', label: 'Foto')),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── CONTENT ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place & period strip
              if (!_profile.isEmpty) ...[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(
                        icon: Icons.business_outlined,
                        label: 'Tempat magang',
                        value: _profile.internshipPlace.isEmpty ? 'Belum diisi' : _profile.internshipPlace,
                      ),
                      const SizedBox(height: 12),
                      InfoRow(
                        icon: Icons.date_range_rounded,
                        label: 'Periode magang',
                        value: formatDateRange(_profile.startDate, _profile.endDate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Hours progress card
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF166534).withOpacity(0.5)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time_filled_rounded,
                                size: 18, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Total Jam Kerja',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${(_totalHours / 500 * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AnimatedCounter(
                            value: _totalHours.toInt(),
                            duration: const Duration(milliseconds: 1100),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF14532D),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'dari 500 jam',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_totalHours / 500).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF16A34A).withOpacity(0.15),
                          color: const Color(0xFF16A34A),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _entries.isEmpty
                            ? 'Belum ada aktivitas tercatat.'
                            : 'Dari ${_entries.length} catatan aktivitas harian.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF16A34A).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Streak & Badges Card ──────────────────────────────────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF422006) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF92400E).withOpacity(0.5)
                          : const Color(0xFFF59E0B).withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.local_fire_department_rounded,
                                size: 20, color: Color(0xFFF59E0B)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Streak',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${GamificationService.calculateStreak(_entries)} hari berturut-turut',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '🏅 ${_badges.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      if (_badges.isNotEmpty) ...[                    
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _badges.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (ctx, i) {
                              final badge = _badges[i];
                              return Tooltip(
                                message: '${badge.title}\n${badge.description}',
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(badge.icon, style: const TextStyle(fontSize: 22)),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Reflection Button ─────────────────────────────────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 280),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openReflectionSheet(),
                    icon: const Icon(Icons.psychology_outlined),
                    label: const Text('Isi Refleksi Harian'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mini metric row
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.edit_note_rounded,
                        label: 'Catatan',
                        value: '${_entries.length}',
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.photo_library_rounded,
                        label: 'Foto',
                        value: '$totalPhotos',
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.today_rounded,
                        label: 'Hari',
                        value: _entries.isEmpty ? '0' : '${_entries.map((e) => e.date).toSet().length}',
                        color: const Color(0xFFDB2777),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recent activity preview
              if (recentEntries.isNotEmpty) ...[
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aktivitas Terkini',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedIndex = 1),
                        child: const Text('Lihat semua →'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...recentEntries.asMap().entries.map((e) => FadeSlideIn(
                  delay: Duration(milliseconds: 460 + e.key * 60),
                  child: _RecentActivityTile(
                    entry: e.value,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                    },
                    is24Hour: _settings.use24HourFormat,
                  ),
                )),
              ],

              // Empty state prompt
              if (_profile.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tekan tombol "Isi profil" di bawah untuk melengkapi identitas dan mulai mencatat aktivitas magang.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(0.25),
    );
  }

  Widget _buildActivityPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
      children: [
        // Multi-select toggle button
        if (!_isMultiSelecting && _entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _toggleMultiSelect,
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: const Text('Pilih banyak'),
              ),
            ),
          ),
        if (_isMultiSelecting && _selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedIds.length} dipilih',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIds.addAll(_entries.map((e) => e.id));
                    });
                  },
                  child: const Text('Pilih semua'),
                ),
              ],
            ),
          ),
        HeroHeader(
          eyebrow: 'Log Harian',
          title: 'Aktivitas Magang',
          subtitle:
              'Isi aktivitas harian secara manual dengan tanggal, hari, jam masuk, jam keluar, dan deskripsi kegiatan.',
          metadata: [
            '${_entries.length} catatan aktivitas',
            formatHours(_totalHours),
            _profile.university.isEmpty
                ? 'Profil belum lengkap'
                : _profile.university,
          ],
          trailing: HeaderStatPanel(
            value: '${_entries.length}',
            label: 'Aktivitas',
            hint: 'Urut dari terbaru',
          ),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Cara pengisian',
                subtitle:
                    'Pilih tanggal, sistem akan menampilkan hari secara otomatis agar tidak salah tulis.',
              ),
              const SizedBox(height: 16),
              const InfoRow(
                icon: Icons.looks_one_rounded,
                label: 'Tanggal dan hari',
                value: 'Pilih tanggal, hari akan mengikuti otomatis.',
              ),
              const SizedBox(height: 12),
              const InfoRow(
                icon: Icons.looks_two_rounded,
                label: 'Jam masuk dan keluar',
                value: 'Isi sesuai kegiatan magang di hari tersebut.',
              ),
              const SizedBox(height: 12),
              const InfoRow(
                icon: Icons.looks_3_rounded,
                label: 'Aktivitas',
                value:
                    'Tuliskan pekerjaan atau kegiatan mahasiswa secara singkat.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            hintText: 'Cari aktivitas (misal: "rapat" atau "laporan")...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 20),
        if (_filteredEntries.isEmpty)
          const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'Tidak ada aktivitas',
            description:
                'Belum ada aktivitas harian atau pencarian tidak ditemukan.',
          )
        else
          ...buildGroupedEntryWidgets(
            context,
            _filteredEntries,
            is24Hour: _settings.use24HourFormat,
            onEdit: _isMultiSelecting
                ? (entry) => _toggleSelection(entry.id)
                : _openActivityEditor,
            onDelete: _isMultiSelecting
                ? (entry) => _toggleSelection(entry.id)
                : _deleteActivity,
            isMultiSelecting: _isMultiSelecting,
            selectedIds: _selectedIds,
            onLongPress: _isMultiSelecting
                ? null
                : (entry) {
                    _toggleMultiSelect();
                    _toggleSelection(entry.id);
                  },
            onTap: _isMultiSelecting
                ? (entry) => _toggleSelection(entry.id)
                : null,
          ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildReportPage(BuildContext context) {
    if (_entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
        children: const [
          EmptyState(
            icon: Icons.analytics_outlined,
            title: 'Belum ada data',
            description: 'Isi aktivitas terlebih dahulu untuk melihat laporan.',
          )
        ]
      );
    }
    
    // Simple Weekly calculation
    int thisWeekCount = 0;
    double thisWeekHours = 0;
    final now = DateTime.now();
    for (final e in _entries) {
      if (now.difference(e.date).inDays <= 7) {
        thisWeekCount++;
        thisWeekHours += e.durationHours;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
      children: [
        HeroHeader(
          eyebrow: 'Laporan',
          title: 'Ringkasan Kinerja',
          subtitle: 'Pantau produktivitas mingguan dan bulanan Anda di sini.',
          metadata: const [],
          trailing: const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Minggu Ini (7 Hari Terakhir)',
                subtitle: 'Ringkasan log kegiatan minggu ini.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.edit_note_rounded,
                      label: 'Kegiatan',
                      value: '$thisWeekCount',
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.access_time_rounded,
                      label: 'Jam',
                      value: thisWeekHours.toStringAsFixed(1),
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
      children: [
        HeroHeader(
          eyebrow: 'Ekspor & Import',
          title: 'Offline dulu, bagikan saat perlu',
          subtitle:
              'Ekspor laporan PDF/CSV, impor data dari CSV, atau backup dan restore semua data aplikasi.',
          metadata: [
            'Mode offline lokal',
            '${_entries.length} baris aktivitas',
            _lastExportPath == null
                ? 'Belum ada file ekspor'
                : 'File siap dibagikan',
          ],
          trailing: HeaderStatPanel(
            value: _profile.canExport ? 'Siap' : 'Lengkapi',
            label: 'Status ekspor',
            hint: _profile.canExport ? 'Profil valid' : 'Isi profil dulu',
          ),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Checklist sebelum ekspor',
                subtitle:
                    'Pastikan data inti sudah ada agar file CSV langsung rapi saat dibuka di Excel.',
              ),
              const SizedBox(height: 12),
              ChecklistTile(
                title: 'Profil mahasiswa terisi',
                description: _profile.canExport
                    ? 'Nama, universitas, dan periode magang sudah diisi.'
                    : 'Lengkapi identitas mahasiswa dan periode magang.',
                isDone: _profile.canExport,
              ),
              const SizedBox(height: 10),
              ChecklistTile(
                title: 'Ada aktivitas harian',
                description: _entries.isEmpty
                    ? 'Belum ada catatan aktivitas untuk diekspor.'
                    : '${_entries.length} aktivitas siap dimasukkan ke CSV.',
                isDone: _entries.isNotEmpty,
              ),
              const SizedBox(height: 10),
              ChecklistTile(
                title: 'Mode offline aktif',
                description:
                    'Data disimpan lokal di perangkat dan tidak perlu internet untuk dipakai.',
                isDone: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ResponsiveWrap(
          children: [
            QuickActionCard(
              icon: _isSaving ? Icons.hourglass_top_rounded : Icons.picture_as_pdf_rounded,
              tone: const Color(0xFFDC2626),
              title: 'Simpan PDF',
              description: 'Laporan resmi format PDF, rapi untuk dosen/pembimbing.',
              onTap: _isSaving ? () {} : _savePdfOnly,
            ),
            QuickActionCard(
              icon: Icons.share_rounded,
              tone: const Color(0xFFDC2626),
              title: 'Bagikan PDF',
              description: 'Kirim file PDF ke dosen via WhatsApp/Email.',
              onTap: _isSaving ? () {} : _sharePdf,
            ),
            QuickActionCard(
              icon: _isSaving ? Icons.hourglass_top_rounded : Icons.save_alt_rounded,
              tone: const Color(0xFF0F766E),
              title: 'Simpan CSV',
              description: 'Data mentah CSV untuk diolah lebih lanjut di Excel.',
              onTap: _isSaving ? () {} : _saveCsvOnly,
            ),
            QuickActionCard(
              icon: Icons.share_rounded,
              tone: const Color(0xFF1D4ED8),
              title: 'Bagikan CSV',
              description: 'Kirim CSV ke dosen atau admin.',
              onTap: _isSaving ? () {} : _shareCsv,
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Import & Backup Section
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Import & Backup',
                subtitle:
                    'Impor data dari CSV, backup semua data ke ZIP, atau pulihkan dari backup sebelumnya.',
              ),
              const SizedBox(height: 12),
              ResponsiveWrap(
                children: [
                  QuickActionCard(
                    icon: Icons.upload_file_rounded,
                    tone: const Color(0xFF7C3AED),
                    title: 'Import CSV',
                    description: 'Masukkan data aktivitas dari file CSV ke aplikasi.',
                    onTap: _importCsvData,
                  ),
                  QuickActionCard(
                    icon: Icons.backup_rounded,
                    tone: const Color(0xFF0369A1),
                    title: 'Backup Data',
                    description: 'Simpan semua data (aktivitas & profil) ke file ZIP.',
                    onTap: _backupData,
                  ),
                  QuickActionCard(
                    icon: Icons.restore_rounded,
                    tone: const Color(0xFFB45309),
                    title: 'Restore Data',
                    description: 'Pulihkan data dari file ZIP backup sebelumnya.',
                    onTap: _restoreData,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Lokasi file terakhir',
                subtitle:
                    'Path ini akan muncul setelah Anda menyimpan file CSV.',
              ),
              const SizedBox(height: 12),
              Text(
                _lastExportPath ?? 'Belum ada file yang dibuat.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Dashboard Helper Widgets ──────────────────────────────────────────────

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final intVal = int.tryParse(value) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedCounter(
          value: intVal,
          duration: const Duration(milliseconds: 1000),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Template Picker Sheet ───────────────────────────────────────────────

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet({required this.templates});
  final List<ActivityTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Quick-Add Template',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih template untuk menambah aktivitas dengan cepat.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final tpl = templates[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tpl.category.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tpl.category.icon, color: tpl.category.color, size: 20),
                  ),
                  title: Text(tpl.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${tpl.category.label} · ${tpl.defaultDurationMinutes} min'),
                  trailing: const Icon(Icons.add_circle_outline_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.15),
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(tpl),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({
    required this.entry,
    required this.onTap,
    this.is24Hour = true,
  });
  final ActivityEntry entry;
  final VoidCallback onTap;
  final bool is24Hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: theme.cardTheme.shape is RoundedRectangleBorder
              ? Border.fromBorderSide((theme.cardTheme.shape as RoundedRectangleBorder).side)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${entry.date.day}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    '${formatDate(entry.date, includeWeekday: true)} · ${formatMinutes(entry.startMinutes, is24Hour: is24Hour)}–${formatMinutes(entry.endMinutes, is24Hour: is24Hour)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (entry.imagePaths.isNotEmpty) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_rounded, size: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.imagePaths.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

