import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../screens/customers_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/follow_up_list_screen.dart';
import '../screens/more_screen.dart';
import '../screens/pdf_report_screen.dart';
import '../screens/settings_screen.dart';
import '../services/customer_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/add_customer_bottom_sheet.dart';

/// Central navigation shell that dynamically switches between
/// a premium bottom navigation bar (mobile) and a sidebar (tablet/desktop).
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  void _openAddCustomerForm() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      // Show as a responsive dialog on desktop
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 850),
            child: const AddCustomerBottomSheet(),
          ),
        ),
      );
    } else {
      // Show as bottom sheet on mobile
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => const AddCustomerBottomSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768; // 768px breakpoint for sidebar

    final desktopPages = [
      const DashboardScreen(),
      const CustomersScreen(),
      const SettingsScreen(),
      const MoreScreen(),
      const FollowUpListScreen(
        initialFilter: SortMode.followUpsToday,
        title: 'Follow-ups',
        isInline: true,
      ),
      PdfReportScreen(
        customers: service.customers,
        totalCustomers: service.totalCustomers,
        bookedCustomers: service.bookedCustomers,
        registrationCompleted: service.registrationCompleted,
        isInline: true,
      ),
    ];

    final mobilePages = [
      const DashboardScreen(),
      const CustomersScreen(),
      const SettingsScreen(),
      const MoreScreen(),
    ];

    // Safety check for index out of bounds when switching layouts
    if (!isDesktop && _selectedIndex > 3) {
      _selectedIndex = 0;
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Left sidebar
            _buildSidebar(width),
            // Divider
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
            // Dynamic content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: desktopPages,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: mobilePages,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }
  }

  // ─── Desktop/Tablet Left Sidebar ────────────────────────────────
  Widget _buildSidebar(double screenWidth) {
    final showExtended = screenWidth >= 1024; // Show names if width is large

    return Container(
      width: showExtended ? 260 : 80,
      color: AppColors.primaryDark,
      child: Column(
        children: [
          // Branding Header
          const SizedBox(height: 24),
          if (showExtended)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.apartment_rounded,
                        color: AppColors.gold,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            )
          else
            Image.asset(
              AppConstants.logoAsset,
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.apartment_rounded,
                color: AppColors.gold,
                size: 24,
              ),
            ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Main Tabs
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _sidebarItem(0, Icons.dashboard_rounded, 'Dashboard', showExtended),
                _sidebarItem(1, Icons.people_rounded, 'Customers', showExtended),
                const SizedBox(height: 12),
                
                // Centered prominent Add Button in sidebar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: showExtended
                      ? ElevatedButton.icon(
                          onPressed: _openAddCustomerForm,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Add Customer',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.primary,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                        )
                      : FloatingActionButton(
                          onPressed: _openAddCustomerForm,
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.primary,
                          elevation: 2,
                          mini: true,
                          child: const Icon(Icons.add_rounded, size: 20),
                        ),
                ),
                const SizedBox(height: 16),

                _sidebarItem(4, Icons.notifications_active_rounded, 'Follow-ups', showExtended),
                _sidebarItem(5, Icons.picture_as_pdf_rounded, 'Reports', showExtended),
                _sidebarItem(2, Icons.settings_rounded, 'Settings', showExtended),
                _sidebarItem(3, Icons.more_horiz_rounded, 'More', showExtended),
              ],
            ),
          ),

          // Footer Profile / Branch information
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _buildSidebarFooter(showExtended),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, bool extended) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? AppColors.gold : Colors.white70;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => setState(() => _selectedIndex = index),
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        tileColor: isSelected ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
        leading: Icon(icon, color: color, size: 20),
        title: extended
            ? Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        horizontalTitleGap: 12,
        minLeadingWidth: 20,
      ),
    );
  }

  Widget _buildSidebarFooter(bool extended) {
    if (!extended) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white10,
        child: ClipOval(
          child: Image.asset(
            AppConstants.photoAsset,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.person_rounded,
              color: AppColors.gold,
              size: 20,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white10,
            child: ClipOval(
              child: Image.asset(
                AppConstants.photoAsset,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.gmName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppConstants.branch,
                  style: GoogleFonts.poppins(
                    color: AppColors.textOnDarkMuted,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile Bottom Navigation Bar ──────────────────────────────
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _mobileNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Dashboard'),
                  _mobileNavItem(1, Icons.people_outline_rounded, Icons.people_rounded, 'Customers'),
                  const SizedBox(width: 60), // Space for floating button
                  _mobileNavItem(2, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
                  _mobileNavItem(3, Icons.more_horiz_outlined, Icons.more_horiz_rounded, 'More'),
                ],
              ),
              Positioned(
                top: -24,
                child: GestureDetector(
                  onTap: _openAddCustomerForm,
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.fab,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                child: Text(
                  'Add Customer',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _selectedIndex == index;
    final icon = isSelected ? solidIcon : outlineIcon;
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
               label,
               style: GoogleFonts.poppins(
                 fontSize: 10,
                 fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                 color: color,
               ),
               overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
