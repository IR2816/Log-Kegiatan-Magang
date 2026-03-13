import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers.dart';
import 'layout_widgets_extras.dart';
import 'models.dart';

class ProfileEditorSheet extends StatefulWidget {
  const ProfileEditorSheet({super.key, required this.initialProfile});

  final InternshipProfile initialProfile;

  @override
  State<ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _universityController;
  late final TextEditingController _internshipPlaceController;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _logoPath;
  String? _profilePicPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialProfile.studentName,
    );
    _studentIdController = TextEditingController(
      text: widget.initialProfile.studentId,
    );
    _universityController = TextEditingController(
      text: widget.initialProfile.university,
    );
    _internshipPlaceController = TextEditingController(
      text: widget.initialProfile.internshipPlace,
    );
    _startDate = widget.initialProfile.startDate;
    _endDate = widget.initialProfile.endDate;
    _logoPath = widget.initialProfile.universityLogoPath;
    _profilePicPath = widget.initialProfile.profilePicturePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _universityController.dispose();
    _internshipPlaceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfilePic) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        if (isProfilePic) {
          _profilePicPath = image.path;
        } else {
          _logoPath = image.path;
        }
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate =
        (isStart ? _startDate : _endDate) ?? dateOnly(DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (!mounted || selectedDate == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDate = dateOnly(selectedDate);
      } else {
        _endDate = dateOnly(selectedDate);
      }
    });
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal awal dan akhir magang wajib diisi.'),
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal akhir magang tidak boleh lebih awal.'),
        ),
      );
      return;
    }

    final profile = InternshipProfile(
      studentName: _nameController.text.trim(),
      studentId: _studentIdController.text.trim(),
      university: _universityController.text.trim(),
      internshipPlace: _internshipPlaceController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      universityLogoPath: _logoPath,
      profilePicturePath: _profilePicPath,
    );

    Navigator.of(context).pop(profile);
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
                  'Isi profil magang',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Data ini dipakai untuk identitas laporan dan file ekspor CSV.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Photo Pickers Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Profile Picture
                    GestureDetector(
                      onTap: () => _pickImage(true),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _profilePicPath != null
                                    ? (kIsWeb
                                        ? Image.network(_profilePicPath!, fit: BoxFit.cover)
                                        : Image.file(File(_profilePicPath!), fit: BoxFit.cover))
                                    : Icon(
                                      Icons.person_rounded,
                                      size: 40,
                                      color: theme.colorScheme.primary.withOpacity(0.5),
                                    ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Foto Profil', style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ),
                    
                    // University Logo
                    GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.secondary.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _logoPath != null
                                    ? (kIsWeb
                                        ? Image.network(_logoPath!, fit: BoxFit.cover)
                                        : Image.file(File(_logoPath!), fit: BoxFit.cover))
                                    : Icon(
                                      Icons.school_rounded,
                                      size: 40,
                                      color: theme.colorScheme.secondary.withOpacity(0.5),
                                    ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_photo_alternate_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Logo Kampus', style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama mahasiswa',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama mahasiswa wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentIdController,
                  decoration: const InputDecoration(
                    labelText: 'NIM / Nomor induk',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _universityController,
                  decoration: const InputDecoration(labelText: 'Universitas'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Universitas wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _internshipPlaceController,
                  decoration: const InputDecoration(
                    labelText: 'Tempat magang / instansi',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Periode magang',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: true),
                        icon: const Icon(Icons.event_available_rounded),
                        label: Text(
                          _startDate == null
                              ? 'Tanggal mulai'
                              : formatDate(_startDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: false),
                        icon: const Icon(Icons.event_busy_rounded),
                        label: Text(
                          _endDate == null
                              ? 'Tanggal selesai'
                              : formatDate(_endDate!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Simpan profil'),
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
