import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../screens/more_screen.dart';
import '../screens/settings_screen.dart';

class ProfileMenuButton extends StatelessWidget {
  final bool isSyncing;

  const ProfileMenuButton({super.key, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final name = auth.displayName;
    final roleLabel = auth.displayRole;
    final branch = auth.displayBranch;
    final roleAbbr = auth.roleAbbr;

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      roleAbbr,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (roleLabel.isNotEmpty)
                Text(
                  roleLabel,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 4),
              Text(
                branch,
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.goldDark, fontWeight: FontWeight.w600),
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
                    Text('Name: $name', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Role: ${roleLabel.isNotEmpty ? roleLabel : roleAbbr}', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Branch: $branch', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MoreScreen()));
          },
          leadingIcon: Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary, size: 20),
          child: Text('More Options', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
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
          onPressed: () => _confirmSignOut(context),
          leadingIcon: Icon(Icons.logout, color: AppColors.statusRed, size: 20),
          child: Text('Sign Out', style: GoogleFonts.poppins(color: AppColors.statusRed)),
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthService>().signOut();
            },
            child: Text('Sign Out', style: GoogleFonts.poppins(color: AppColors.statusRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
