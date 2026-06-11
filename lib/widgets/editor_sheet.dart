import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../helpers/helpers.dart';
import '../widgets/layout_widgets_extras.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';

class ActivityEditorSheet extends StatefulWidget {
  const ActivityEditorSheet({
    super.key,
    this.initialEntry,
    required this.is24Hour,
  });

  final ActivityEntry? initialEntry;
  final bool is24Hour;

  @override
  State<ActivityEditorSheet> createState() => _ActivityEditorSheetState();
}

class _ActivityEditorSheetState extends State<ActivityEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _activityController;
  late final TextEditingController _tagController;

  late DateTime _selectedDate;
  late int _startMinutes;
  late int _endMinutes;
  late ActivityCategory _selectedCategory;
  late List<String> _tags;
  List<String> _imagePaths = [];
  Timer? _autoSaveTimer;
  bool _hasDraft = false;
  final TimerService _timerService = TimerService();
  bool _timerActive = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _activityController = TextEditingController(text: entry?.activity ?? '');
    _tagController = TextEditingController();
    _selectedDate = dateOnly(entry?.date ?? DateTime.now());
    _startMinutes = entry?.startMinutes ?? 8 * 60;
    _endMinutes = entry?.endMinutes ?? 16 * 60;
    _selectedCategory = entry?.category ?? ActivityCategory.other;
    _tags = List<String>.from(entry?.tags ?? []);
    _imagePaths = List<String>.from(entry?.imagePaths ?? []);
    
    // Check for draft (only for new entries, not edits)
    if (entry == null) {
      _checkForDraft();
    }
    
    // Start auto-save timer (every 10 seconds)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveDraft();
    });
  }

  @override
  void dispose() {
    _activityController.dispose();
    _tagController.dispose();
    _autoSaveTimer?.cancel();
    if (_timerActive) _timerService.stop();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_timerService.isRunning) {
        _timerService.stop();
        _timerActive = false;
        // Auto-fill duration based on elapsed time
        final elapsedMinutes = _timerService.elapsedMinutes;
        if (elapsedMinutes > 0) {
          _endMinutes = (_startMinutes + elapsedMinutes).clamp(0, 24 * 60);
        }
      } else {
        _timerService.reset();
        _timerService.start();
        _timerActive = true;
      }
    });
  }

  void _stopAndApplyTimer() {
    if (_timerService.isRunning) {
      _timerService.stop();
      final elapsedMinutes = _timerService.elapsedMinutes;
      if (elapsedMinutes > 0) {
        setState(() {
          _endMinutes = (_startMinutes + elapsedMinutes).clamp(0, 24 * 60);
        });
      }
      setState(() => _timerActive = false);
    }
  }

  Future<void> _checkForDraft() async {
    final storage = LocalStorageService();
    final draft = await storage.loadDraft();
    if (draft == null || !mounted) return;
    
    final activity = draft['activity'] as String? ?? '';
    if (activity.isEmpty) return;
    
    _hasDraft = true;
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Draft Tersimpan'),
        content: Text('Ada draft tersimpan: "$activity". Pulihkan?'),
        actions: [
          TextButton(
            onPressed: () {
              storage.clearDraft();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Buang'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    
    if (restore == true && mounted) {
      setState(() {
        _activityController.text = activity;
        _selectedDate = DateTime.tryParse(draft['date'] as String? ?? '') ?? _selectedDate;
        _startMinutes = draft['startMinutes'] as int? ?? _startMinutes;
        _endMinutes = draft['endMinutes'] as int? ?? _endMinutes;
        _selectedCategory = ActivityCategory.values.firstWhere(
          (e) => e.name == draft['category'],
          orElse: () => _selectedCategory,
        );
        _tags = (draft['tags'] as List<dynamic>?)?.whereType<String>().toList() ?? _tags;
      });
    }
  }

  Future<void> _saveDraft() async {
    final activity = _activityController.text.trim();
    if (activity.isEmpty && widget.initialEntry == null) return;
    
    final storage = LocalStorageService();
    await storage.saveDraft({
      'activity': activity,
      'date': _selectedDate.toIso8601String(),
      'startMinutes': _startMinutes,
      'endMinutes': _endMinutes,
      'category': _selectedCategory.name,
      'tags': _tags,
    });
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (!mounted || selectedDate == null) {
      return;
    }
    setState(() {
      _selectedDate = dateOnly(selectedDate);
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = minutesToTimeOfDay(
      isStart ? _startMinutes : _endMinutes,
    );
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: widget.is24Hour),
          child: child!,
        );
      },
    );
    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() {
      final value = selectedTime.hour * 60 + selectedTime.minute;
      if (isStart) {
        _startMinutes = value;
      } else {
        _endMinutes = value;
      }
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);
    if (images.isEmpty || !mounted) return;
    setState(() {
      // Limit to 5 total images
      final combined = [..._imagePaths, ...images.map((x) => x.path)];
      _imagePaths = combined.take(5).toList();
    });
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (_endMinutes <= _startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam keluar harus lebih besar dari jam masuk.'),
        ),
      );
      return;
    }
    
    // Copy images to app directory
    final storage = LocalStorageService();
    final List<String> finalImagePaths = [];
    for (final path in _imagePaths) {
       if (path.contains('images/') || path.contains('images\\')) {
           finalImagePaths.add(path);
       } else {
           final newPath = await storage.saveImageInApp(path);
           finalImagePaths.add(newPath);
       }
    }

    final entry = ActivityEntry(
      id:
          widget.initialEntry?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate,
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
      activity: _activityController.text.trim(),
      imagePaths: finalImagePaths,
      category: _selectedCategory,
      tags: _tags,
    );

    if (mounted) {
      // Clear draft on successful save
      final storage = LocalStorageService();
      await storage.clearDraft();
      if (mounted) Navigator.of(context).pop(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return SheetContainer(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialEntry == null
                      ? 'Tambah aktivitas'
                      : 'Edit aktivitas',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hari akan mengikuti tanggal yang dipilih.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tanggal aktivitas',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(formatDate(_selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: weekdayName(_selectedDate),
                        enabled: false,
                        decoration: const InputDecoration(labelText: 'Hari'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Jam kegiatan',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isStart: true),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(
                          'Masuk ${formatMinutes(_startMinutes, is24Hour: widget.is24Hour)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isStart: false),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          'Keluar ${formatMinutes(_endMinutes, is24Hour: widget.is24Hour)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // ── Timer / Stopwatch Section ─────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Timer Kerja',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: _timerService,
                      builder: (ctx, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_timerService.isRunning)
                              Text(
                                _timerService.formattedTime,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFDC2626),
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _toggleTimer,
                              icon: Icon(
                                _timerService.isRunning
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              tooltip: _timerService.isRunning ? 'Stop' : 'Start',
                              style: IconButton.styleFrom(
                                backgroundColor: _timerService.isRunning
                                    ? const Color(0xFFDC2626).withOpacity(0.15)
                                    : null,
                                foregroundColor: _timerService.isRunning
                                    ? const Color(0xFFDC2626)
                                    : null,
                              ),
                            ),
                            if (_timerService.elapsedSeconds > 0 && !_timerService.isRunning)
                              IconButton(
                                onPressed: () {
                                  _timerService.reset();
                                  setState(() => _timerActive = false);
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                tooltip: 'Reset',
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                if (_timerActive || _timerService.elapsedSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _timerActive
                          ? 'Timer berjalan... Stop untuk mengisi jam keluar otomatis.'
                          : 'Durasi tercatat: ${_timerService.elapsedMinutes} menit.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Kategori kegiatan',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButton<ActivityCategory>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: ActivityCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, color: category.color, size: 20),
                          const SizedBox(width: 8),
                          Text(category.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newCategory) {
                    if (newCategory != null) {
                      setState(() => _selectedCategory = newCategory);
                    }
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _activityController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Uraian kegiatan',
                    hintText:
                        'Contoh: Membuat halaman login, meeting dengan mentor, atau menulis laporan harian.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Uraian kegiatan wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tag / Label',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (_tags.length < 5)
                      TextButton.icon(
                        onPressed: () {
                          _addTag();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tambah tag'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          hintText: 'Ketik tag dan tekan tambah',
                          suffixIcon: _tagController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.check_circle),
                                  onPressed: _addTag,
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < _tags.length; i++)
                        Chip(
                          label: Text(_tags[i]),
                          onDeleted: () => _removeTag(i),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                // ── Photo Section ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lampiran foto',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (_imagePaths.length < 5)
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: const Text('Tambah foto'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _imagePaths.isEmpty
                      ? 'Opsional. Maksimal 5 foto per aktivitas.'
                      : '${_imagePaths.length}/5 foto ditambahkan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                if (_imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagePaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final path = _imagePaths[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(
                                    path,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                  : Image.file(
                                    File(path),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Simpan aktivitas'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

