import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../screens/customers_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/follow_up_list_screen.dart';
import '../screens/more_screen.dart';
import '../models/notification_item.dart';
import '../screens/pdf_report_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';
import '../services/customer_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/add_customer_bottom_sheet.dart';
import '../widgets/crm_drawer.dart';

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

  void _onDrawerItemSelected(int index) {
    Navigator.pop(context); // Close drawer immediately
    
    if (index == 5) {
      // Profile maps to Settings
      setState(() => _selectedIndex = 4);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile details are managed in Settings.', style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (index == 6) {
      // About MCP Avadi
      showAboutDialog(
        context: context,
        applicationName: 'MCP Avadi CRM',
        applicationVersion: '1.0.0',
        applicationIcon: Icon(
          Icons.apartment_rounded,
          color: AppColors.primary,
          size: 32,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Madras City Properties Premium CRM for tracking and managing real estate customer leads.',
              style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768; // 768px breakpoint for sidebar

    final List<Widget> pages = [
      const DashboardScreen(),
      const CustomersScreen(),
      const FollowUpListScreen(
        initialFilter: SortMode.followUpsToday,
        title: 'Follow-ups',
        isInline: true,
      ),
      const NotificationsScreen(),
      const SettingsScreen(),
      PdfReportScreen(
        customers: service.customers,
        totalCustomers: service.totalCustomers,
        bookedCustomers: service.bookedCustomers,
        registrationCompleted: service.registrationCompleted,
        isInline: true,
      ),
      const MoreScreen(),
    ];

    // Safety check for index out of bounds when switching layouts
    if (!isDesktop && _selectedIndex > 6) {
      _selectedIndex = 0;
    }

    if (isDesktop) {
      return Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Left sidebar
            _buildSidebar(width),
            // Divider
            VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
            // Dynamic content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background,
        drawer: CRMDrawer(
          selectedIndex: _selectedIndex,
          onItemSelected: _onDrawerItemSelected,
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(context),
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
                      errorBuilder: (_, __, ___) => Icon(
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
              errorBuilder: (_, __, ___) => Icon(
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

                _sidebarItem(2, Icons.notifications_active_rounded, 'Follow-ups', showExtended),
                _sidebarItem(3, Icons.notifications_none_rounded, 'Notifications', showExtended),
                _sidebarItem(5, Icons.picture_as_pdf_rounded, 'Reports', showExtended),
                _sidebarItem(4, Icons.settings_rounded, 'Settings', showExtended),
                _sidebarItem(6, Icons.more_horiz_rounded, 'More', showExtended),
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
            errorBuilder: (_, __, ___) => Icon(
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
                errorBuilder: (_, __, ___) => Icon(
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

  // ─── Premium Glassmorphism Bottom Navigation Bar ───────────────────────
  Widget _buildBottomNavigationBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Glassmorphism styling based on theme
    final glassColor = isDark 
        ? const Color(0xFF111A15).withValues(alpha: 0.45) // Dark green/black, 35-50%
        : Colors.white.withValues(alpha: 0.55); // White, 45-60%
        
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small floating + button
        SizedBox(
          height: 48,
          width: 48,
          child: FloatingActionButton(
            heroTag: 'nav_add_customer',
            onPressed: _openAddCustomerForm,
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        // Glass Navigation
        Container(
          // Floating margins with SafeArea support built-in
          margin: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: glassColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _mobileNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard', isDark),
                    _mobileNavItem(1, Icons.people_outline_rounded, Icons.people_rounded, 'Customers', isDark),
                    _mobileNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Follow-ups', isDark),
                    _mobileNavItem(3, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Notifications', isDark),
                    _mobileNavItem(4, Icons.settings_outlined, Icons.settings_rounded, 'Settings', isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileNavItem(int index, IconData outlineIcon, IconData solidIcon, String label, bool isDark) {
    final isSelected = _selectedIndex == index;
    final icon = isSelected ? solidIcon : outlineIcon;
    
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final color = isSelected ? activeColor : inactiveColor;
    
    // Notification Badge logic
    Widget badgeOverlay(Widget child) {
      if (index != 3) return child;
      return Consumer<CustomerService>(
        builder: (context, service, _) {
          final unreadCount = NotificationItem.getNotifications(service)
              .where((n) => !service.readNotificationIds.contains(n.id)).length;
              
          if (unreadCount == 0) return child;
          
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1A2421) : Colors.white, 
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: GoogleFonts.poppins(fontSize: 8, color: AppColors.primaryDark, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: badgeOverlay(Icon(icon, color: color, size: 24)),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.8,
              child: Text(
                 label,
                 style: GoogleFonts.poppins(
                   fontSize: 10,
                   fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                   color: color,
                 ),
                 overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
