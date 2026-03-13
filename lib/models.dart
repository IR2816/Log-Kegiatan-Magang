import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark }

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
class AppSettings {
  const AppSettings({
    this.use24HourFormat = true,
    this.themeMode = AppThemeMode.system,
  });

  final bool use24HourFormat;
  final AppThemeMode themeMode;

  AppSettings copyWith({bool? use24HourFormat, AppThemeMode? themeMode}) {
    return AppSettings(
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'use24HourFormat': use24HourFormat,
      'themeMode': themeMode.name,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      use24HourFormat: (map['use24HourFormat'] ?? true) as bool,
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == map['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
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
  });

  final String id;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final String activity;
  final List<String> imagePaths;

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
  }) {
    return ActivityEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      activity: activity ?? this.activity,
      imagePaths: imagePaths ?? this.imagePaths,
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
    };
  }

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    final rawImages = map['imagePaths'] as List<dynamic>? ?? const [];
    return ActivityEntry(
      id: (map['id'] ?? '') as String,
      date: DateTime.tryParse((map['date'] ?? '') as String) ?? DateTime.now(),
      startMinutes: (map['startMinutes'] ?? 0) as int,
      endMinutes: (map['endMinutes'] ?? 0) as int,
      activity: (map['activity'] ?? '') as String,
      imagePaths: rawImages.whereType<String>().toList(),
    );
  }
}

@immutable
class AppData {
  const AppData({
    required this.profile,
    required this.entries,
    this.settings = const AppSettings(),
  });

  const AppData.empty()
    : profile = const InternshipProfile.empty(),
      entries = const [],
      settings = const AppSettings();

  final InternshipProfile profile;
  final List<ActivityEntry> entries;
  final AppSettings settings;

  AppData copyWith({
    InternshipProfile? profile,
    List<ActivityEntry>? entries,
    AppSettings? settings,
  }) {
    return AppData(
      profile: profile ?? this.profile,
      entries: entries ?? this.entries,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profile': profile.toMap(),
      'entries': entries.map((entry) => entry.toMap()).toList(),
      'settings': settings.toMap(),
    };
  }

  factory AppData.fromMap(Map<String, dynamic> map) {
    final rawEntries = (map['entries'] as List<dynamic>? ?? const []);
    return AppData(
      profile:
          map['profile'] is Map<String, dynamic>
              ? InternshipProfile.fromMap(map['profile'] as Map<String, dynamic>)
              : const InternshipProfile.empty(),
      entries:
          rawEntries
              .whereType<Map<String, dynamic>>()
              .map(ActivityEntry.fromMap)
              .toList(),
      settings:
          map['settings'] is Map<String, dynamic>
              ? AppSettings.fromMap(map['settings'] as Map<String, dynamic>)
              : const AppSettings(),
    );
  }
}
