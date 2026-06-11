import 'package:flutter/material.dart';
import '../models/models.dart';
import '../helpers/helpers.dart';
import '../widgets/layout_widgets_extras.dart';

class ReflectionSheet extends StatefulWidget {
  const ReflectionSheet({
    super.key,
    this.existingReflection,
  });

  final DailyReflection? existingReflection;

  @override
  State<ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends State<ReflectionSheet> {
  late TextEditingController _reflectionController;
  late TextEditingController _lessonsController;
  late MoodLevel _selectedMood;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReflection;
    _reflectionController = TextEditingController(text: existing?.reflection ?? '');
    _lessonsController = TextEditingController(text: existing?.lessonsLearned ?? '');
    _selectedMood = existing?.mood ?? MoodLevel.neutral;
    _selectedDate = existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    _lessonsController.dispose();
    super.dispose();
  }

  void _submit() {
    final reflection = DailyReflection(
      date: dateOnly(_selectedDate),
      mood: _selectedMood,
      reflection: _reflectionController.text.trim(),
      lessonsLearned: _lessonsController.text.trim(),
    );
    Navigator.of(context).pop(reflection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SheetContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingReflection == null
                  ? 'Refleksi Harian'
                  : 'Edit Refleksi',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Catat perasaan dan pelajaran hari ini.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Date selector
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = dateOnly(picked));
                }
              },
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(formatDate(_selectedDate, includeWeekday: true)),
            ),
            const SizedBox(height: 20),

            // Mood selector
            Text(
              'Bagaimana perasaanmu hari ini?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: MoodLevel.values.map((mood) {
                final isSelected = mood == _selectedMood;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          mood.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mood.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Reflection text
            TextFormField(
              controller: _reflectionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Refleksi hari ini',
                hintText: 'Apa yang kamu rasakan dan pikirkan hari ini?',
              ),
            ),
            const SizedBox(height: 16),

            // Lessons learned
            TextFormField(
              controller: _lessonsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Pelajaran yang didapat',
                hintText: 'Hal baru apa yang kamu pelajari?',
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Simpan refleksi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
