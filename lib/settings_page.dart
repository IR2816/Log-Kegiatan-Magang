import 'package:flutter/material.dart';
import 'models.dart';
import 'layout_widgets_extras.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onEditProfile,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return SheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Tentang'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Log Magang Academic'),
            subtitle: const Text('Versi 1.1.0 - Scholarly Edition'),
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
