import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../screens/follow_up_list_screen.dart';
import '../screens/pdf_report_screen.dart';
import '../services/customer_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/add_customer_bottom_sheet.dart';
import '../widgets/recent_customer_row.dart';

/// Redesigned Premium CRM Dashboard Screen matching the mobile UI reference.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerService>().initialize();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded : Icons.check_circle_rounded,
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

  void _openAddCustomerSheet() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
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
    return Consumer<CustomerService>(
      builder: (context, service, child) {
        // Show error snackbar if needed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (service.errorMessage != null && service.errorMessage!.isNotEmpty) {
            _showSnackBar(service.errorMessage!, isError: true);
            service.clearError();
          }
        });

        // Compute 5 most recently created/updated customers
        final recentCustomers = List<Customer>.from(service.allCustomersUnfiltered)
          ..sort((a, b) {
            final aTime = a.updatedAt ?? a.createdAt ?? a.date ?? DateTime(2000);
            final bTime = b.updatedAt ?? b.createdAt ?? b.date ?? DateTime(2000);
            return bTime.compareTo(aTime); // descending
          });
        final topRecent = recentCustomers.take(5).toList();

        return Material(
          color: AppColors.background,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            strokeWidth: 2.5,
            onRefresh: () async {
              await service.syncWithDatabase();
              if (service.errorMessage == null) {
                _showSnackBar('Data Synced Successfully');
              }
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Premium Header & Welcome Card ────────────────────────
                SliverToBoxAdapter(
                  child: _HeaderAndWelcome(
                    isSyncing: service.isSyncing,
                  ),
                ),

                // ── Analytics Grid ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                    child: _AnalyticsSection(service: service),
                  ),
                ),

                // ── Recent Customers Header ──────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.sm),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_outline_rounded, size: 20, color: AppColors.textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Customers',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            _showSnackBar('Select Customers tab to view all');
                          },
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.goldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Recent Customers List ────────────────────────────
                if (service.isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                    ),
                  )
                else if (topRecent.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                        ),
                        child: Center(
                          child: Text(
                            'No customer leads registered yet.',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Column(
                            children: topRecent.map((c) => RecentCustomerRow(customer: c)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Bottom Sections: Follow-up Overview & Quick Actions ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 100),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        if (isMobile) {
                          // Mobile layout: Column
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FollowUpOverviewCard(service: service),
                              const SizedBox(height: AppSpacing.lg),
                              _QuickActionsCard(onAddCustomer: _openAddCustomerSheet),
                            ],
                          );
                        } else {
                          // Tablet/Desktop layout: Row
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 1, child: _FollowUpOverviewCard(service: service)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(flex: 1, child: _QuickActionsCard(onAddCustomer: _openAddCustomerSheet)),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header & Welcome Card
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderAndWelcome extends StatelessWidget {
  final bool isSyncing;

  const _HeaderAndWelcome({required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom AppBar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Scaffold.of(context).openDrawer();
                        },
                        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Real Estate CRM',
                            style: GoogleFonts.poppins(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Notification Bell with Badge
                      Stack(
                        children: [
                          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '3',
                                style: GoogleFonts.poppins(fontSize: 8, color: AppColors.primaryDark, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Avatar with Live indicator
                      Stack(
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // Welcome Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF135A46), Color(0xFF0C382A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.header,
                ),
                child: Stack(
                  children: [
                    // A subtle house illustration or pattern could go here. For now, an opacity container
                    Positioned(
                      right: 0,
                      bottom: 0,
                      top: 0,
                      width: 150,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.lg)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppConstants.gmName,
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConstants.gmTitle,
                            style: GoogleFonts.poppins(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Date Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Today, ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              // Live Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: AppColors.statusBooked, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Live',
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Section
// ─────────────────────────────────────────────────────────────────────────────
class _AnalyticsSection extends StatelessWidget {
  final CustomerService service;

  const _AnalyticsSection({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            InkWell(
              onTap: () {},
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.goldDark),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.goldDark, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(builder: (context, constraints) {
          final double width = constraints.maxWidth;
          int crossAxisCount = 2;
          if (width > 600) crossAxisCount = 4;

          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.85,
            ),
            children: [
              _StatCard(
                title: 'Total\nCustomers',
                value: service.totalCustomers.toString(),
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primary.withValues(alpha: 0.1),
                trendText: 'vs last month',
                isPositive: true,
                percentage: '12%',
              ),
              _StatCard(
                title: 'Today\'s\nLeads',
                value: service.todayLeads.toString(),
                icon: Icons.person_add_outlined,
                iconColor: AppColors.statusPurple,
                iconBg: AppColors.statusPurpleBg,
                trendText: 'vs yesterday',
                isPositive: true,
                percentage: '100%',
              ),
              _StatCard(
                title: 'Follow-ups\nToday',
                value: service.followUpsTodayCount.toString(),
                icon: Icons.calendar_today_rounded,
                iconColor: AppColors.statusPending,
                iconBg: AppColors.statusPendingBg,
                trendText: 'vs yesterday',
                isPositive: false,
              ),
              _StatCard(
                title: 'Overdue\nFollow-ups',
                value: service.overdueFollowUpsCount.toString(),
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.statusRed,
                iconBg: AppColors.statusRedBg,
                trendText: 'vs yesterday',
                isPositive: false,
              ),
              _StatCard(
                title: 'Upcoming\nFollow-ups',
                value: service.upcomingFollowUpsCount.toString(),
                icon: Icons.event_rounded,
                iconColor: AppColors.statusUpcoming,
                iconBg: AppColors.statusUpcomingBg,
                trendText: 'vs yesterday',
                isPositive: true,
                percentage: '100%',
              ),
              _StatCard(
                title: 'Completed\nFollow-ups',
                value: service.completedFollowUpsCount.toString(),
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.statusBooked,
                iconBg: AppColors.statusBookedBg,
                trendText: 'vs yesterday',
                isPositive: false,
              ),
              _StatCard(
                title: 'Booked\nCustomers',
                value: service.bookedCustomers.toString(),
                icon: Icons.bookmark_border_rounded,
                iconColor: AppColors.goldDark,
                iconBg: AppColors.gold.withValues(alpha: 0.1),
                trendText: 'vs yesterday',
                isPositive: false,
              ),
              _StatCard(
                title: 'Registration\nCompleted',
                value: service.registrationCompleted.toString(),
                icon: Icons.verified_outlined,
                iconColor: AppColors.primary,
                iconBg: AppColors.primary.withValues(alpha: 0.1),
                trendText: 'vs yesterday',
                isPositive: false,
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String trendText;
  final bool isPositive;
  final String? percentage;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.trendText,
    required this.isPositive,
    this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600, height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 28, color: AppColors.textPrimary, fontWeight: FontWeight.w800, height: 1.0),
          ),
          const SizedBox(height: 8),
          if (percentage != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: isPositive ? AppColors.statusBooked : AppColors.statusRed, size: 12),
                const SizedBox(width: 2),
                Text(
                  percentage!,
                  style: GoogleFonts.poppins(fontSize: 10, color: isPositive ? AppColors.statusBooked : AppColors.statusRed, fontWeight: FontWeight.w700),
                ),
              ],
            )
          else
            Text(
              '—',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 2),
          Text(
            trendText,
            style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Follow Up Overview Card
// ─────────────────────────────────────────────────────────────────────────────
class _FollowUpOverviewCard extends StatelessWidget {
  final CustomerService service;

  const _FollowUpOverviewCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Follow-up Overview',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                'View All',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.goldDark),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildOverviewRow('Follow-ups Today', service.followUpsTodayCount, AppColors.statusPending),
          const Divider(height: 24, thickness: 0.5),
          _buildOverviewRow('Upcoming Follow-ups', service.upcomingFollowUpsCount, AppColors.statusUpcoming),
          const Divider(height: 24, thickness: 0.5),
          _buildOverviewRow('Overdue Follow-ups', service.overdueFollowUpsCount, AppColors.statusRed),
          const Divider(height: 24, thickness: 0.5),
          _buildOverviewRow('Completed Follow-ups', service.completedFollowUpsCount, AppColors.statusBooked),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(String label, int count, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          count.toString(),
          style: GoogleFonts.poppins(fontSize: 13, color: dotColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions Card
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onAddCustomer;

  const _QuickActionsCard({required this.onAddCustomer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.5,
            ),
            children: [
              _buildActionCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Customer',
                color: AppColors.primary,
                bgColor: AppColors.primary.withValues(alpha: 0.05),
                onTap: onAddCustomer,
              ),
              _buildActionCard(
                icon: Icons.calendar_today_rounded,
                label: 'Follow-ups',
                color: AppColors.statusPending,
                bgColor: AppColors.statusPendingBg,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FollowUpListScreen(
                        initialFilter: SortMode.followUpsToday,
                        title: 'Follow-ups',
                      ),
                    ),
                  );
                },
              ),
              _buildActionCard(
                icon: Icons.description_rounded,
                label: 'View Reports',
                color: AppColors.statusPurple,
                bgColor: AppColors.statusPurpleBg,
                onTap: () {
                  final service = context.read<CustomerService>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfReportScreen(
                        customers: service.customers,
                        totalCustomers: service.totalCustomers,
                        bookedCustomers: service.bookedCustomers,
                        registrationCompleted: service.registrationCompleted,
                      ),
                    ),
                  );
                },
              ),
              _buildActionCard(
                icon: Icons.message_rounded,
                label: 'WhatsApp\nMessage',
                color: AppColors.statusBooked,
                bgColor: AppColors.statusBookedBg,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WhatsApp integration not configured.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
