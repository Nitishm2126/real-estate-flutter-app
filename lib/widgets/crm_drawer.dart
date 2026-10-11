import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Professional, brand-aligned Navigation Drawer for MCP Avadi CRM.
///
/// Shows the authenticated user name, role, and branch in the header.
/// Includes a Sign Out action at the bottom.
class CRMDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CRMDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Drawer(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          // Branding Header matching the desktop sidebar layout
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            color: AppColors.primaryDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Image.asset(
                        AppConstants.logoAsset,
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.apartment_rounded,
                          color: AppColors.gold,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Real Estate CRM',
                            style: GoogleFonts.poppins(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (auth.isSignedIn) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        child: ClipOval(
                          child: Image.asset(
                            AppConstants.photoAsset,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              color: AppColors.gold,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.displayName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    auth.roleAbbr,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.gold,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    auth.displayBranch,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable navigation list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _drawerItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _drawerItem(1, Icons.people_rounded, 'Customers'),
                _drawerItem(2, Icons.calendar_month_rounded, 'Follow-ups'),
                _drawerItem(3, Icons.notifications_rounded, 'Notifications'),
                _drawerItem(7, Icons.apartment_rounded, 'Properties'),
                _drawerItem(4, Icons.settings_rounded, 'Settings'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                _drawerItem(5, Icons.person_rounded, 'Profile'),
                _drawerItem(6, Icons.more_horiz_rounded, 'More Options'),
                _drawerItem(8, Icons.info_outline_rounded, 'About MCP Avadi'),
              ],
            ),
          ),
          // Sign Out footer
          const Divider(),
          _signOutTile(context),
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: Text(
              'Designed & Developed by Nitish',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signOutTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.logout_rounded, color: AppColors.statusRed, size: 22),
      title: Text(
        'Sign Out',
        style: GoogleFonts.poppins(
          color: AppColors.statusRed,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
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
      },
    );
  }

  Widget _drawerItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    final iconColor = isSelected ? AppColors.gold : AppColors.textSecondary;
    final textColor = isSelected ? AppColors.textPrimary : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ListTile(
        onTap: () => onItemSelected(index),
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        horizontalTitleGap: 12,
        minLeadingWidth: 20,
      ),
    );
  }
}
