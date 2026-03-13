import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'animations.dart';
import 'editor_sheet.dart';
import 'entry_widgets.dart';
import 'helpers.dart';
import 'layout_widgets.dart';
import 'layout_widgets_extras.dart';
import 'models.dart';
import 'profile_sheet.dart';
import 'settings_page.dart';
import 'storage_service.dart';

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
  late AppSettings _settings;

  bool _isSaving = false;
  int _selectedIndex = 0;
  String? _lastExportPath;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _loadData();
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
    });
    // Sync with app-level settings
    widget.onSettingsChanged(_settings);
  }

  Future<void> _persistData({
    InternshipProfile? profile,
    List<ActivityEntry>? entries,
  }) async {
    final nextProfile = profile ?? _profile;
    final nextEntries = [...(entries ?? _entries)]..sort(compareActivities);

    setState(() {
      _profile = nextProfile;
      _entries = nextEntries;
    });

    await _storageService.save(
      AppData(profile: nextProfile, entries: nextEntries, settings: _settings),
    );
  }

  Future<void> _updateSettings(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    widget.onSettingsChanged(settings);
    await _storageService.save(
      AppData(profile: _profile, entries: _entries, settings: settings),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsPage(
        settings: _settings,
        onSettingsChanged: _updateSettings,
        onEditProfile: _openProfileEditor,
      ),
    );
  }

  double get _totalHours =>
      _entries.fold(0.0, (sum, entry) => sum + entry.durationHours);

  Widget? get _floatingActionButton {
    if (_selectedIndex == 0) {
      return FloatingActionButton.extended(
        onPressed: _openProfileEditor,
        icon: const Icon(Icons.badge_rounded),
        label: const Text('Isi profil'),
      );
    }

    if (_selectedIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: _openActivityEditor,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Tambah aktivitas'),
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
    _showMessage('Aktivitas berhasil dihapus.');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          switch (_selectedIndex) {
            0 => 'Dashboard',
            1 => 'Catatan',
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
        actions: [
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
                    _BannerStat(value: '${_entries.length}', label: 'Log'),
                    _divider(),
                    _BannerStat(value: '${_totalHours.toInt()}', label: 'Jam'),
                    _divider(),
                    _BannerStat(
                      value: _entries.isEmpty
                          ? '-'
                          : '${_entries.map((e) => e.date).toSet().length}',
                      label: 'Hari',
                    ),
                    _divider(),
                    _BannerStat(value: '$totalPhotos', label: 'Foto'),
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
        const SizedBox(height: 20),
        if (_entries.isEmpty)
          const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'Belum ada aktivitas harian',
            description:
                'Tekan tombol "Tambah aktivitas" untuk mulai mengisi log kegiatan magang.',
          )
        else
          ...buildGroupedEntryWidgets(
            context,
            _entries,
            is24Hour: _settings.use24HourFormat,
            onEdit: _openActivityEditor,
            onDelete: _deleteActivity,
          ),
      ],
    );
  }

  Widget _buildExportPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 120),
      children: [
        HeroHeader(
          eyebrow: 'Ekspor CSV',
          title: 'Offline dulu, bagikan saat perlu',
          subtitle:
              'Data tetap bisa dipakai sepenuhnya tanpa internet. Saat butuh kirim ke dosen, mentor, atau admin, simpan atau bagikan file CSV yang bisa dibuka di Excel.',
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
              icon: _isSaving
                  ? Icons.hourglass_top_rounded
                  : Icons.save_alt_rounded,
              tone: const Color(0xFF0F766E),
              title: 'Simpan CSV',
              description:
                  'Membuat file CSV di perangkat, bisa dibuka dengan Excel.',
              onTap: _isSaving ? () {} : _saveCsvOnly,
            ),
            QuickActionCard(
              icon: Icons.share_rounded,
              tone: const Color(0xFF1D4ED8),
              title: 'Bagikan CSV',
              description:
                  'Kirim file CSV lewat WhatsApp, email, atau aplikasi lain.',
              onTap: _isSaving ? () {} : _shareCsv,
            ),
          ],
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
