import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers.dart';
import 'layout_widgets_extras.dart';
import 'models.dart';

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

  late DateTime _selectedDate;
  late int _startMinutes;
  late int _endMinutes;
  List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _activityController = TextEditingController(text: entry?.activity ?? '');
    _selectedDate = dateOnly(entry?.date ?? DateTime.now());
    _startMinutes = entry?.startMinutes ?? 8 * 60;
    _endMinutes = entry?.endMinutes ?? 16 * 60;
    _imagePaths = List<String>.from(entry?.imagePaths ?? []);
  }

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
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

  void _submit() {
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

    final entry = ActivityEntry(
      id:
          widget.initialEntry?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: _selectedDate,
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
      activity: _activityController.text.trim(),
      imagePaths: _imagePaths,
    );

    Navigator.of(context).pop(entry);
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
