import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/layout_widgets_extras.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onEditProfile,
    required this.onBackup,
    required this.onRestore,
    required this.onImportCsv,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onEditProfile;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onImportCsv;

  @override
  Widget build(BuildContext context) {
    return SheetContainer(
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Pengaturan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Sesuaikan tampilan dan format waktu aplikasi.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Data Mahasiswa'),
          _buildSettingTile(
            context,
            icon: Icons.badge_rounded,
            title: 'Edit Profil Magang',
            subtitle: 'Ubah nama, NIM, universitas, atau periode.',
            onTap: () {
              Navigator.pop(context);
              onEditProfile();
            },
          ),
          const Divider(height: 32),
          _buildSectionTitle(context, 'Tampilan'),
          _buildSettingTile(
            context,
            icon: Icons.brightness_6_rounded,
            title: 'Mode Tema',
            subtitle: _getThemeModeLabel(settings.themeMode),
            onTap: () => _showThemePicker(context),
          ),
          const Divider(height: 32),
          _buildSectionTitle(context, 'Format Waktu'),
          SwitchListTile(
            secondary: const Icon(Icons.schedule_rounded),
            title: const Text('Format 24 Jam'),
            subtitle: Text(
              settings.use24HourFormat
                  ? 'Contoh: 14:00'
                  : 'Contoh: 02:00 PM',
            ),
            value: settings.use24HourFormat,
            onChanged: (value) {
              onSettingsChanged(settings.copyWith(use24HourFormat: value));
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32),
          _buildSectionTitle(context, 'Notifikasi'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('Reminder Harian'),
            subtitle: Text(
              settings.reminderEnabled
                  ? 'Notifikasi harian aktif'
                  : 'Ingatkan saya untuk mengisi log',
            ),
            value: settings.reminderEnabled,
            onChanged: (value) async {
              onSettingsChanged(settings.copyWith(reminderEnabled: value));
              if (value) {
                await NotificationService.scheduleDailyReminder();
              }
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32),
          _buildSectionTitle(context, 'Keamanan'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_rounded),
            title: const Text('Kunci PIN'),
            subtitle: Text(
              settings.pinEnabled
                  ? 'Aplikasi dilindungi PIN'
                  : 'Aktifkan PIN untuk keamanan',
            ),
            value: settings.pinEnabled,
            onChanged: (value) async {
              if (value) {
                // Show create PIN dialog
                // Get context from the nearest navigator
                final ctx = Navigator.of(context).context;
                final pin = await AuthService.showCreatePinDialog(ctx);
                if (pin != null) {
                  onSettingsChanged(settings.copyWith(
                    pinEnabled: true,
                    pinCode: pin,
                  ));
                }
              } else {
                onSettingsChanged(settings.copyWith(pinEnabled: false));
              }
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32),
          _buildSectionTitle(context, 'Penyimpanan Data'),
          _buildSettingTile(
            context,
            icon: Icons.backup_rounded,
            title: 'Backup Data',
            subtitle: 'Simpan data log dan gambar ke file .zip',
            onTap: onBackup,
          ),
          _buildSettingTile(
            context,
            icon: Icons.restore_rounded,
            title: 'Restore Data',
            subtitle: 'Pulihkan data dari file .zip backup',
            onTap: onRestore,
          ),
          _buildSettingTile(
            context,
            icon: Icons.upload_file_rounded,
            title: 'Import CSV',
            subtitle: 'Masukkan data dari file .csv',
            onTap: onImportCsv,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Tentang'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Log Magang Academic'),
            subtitle: const Text('Versi 2.0.0 - Scholarly Edition'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getThemeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Ikuti Sistem';
      case AppThemeMode.light:
        return 'Mode Terang';
      case AppThemeMode.dark:
        return 'Mode Gelap';
    }
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto_rounded),
              title: const Text('Ikuti Sistem'),
              selected: settings.themeMode == AppThemeMode.system,
              onTap: () {
                onSettingsChanged(
                  settings.copyWith(themeMode: AppThemeMode.system),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode_rounded),
              title: const Text('Mode Terang'),
              selected: settings.themeMode == AppThemeMode.light,
              onTap: () {
                onSettingsChanged(
                  settings.copyWith(themeMode: AppThemeMode.light),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: const Text('Mode Gelap'),
              selected: settings.themeMode == AppThemeMode.dark,
              onTap: () {
                onSettingsChanged(
                  settings.copyWith(themeMode: AppThemeMode.dark),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

