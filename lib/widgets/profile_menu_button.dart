import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../screens/settings_screen.dart';

class ProfileMenuButton extends StatelessWidget {
  final bool isSyncing;

  const ProfileMenuButton({super.key, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-40, 10),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.surface),
        elevation: WidgetStateProperty.all(AppShadows.card.first.blurRadius * 2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        )),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 8)),
      ),
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: ClipOval(
                  child: Image.asset(
                    AppConstants.photoAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isSyncing ? AppColors.gold : AppColors.statusBooked,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryDark, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.gmName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                AppConstants.gmTitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.branch,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        MenuItemButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text('Profile Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${AppConstants.gmName}', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Role: ${AppConstants.gmTitle}', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Branch: ${AppConstants.branch}', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
          leadingIcon: Icon(Icons.person_outline, color: AppColors.textPrimary, size: 20),
          child: Text('Profile', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
        ),
        MenuItemButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
          leadingIcon: Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 20),
          child: Text('Settings', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
        ),
        MenuItemButton(
          onPressed: () {
            showAboutDialog(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: '1.0.0',
              applicationIcon: Image.asset(AppConstants.logoAsset, width: 50, height: 50),
              applicationLegalese: '© 2026 ${AppConstants.companyFullName}',
            );
          },
          leadingIcon: Icon(Icons.info_outline, color: AppColors.textPrimary, size: 20),
          child: Text('About', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
        ),
        const Divider(),
        MenuItemButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Logout functionality will be implemented with Auth integration.', style: GoogleFonts.poppins()),
                backgroundColor: AppColors.statusRed,
              ),
            );
          },
          leadingIcon: Icon(Icons.logout, color: AppColors.statusRed, size: 20),
          child: Text('Logout', style: GoogleFonts.poppins(color: AppColors.statusRed)),
        ),
      ],
    );
  }
}
