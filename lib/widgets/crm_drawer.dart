import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Professional, brand-aligned Navigation Drawer for MCP Avadi CRM.
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
            child: Row(
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
                _drawerItem(4, Icons.settings_rounded, 'Settings'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                _drawerItem(5, Icons.person_rounded, 'Profile'),
                _drawerItem(6, Icons.more_horiz_rounded, 'More Options'),
                _drawerItem(7, Icons.info_outline_rounded, 'About MCP Avadi'),
              ],
            ),
          ),
          // Subtle pinned footer matching theme colors
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Designed & Developed by Nitish',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
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
