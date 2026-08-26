import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/follow_up.dart';
import '../services/customer_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/theme.dart';
import '../widgets/add_customer_bottom_sheet.dart';
import '../widgets/add_follow_up_sheet.dart';
import '../widgets/customer_timeline.dart';
import '../widgets/follow_up_history_section.dart';
import '../widgets/next_followup_sheet.dart';
import '../widgets/whatsapp_selection_sheet.dart';

/// Full-detail view for a single customer with Hero animation,
/// working Call and WhatsApp buttons, and status badges.
class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({super.key, required this.customer});

  final Customer customer;

  // ─── Actions ─────────────────────────────────────────────────

  Future<void> _call(BuildContext context) async {
    final service = Provider.of<CustomerService>(context, listen: false);
    final currentCustomer = service.customers
        .firstWhere((c) => c.id == customer.id, orElse: () => customer);
    final uri = Uri(scheme: 'tel', path: currentCustomer.dialablePhoneNumber);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        _showSnackBar(context, 'Could not open the phone dialer.',
            isError: true);
      }
    }
  }

  Future<void> _whatsApp(BuildContext context) async {
    final service = Provider.of<CustomerService>(context, listen: false);
    final currentCustomer = service.customers
        .firstWhere((c) => c.id == customer.id, orElse: () => customer);
    
    final message = WhatsAppService.getPrefilledMessage(currentCustomer.customerName);
    
    final availableApp = await WhatsAppService.checkAvailableApps();
    
    if (!context.mounted) return;

    if (availableApp == WhatsAppApp.none) {
      _showSnackBar(context, 'WhatsApp is not available on this device.', isError: true);
      return;
    }

    if (availableApp == WhatsAppApp.both) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => WhatsAppSelectionSheet(
          onSelect: (selectedApp) async {
            final launched = await WhatsAppService.launchWhatsApp(
              phone: currentCustomer.dialablePhoneNumber,
              message: message,
              app: selectedApp,
            );
            if (!launched && context.mounted) {
              _showSnackBar(context, 'Could not open WhatsApp.', isError: true);
            }
          },
        ),
      );
    } else {
      final launched = await WhatsAppService.launchWhatsApp(
        phone: currentCustomer.dialablePhoneNumber,
        message: message,
        app: availableApp,
      );
      if (!launched && context.mounted) {
        _showSnackBar(context, 'Could not open WhatsApp.', isError: true);
      }
    }
  }

  void _showSnackBar(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  Future<void> _completeFollowUpFromHeader(
      BuildContext context, Customer currentCustomer) async {
    final service = context.read<CustomerService>();
    final isCompleted = currentCustomer.followUpCompleted;

    try {
      await service.toggleFollowUp(currentCustomer);
      if (!context.mounted) return;
      if (!isCompleted) {
        // Show next follow-up sheet after completing
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: true,
          builder: (_) => NextFollowUpSheet(
            customer: currentCustomer,
            completedFollowUp: currentCustomer.followUpHistory.isNotEmpty
                ? currentCustomer.followUpHistory.first
                : (currentCustomer.followUpHistory.isEmpty
                    ? _makeDummyFollowUp(currentCustomer)
                    : currentCustomer.followUpHistory.first),
          ),
        );
      } else {
        _showSnackBar(context, 'Follow-up Reopened');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Failed to update follow-up status.',
            isError: true);
      }
    }
  }

  /// Minimal stub follow-up for when history is empty.
  FollowUp _makeDummyFollowUp(Customer c) {
    return FollowUp(
      id: c.id,
      customerId: c.id ?? '',
      followUpNumber: 1,
      followUpDate: c.followUpDate ?? DateTime.now(),
      followUpTime: c.followUpTime,
      notes: c.followUpNotes,
    );
  }

  void _openEditSheet(BuildContext context,
      {bool isSchedulingNextFollowUp = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddCustomerBottomSheet(
        existingCustomer: customer,
        isSchedulingNextFollowUp: isSchedulingNextFollowUp,
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Collapsing App Bar with Hero ─────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            elevation: 0,
            actions: [
              Consumer<CustomerService>(builder: (context, service, child) {
                return IconButton(
                  onPressed: () => _openEditSheet(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 18),
                  ),
                  tooltip: 'Edit Customer',
                );
              }),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Consumer<CustomerService>(
                    builder: (context, service, child) {
                      final currentCustomer = service.customers.firstWhere(
                        (c) => c.id == customer.id,
                        orElse: () => customer,
                      );
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Hero avatar
                          Hero(
                            tag: 'avatar_${customer.id}',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.gold, AppColors.goldDark],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  _initials(currentCustomer.customerName),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            currentCustomer.customerName.trim().isNotEmpty
                                ? currentCustomer.customerName
                                : '-',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentCustomer.phoneNumber.trim().isNotEmpty
                                ? currentCustomer.phoneNumber
                                : '-',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Body Content ─────────────────────────────────────
          SliverToBoxAdapter(
            child:
                Consumer<CustomerService>(builder: (context, service, child) {
              final currentCustomer = service.customers.firstWhere(
                (c) => c.id == customer.id,
                orElse: () => customer,
              );
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // Status Badges
                    _StatusRow(customer: currentCustomer)
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 100.ms)
                        .slideY(begin: 0.1),

                    const SizedBox(height: AppSpacing.md),

                    // Quick Actions Bar
                    _QuickActionsBar(
                      customer: currentCustomer,
                      onCall: () => _call(context),
                      onWhatsApp: () => _whatsApp(context),
                      onAddFollowUp: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddFollowUpSheet(initialCustomer: currentCustomer),
                        );
                      },
                      onEdit: () => _openEditSheet(context),
                    ).animate().fadeIn(duration: 350.ms, delay: 150.ms).slideY(begin: 0.1),

                    const SizedBox(height: AppSpacing.md),

                    // Info Card
                    _InfoCard(customer: currentCustomer)
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 200.ms)
                        .slideY(begin: 0.1),

                    // Notes Card
                    const SizedBox(height: AppSpacing.md),
                    _NotesCard(notes: currentCustomer.notes)
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 300.ms)
                        .slideY(begin: 0.1),

                    // Active Follow-up Card (customer-level)
                    if (currentCustomer.followUpDate != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _FollowUpCard(customer: currentCustomer)
                          .animate()
                          .fadeIn(duration: 350.ms, delay: 350.ms)
                          .slideY(begin: 0.1),
                    ],

                    // Legacy: mark complete / reopen for customer-level follow-up
                    if (currentCustomer.followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _completeFollowUpFromHeader(
                                context, currentCustomer),
                            icon: Icon(
                              currentCustomer.followUpCompleted
                                  ? Icons.replay_rounded
                                  : Icons.check_circle_rounded,
                              size: 20,
                            ),
                            label: Text(
                              currentCustomer.followUpCompleted
                                  ? 'Reopen Follow-up'
                                  : 'Mark Follow-up Complete',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: currentCustomer.followUpCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.statusBooked,
                              side: BorderSide(
                                color: currentCustomer.followUpCompleted
                                    ? AppColors.divider
                                    : AppColors.statusBooked
                                        .withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              backgroundColor: currentCustomer.followUpCompleted
                                  ? AppColors.surface
                                  : AppColors.statusBookedBg,
                            ),
                          ),
                        ).animate().fadeIn(duration: 350.ms, delay: 400.ms),
                      ),

                    const SizedBox(height: AppSpacing.lg),

                    // Follow-up History (with quick actions per card)
                    FollowUpHistorySection(customer: currentCustomer),

                    const SizedBox(height: AppSpacing.lg),

                    // Customer Activity Timeline
                    CustomerTimeline(customer: currentCustomer)
                        .animate()
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions Bar ───────────────────────────────────────────────
class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({
    required this.customer,
    required this.onCall,
    required this.onWhatsApp,
    required this.onAddFollowUp,
    required this.onEdit,
  });
  final Customer customer;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onAddFollowUp;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickBtn(
            icon: Icons.call_rounded,
            label: 'Call',
            color: AppColors.statusBooked,
            onTap: onCall,
          ),
          _QuickBtn(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: onWhatsApp,
          ),
          _QuickBtn(
            icon: Icons.add_task_rounded,
            label: 'Follow-up',
            color: AppColors.primary,
            onTap: onAddFollowUp,
          ),
          _QuickBtn(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: AppColors.goldDark,
            onTap: onEdit,
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Row ───────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final isBooked = customer.bookingStatus == BookingStatus.booked;
    final isCompleted =
        customer.registrationStatus == RegistrationStatus.completed;

    return Row(
      children: [
        Expanded(
          child: _Badge(
            label: isBooked ? '✓ Booked' : '⏳ Pending Booking',
            textColor:
                isBooked ? AppColors.statusBooked : AppColors.statusPending,
            bgColor:
                isBooked ? AppColors.statusBookedBg : AppColors.statusPendingBg,
            borderColor: isBooked
                ? AppColors.statusBooked.withValues(alpha: 0.3)
                : AppColors.statusPending.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Badge(
            label: isCompleted ? '✓ Reg. Completed' : '⏳ Reg. Pending',
            textColor:
                isCompleted ? AppColors.statusCompleted : AppColors.statusRed,
            bgColor: isCompleted
                ? AppColors.statusCompletedBg
                : AppColors.statusRedBg,
            borderColor: isCompleted
                ? AppColors.statusCompleted.withValues(alpha: 0.3)
                : AppColors.statusRed.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });
  final String label;
  final Color textColor, bgColor, borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Info Card ───────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoRow(
                icon: Icons.place_rounded,
                label: 'Place',
                value: customer.place),
            _InfoRow(
                icon: Icons.person_pin_circle_rounded,
                label: 'Lead Given By',
                value: customer.leadGivenBy),
            _InfoRow(
                icon: Icons.villa_rounded,
                label: 'Site Visited',
                value: customer.siteVisited),
            _InfoRow(
                icon: Icons.calendar_month_rounded,
                label: 'Visit Date',
                value: customer.formattedDate,
                isLast: true),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final IconData icon;
  final String label, value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value.trim().isNotEmpty ? value : '-',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

// ─── Notes Card ──────────────────────────────────────────────────────────────
class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded,
                  size: 16, color: AppColors.goldDark),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes.trim().isNotEmpty ? notes : '-',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}



// --- Follow-up Card ----------------------------------------------------------
class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Next Active Follow-up',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddFollowUpSheet(initialCustomer: customer),
                    );
                  },
                  icon: Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  label: Text('Add Follow-up', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                if (customer.followUpCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.statusBookedBg,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      'Completed',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusBooked,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingBg,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      'Pending',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusPending,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Follow-up Date',
                value: customer.formattedFollowUpDate,
                isLast: customer.followUpTime == null &&
                    customer.followUpNotes.isEmpty),
            if (customer.followUpTime != null &&
                customer.followUpTime!.isNotEmpty)
              _InfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Follow-up Time',
                  value: customer.followUpTime!,
                  isLast: customer.followUpNotes.isEmpty),
            if (customer.followUpNotes.isNotEmpty)
              _InfoRow(
                  icon: Icons.note_alt_rounded,
                  label: 'Notes',
                  value: customer.followUpNotes,
                  isLast: !customer.followUpCompleted ||
                      customer.followUpCompletedAt == null),
            if (customer.followUpCompleted &&
                customer.followUpCompletedAt != null)
              _InfoRow(
                  icon: Icons.done_all_rounded,
                  label: 'Completed On',
                  value: DateFormat('dd MMM yyyy, hh:mm a')
                      .format(customer.followUpCompletedAt!.toLocal()),
                  isLast: true),
          ],
        ),
      ),
    );
  }
}
