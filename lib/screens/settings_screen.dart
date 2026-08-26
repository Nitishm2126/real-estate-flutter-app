import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/customer_service.dart';
import '../services/theme_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Professional Settings Screen organizing App, Business, Data, and About settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 160),
        children: [
          // ── APP SECTION ──────────────────────────────────────────
          _sectionHeader('APP'),
          _card([
            _switchTile(
              icon: Icons.notifications_active_rounded,
              title: 'Push Notifications',
              subtitle: 'Receive follow-up and lead reminders',
              value: _notificationsEnabled,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
                _showSnackBar('Notification preferences updated');
              },
            ),
            const Divider(),
            _switchTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Theme',
              subtitle: 'Switch application to dark colors',
              value: themeService.isDarkMode,
              onChanged: (val) {
                themeService.toggleTheme(val);
                _showSnackBar(val ? 'Dark Theme enabled' : 'Light Theme enabled');
              },
            ),
            const Divider(),
            _actionTile(
              icon: Icons.palette_rounded,
              title: 'Appearance Style',
              subtitle: 'Modern startup aesthetic',
              trailing: Text(
                'Default',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {},
            ),
          ]),

          const SizedBox(height: AppSpacing.lg),

          // ── BUSINESS SECTION ─────────────────────────────────────
          _sectionHeader('BUSINESS'),
          _card([
            _infoTile(
              icon: Icons.apartment_rounded,
              title: 'Branch Details',
              content: '${AppConstants.companyFullName}\n${AppConstants.branch}',
            ),
            const Divider(),
            _infoTile(
              icon: Icons.person_rounded,
              title: 'GM Sales Representative',
              content: '${AppConstants.gmName}\n${AppConstants.gmTitle}',
            ),
            const Divider(),
            _infoTile(
              icon: Icons.phone_android_rounded,
              title: 'Avadi Office Contact',
              content: '+91 72002 89643',
            ),
          ]),

          const SizedBox(height: AppSpacing.lg),

          // ── DATA SECTION ─────────────────────────────────────────
          _sectionHeader('DATA & CLOUD'),
          _card([
            _actionTile(
              icon: Icons.cloud_done_rounded,
              title: 'Supabase Cloud Sync',
              subtitle: 'Ensure local changes are persisted',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: service.errorMessage != null
                      ? AppColors.statusRedBg
                      : AppColors.statusBookedBg,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  service.errorMessage != null ? 'Offline' : 'Connected',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: service.errorMessage != null
                        ? AppColors.statusRed
                        : AppColors.statusBooked,
                  ),
                ),
              ),
              onTap: () async {
                await service.syncWithDatabase();
                if (service.errorMessage == null) {
                  _showSnackBar('Database successfully synchronized!');
                }
              },
            ),
            const Divider(),
            _actionTile(
              icon: Icons.refresh_rounded,
              title: 'Force Reload Schema Cache',
              subtitle: 'Re-fetch structure from Supabase',
              onTap: () async {
                await service.syncWithDatabase();
                _showSnackBar('Cache updated successfully');
              },
            ),
          ]),

          const SizedBox(height: AppSpacing.lg),

          // ── ABOUT SECTION ────────────────────────────────────────
          _sectionHeader('ABOUT'),
          _card([
            _infoTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              content: 'v1.0.0 (Production Build)',
            ),
            const Divider(),
            _infoTile(
              icon: Icons.security_rounded,
              title: 'Security Compliance',
              content: 'Supabase Native Row Level Security enabled.',
            ),
            const Divider(),
            _infoTile(
              icon: Icons.copyright_rounded,
              title: 'Copyright',
              content: '© 2026 Madras City Properties. All Rights Reserved.',
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Designed & Developed by Nitish',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets Helpers ──────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.divider,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
