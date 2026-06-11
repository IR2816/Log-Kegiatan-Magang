import '../models/models.dart';

class TemplateService {
  /// Get default templates for quick-add
  static List<ActivityTemplate> getDefaultTemplates() {
    return [
      ActivityTemplate(
        id: 'tpl_rapat_pagi',
        name: 'Rapat Pagi',
        category: ActivityCategory.rapat,
        defaultDurationMinutes: 60,
        description: 'Rapat koordinasi tim pagi hari',
      ),
      ActivityTemplate(
        id: 'tpl_coding',
        name: 'Coding Sprint',
        category: ActivityCategory.coding,
        defaultDurationMinutes: 120,
        description: 'Sesi coding/development',
      ),
      ActivityTemplate(
        id: 'tpl_training',
        name: 'Training / Workshop',
        category: ActivityCategory.training,
        defaultDurationMinutes: 120,
        description: 'Pelatihan atau workshop',
      ),
      ActivityTemplate(
        id: 'tpl_testing',
        name: 'Testing & QA',
        category: ActivityCategory.testing,
        defaultDurationMinutes: 90,
        description: 'Testing dan quality assurance',
      ),
      ActivityTemplate(
        id: 'tpl_design',
        name: 'Design Review',
        category: ActivityCategory.design,
        defaultDurationMinutes: 60,
        description: 'Review atau pembuatan desain',
      ),
      ActivityTemplate(
        id: 'tpl_dokumentasi',
        name: 'Dokumentasi',
        category: ActivityCategory.documentation,
        defaultDurationMinutes: 60,
        description: 'Menulis dokumentasi teknis',
      ),
      ActivityTemplate(
        id: 'tpl_laporan',
        name: 'Laporan Harian',
        category: ActivityCategory.documentation,
        defaultDurationMinutes: 30,
        description: 'Menulis laporan harian',
      ),
      ActivityTemplate(
        id: 'tpl_meeting_mentor',
        name: 'Meeting Mentor',
        category: ActivityCategory.rapat,
        defaultDurationMinutes: 45,
        description: 'Meeting dengan mentor/pembimbing',
      ),
    ];
  }

  /// Create an ActivityEntry from a template
  static ActivityEntry createEntryFromTemplate(
    ActivityTemplate template,
    DateTime date,
    int startMinutes, {
    String? customDescription,
  }) {
    final endMinutes = startMinutes + template.defaultDurationMinutes;
    return ActivityEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: date,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      activity: customDescription ?? (template.description.isNotEmpty
          ? template.description
          : template.name),
      category: template.category,
    );
  }

  /// Merge default templates with user custom templates
  static List<ActivityTemplate> getAllTemplates(List<ActivityTemplate> userTemplates) {
    final defaults = getDefaultTemplates();
    final defaultIds = defaults.map((t) => t.id).toSet();
    
    // User templates that aren't in defaults
    final custom = userTemplates.where((t) => !defaultIds.contains(t.id)).toList();
    
    return [...defaults, ...custom];
  }
}
