import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark }

// Database versioning untuk migrasi data yang aman
const int CURRENT_DB_VERSION = 3;

enum ActivityCategory {
  rapat,      // Rapat / Meeting
  coding,     // Coding / Development
  training,   // Training / Learning
  testing,    // Testing / QA
  design,     // Design / UI
  documentation, // Dokumentasi
  other;      // Lainnya

  String get label => {
    ActivityCategory.rapat: 'Rapat',
    ActivityCategory.coding: 'Coding',
    ActivityCategory.training: 'Training',
    ActivityCategory.testing: 'Testing',
    ActivityCategory.design: 'Design',
    ActivityCategory.documentation: 'Dokumentasi',
    ActivityCategory.other: 'Lainnya',
  }[this] ?? 'Lainnya';

  Color get color => {
    ActivityCategory.rapat: Colors.blue,
    ActivityCategory.coding: Colors.purple,
    ActivityCategory.training: Colors.green,
    ActivityCategory.testing: Colors.orange,
    ActivityCategory.design: Colors.pink,
    ActivityCategory.documentation: Colors.amber,
    ActivityCategory.other: Colors.grey,
  }[this] ?? Colors.grey;

  IconData get icon => {
    ActivityCategory.rapat: Icons.people,
    ActivityCategory.coding: Icons.code,
    ActivityCategory.training: Icons.school,
    ActivityCategory.testing: Icons.bug_report,
    ActivityCategory.design: Icons.palette,
    ActivityCategory.documentation: Icons.description,
    ActivityCategory.other: Icons.more_horiz,
  }[this] ?? Icons.more_horiz;
}

enum MoodLevel {
  veryBad,    // 😞
  bad,        // 😐
  neutral,    // 😊
  good,       // 😄
  veryGood;   // 🤩

  String get emoji => {
    MoodLevel.veryBad: '😞',
    MoodLevel.bad: '😐',
    MoodLevel.neutral: '😊',
    MoodLevel.good: '😄',
    MoodLevel.veryGood: '🤩',
  }[this] ?? '😊';

  String get label => {
    MoodLevel.veryBad: 'Sangat Buruk',
    MoodLevel.bad: 'Buruk',
    MoodLevel.neutral: 'Biasa Saja',
    MoodLevel.good: 'Bagus',
    MoodLevel.veryGood: 'Sangat Bagus',
  }[this] ?? 'Biasa Saja';
}

@immutable
class DailyReflection {
  const DailyReflection({
    required this.date,
    required this.mood,
    this.reflection = '',
    this.lessonsLearned = '',
  });

  final DateTime date;
  final MoodLevel mood;
  final String reflection;
  final String lessonsLearned;

  DailyReflection copyWith({
    DateTime? date,
    MoodLevel? mood,
    String? reflection,
    String? lessonsLearned,
  }) {
    return DailyReflection(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      reflection: reflection ?? this.reflection,
      lessonsLearned: lessonsLearned ?? this.lessonsLearned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'mood': mood.name,
      'reflection': reflection,
      'lessonsLearned': lessonsLearned,
    };
  }

  factory DailyReflection.fromMap(Map<String, dynamic> map) {
    return DailyReflection(
      date: DateTime.tryParse((map['date'] ?? '') as String) ?? DateTime.now(),
      mood: MoodLevel.values.firstWhere(
        (e) => e.name == map['mood'],
        orElse: () => MoodLevel.neutral,
      ),
      reflection: (map['reflection'] ?? '') as String,
      lessonsLearned: (map['lessonsLearned'] ?? '') as String,
    );
  }
}

@immutable
class InternshipProfile {
  const InternshipProfile({
    required this.studentName,
    required this.studentId,
    required this.university,
    required this.internshipPlace,
    required this.startDate,
    required this.endDate,
    this.universityLogoPath,
    this.profilePicturePath,
  });

  const InternshipProfile.empty()
    : studentName = '',
      studentId = '',
      university = '',
      internshipPlace = '',
      startDate = null,
      endDate = null,
      universityLogoPath = null,
      profilePicturePath = null;

  final String studentName;
  final String studentId;
  final String university;
  final String internshipPlace;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? universityLogoPath;
  final String? profilePicturePath;

  bool get isEmpty =>
      studentName.isEmpty &&
      studentId.isEmpty &&
      university.isEmpty &&
      internshipPlace.isEmpty &&
      startDate == null &&
      endDate == null;

  bool get canExport =>
      studentName.trim().isNotEmpty &&
      university.trim().isNotEmpty &&
      startDate != null &&
      endDate != null;

  InternshipProfile copyWith({
    String? studentName,
    String? studentId,
    String? university,
    String? internshipPlace,
    DateTime? startDate,
    DateTime? endDate,
    String? universityLogoPath,
    String? profilePicturePath,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return InternshipProfile(
      studentName: studentName ?? this.studentName,
      studentId: studentId ?? this.studentId,
      university: university ?? this.university,
      internshipPlace: internshipPlace ?? this.internshipPlace,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      universityLogoPath: universityLogoPath ?? this.universityLogoPath,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentName': studentName,
      'studentId': studentId,
      'university': university,
      'internshipPlace': internshipPlace,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'universityLogoPath': universityLogoPath,
      'profilePicturePath': profilePicturePath,
    };
  }

  factory InternshipProfile.fromMap(Map<String, dynamic> map) {
    return InternshipProfile(
      studentName: (map['studentName'] ?? '') as String,
      studentId: (map['studentId'] ?? '') as String,
      university: (map['university'] ?? '') as String,
      internshipPlace: (map['internshipPlace'] ?? '') as String,
      startDate: map['startDate'] == null
          ? null
          : DateTime.tryParse(map['startDate'] as String),
      endDate: map['endDate'] == null
          ? null
          : DateTime.tryParse(map['endDate'] as String),
      universityLogoPath: map['universityLogoPath'] as String?,
      profilePicturePath: map['profilePicturePath'] as String?,
    );
  }
}

@immutable
class ActivityTemplate {
  const ActivityTemplate({
    required this.id,
    required this.name,
    required this.category,
    this.defaultDurationMinutes = 60,
    this.description = '',
  });

  final String id;
  final String name;
  final ActivityCategory category;
  final int defaultDurationMinutes;
  final String description;

  ActivityTemplate copyWith({
    String? id,
    String? name,
    ActivityCategory? category,
    int? defaultDurationMinutes,
    String? description,
  }) {
    return ActivityTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      defaultDurationMinutes: defaultDurationMinutes ?? this.defaultDurationMinutes,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'defaultDurationMinutes': defaultDurationMinutes,
      'description': description,
    };
  }

  factory ActivityTemplate.fromMap(Map<String, dynamic> map) {
    return ActivityTemplate(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      category: ActivityCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ActivityCategory.other,
      ),
      defaultDurationMinutes: (map['defaultDurationMinutes'] ?? 60) as int,
      description: (map['description'] ?? '') as String,
    );
  }
}

@immutable
class AppBadge {
  const AppBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;
  final String icon; // emoji
  final DateTime unlockedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'unlockedAt': unlockedAt.toIso8601String(),
    };
  }

  factory AppBadge.fromMap(Map<String, dynamic> map) {
    return AppBadge(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      icon: (map['icon'] ?? '') as String,
      unlockedAt: DateTime.tryParse((map['unlockedAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}

@immutable
class AppSettings {
  const AppSettings({
    this.use24HourFormat = true,
    this.themeMode = AppThemeMode.system,
    this.reminderEnabled = false,
    this.pinEnabled = false,
    this.pinCode = '',
  });

  final bool use24HourFormat;
  final AppThemeMode themeMode;
  final bool reminderEnabled;
  final bool pinEnabled;
  final String pinCode;

  AppSettings copyWith({
    bool? use24HourFormat,
    AppThemeMode? themeMode,
    bool? reminderEnabled,
    bool? pinEnabled,
    String? pinCode,
  }) {
    return AppSettings(
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      themeMode: themeMode ?? this.themeMode,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinCode: pinCode ?? this.pinCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'use24HourFormat': use24HourFormat,
      'themeMode': themeMode.name,
      'reminderEnabled': reminderEnabled,
      'pinEnabled': pinEnabled,
      'pinCode': pinCode,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      use24HourFormat: (map['use24HourFormat'] ?? true) as bool,
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == map['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      reminderEnabled: (map['reminderEnabled'] ?? false) as bool,
      pinEnabled: (map['pinEnabled'] ?? false) as bool,
      pinCode: (map['pinCode'] ?? '') as String,
    );
  }
}

@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.activity,
    this.imagePaths = const [],
    this.category = ActivityCategory.other,
    this.tags = const [],
    this.locationLat,
    this.locationLng,
    this.locationName,
  });

  final String id;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final String activity;
  final List<String> imagePaths;
  final ActivityCategory category;
  final List<String> tags; // Tag custom, e.g., ["urgent", "important"]
  final double? locationLat;
  final double? locationLng;
  final String? locationName;

  double get durationHours {
    final minutes = (endMinutes - startMinutes).clamp(0, 24 * 60);
    return minutes / 60;
  }

  ActivityEntry copyWith({
    String? id,
    DateTime? date,
    int? startMinutes,
    int? endMinutes,
    String? activity,
    List<String>? imagePaths,
    ActivityCategory? category,
    List<String>? tags,
    double? locationLat,
    double? locationLng,
    String? locationName,
    bool clearLocation = false,
  }) {
    return ActivityEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      activity: activity ?? this.activity,
      imagePaths: imagePaths ?? this.imagePaths,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      locationLat: clearLocation ? null : (locationLat ?? this.locationLat),
      locationLng: clearLocation ? null : (locationLng ?? this.locationLng),
      locationName: clearLocation ? null : (locationName ?? this.locationName),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'activity': activity,
      'imagePaths': imagePaths,
      'category': category.name,
      'tags': tags,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationName': locationName,
    };
  }

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    final rawImages = map['imagePaths'] as List<dynamic>? ?? const [];
    final rawTags = map['tags'] as List<dynamic>? ?? const [];
    return ActivityEntry(
      id: (map['id'] ?? '') as String,
      date: DateTime.tryParse((map['date'] ?? '') as String) ?? DateTime.now(),
      startMinutes: (map['startMinutes'] ?? 0) as int,
      endMinutes: (map['endMinutes'] ?? 0) as int,
      activity: (map['activity'] ?? '') as String,
      imagePaths: rawImages.whereType<String>().toList(),
      category: ActivityCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ActivityCategory.other,
      ),
      tags: rawTags.whereType<String>().toList(),
      locationLat: (map['locationLat'] as num?)?.toDouble(),
      locationLng: (map['locationLng'] as num?)?.toDouble(),
      locationName: map['locationName'] as String?,
    );
  }
}

@immutable
class AppData {
  const AppData({
    required this.profile,
    required this.entries,
    this.settings = const AppSettings(),
    this.dbVersion = CURRENT_DB_VERSION,
    this.reflections = const [],
    this.templates = const [],
    this.badges = const [],
  });

  const AppData.empty()
    : profile = const InternshipProfile.empty(),
      entries = const [],
      settings = const AppSettings(),
      dbVersion = CURRENT_DB_VERSION,
      reflections = const [],
      templates = const [],
      badges = const [];

  final InternshipProfile profile;
  final List<ActivityEntry> entries;
  final AppSettings settings;
  final int dbVersion; // Untuk tracking migrasi database
  final List<DailyReflection> reflections;
  final List<ActivityTemplate> templates;
  final List<AppBadge> badges;

  AppData copyWith({
    InternshipProfile? profile,
    List<ActivityEntry>? entries,
    AppSettings? settings,
    int? dbVersion,
    List<DailyReflection>? reflections,
    List<ActivityTemplate>? templates,
    List<AppBadge>? badges,
  }) {
    return AppData(
      profile: profile ?? this.profile,
      entries: entries ?? this.entries,
      settings: settings ?? this.settings,
      dbVersion: dbVersion ?? this.dbVersion,
      reflections: reflections ?? this.reflections,
      templates: templates ?? this.templates,
      badges: badges ?? this.badges,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dbVersion': dbVersion,
      'profile': profile.toMap(),
      'entries': entries.map((entry) => entry.toMap()).toList(),
      'settings': settings.toMap(),
      'reflections': reflections.map((r) => r.toMap()).toList(),
      'templates': templates.map((t) => t.toMap()).toList(),
      'badges': badges.map((b) => b.toMap()).toList(),
    };
  }

  factory AppData.fromMap(Map<String, dynamic> map) {
    final rawEntries = (map['entries'] as List<dynamic>? ?? const []);
    final rawReflections = (map['reflections'] as List<dynamic>? ?? const []);
    final rawTemplates = (map['templates'] as List<dynamic>? ?? const []);
    final rawBadges = (map['badges'] as List<dynamic>? ?? const []);
    int version = (map['dbVersion'] ?? 1) as int;

    // AUTO MIGRATION: dari v1 ke v2 (tambah kategori ke entry lama)
    // dari v2 ke v3 (tambah location fields, templates, badges)
    // Note: use Map<String, dynamic>.from() to handle LinkedMap on web
    List<ActivityEntry> migratedEntries = rawEntries
        .whereType<Map>()
        .map((e) => ActivityEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return AppData(
      profile:
          map['profile'] is Map
              ? InternshipProfile.fromMap(Map<String, dynamic>.from(map['profile'] as Map))
              : const InternshipProfile.empty(),
      entries: migratedEntries,
      settings:
          map['settings'] is Map
              ? AppSettings.fromMap(Map<String, dynamic>.from(map['settings'] as Map))
              : const AppSettings(),
      dbVersion: version,
      reflections:
          rawReflections
              .whereType<Map>()
              .map((e) => DailyReflection.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
      templates:
          rawTemplates
              .whereType<Map>()
              .map((e) => ActivityTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
      badges:
          rawBadges
              .whereType<Map>()
              .map((e) => AppBadge.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }
}
