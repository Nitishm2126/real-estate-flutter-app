import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/follow_up.dart';
import '../screens/customer_details_screen.dart';
import '../services/customer_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/theme.dart';
import '../widgets/next_followup_sheet.dart';
import '../widgets/whatsapp_selection_sheet.dart';
import '../widgets/add_follow_up_sheet.dart';

class FollowUpListScreen extends StatefulWidget {
  const FollowUpListScreen({
    super.key,
    required this.initialFilter,
    required this.title,
    this.isInline = false,
  });

  final SortMode initialFilter;
  final String title;
  final bool isInline;

  @override
  State<FollowUpListScreen> createState() => _FollowUpListScreenState();
}

class _FollowUpListScreenState extends State<FollowUpListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _modes = [
    SortMode.followUpsOverdue,
    SortMode.followUpsToday,
    SortMode.followUpsUpcoming,
    SortMode.followUpsCompleted,
    SortMode.followUpsAll,
  ];

  @override
  void initState() {
    super.initState();
    int idx = _modes.indexOf(widget.initialFilter);
    if (idx == -1) idx = 1;
    _tabController = TabController(length: 5, vsync: this, initialIndex: idx);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Follow-ups'),
        automaticallyImplyLeading: !widget.isInline,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'OVERDUE'),
            Tab(text: 'TODAY'),
            Tab(text: 'UPCOMING'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'ALL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _modes
            .map((m) => _FollowUpTabContent(
                  mode: m,
                  isInline: widget.isInline,
                ))
            .toList(),
      ),
      floatingActionButton: widget.isInline
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddFollowUpSheet(),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Add Follow-up',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab content — shows individual follow-up records
// ─────────────────────────────────────────────────────────────────────────────
class _FollowUpTabContent extends StatelessWidget {
  const _FollowUpTabContent({required this.mode, required this.isInline});
  final SortMode mode;
  final bool isInline;

  String get _emptyTitle {
    switch (mode) {
      case SortMode.followUpsOverdue:
        return 'No overdue follow-ups!';
      case SortMode.followUpsToday:
        return 'No follow-ups for today.';
      case SortMode.followUpsUpcoming:
        return 'No upcoming follow-ups.';
      case SortMode.followUpsCompleted:
        return 'No completed follow-ups yet.';
      default:
        return 'No follow-ups found.';
    }
  }

  String get _emptySubtitle {
    switch (mode) {
      case SortMode.followUpsOverdue:
        return 'Great job! You\'re all caught up.';
      case SortMode.followUpsToday:
        return 'You\'re all caught up!';
      case SortMode.followUpsUpcoming:
        return 'Schedule follow-ups for your customers.';
      case SortMode.followUpsCompleted:
        return 'Complete a follow-up to see it here.';
      default:
        return 'Add follow-ups from customer records.';
    }
  }

  List<FollowUpWithCustomer> _filterRecords(
      List<FollowUpWithCustomer> all, CustomerService service) {
    switch (mode) {
      case SortMode.followUpsOverdue:
        return all
            .where((r) => service.getFollowUpRecordPriority(r.followUp) == 0)
            .toList()
          ..sort((a, b) =>
              a.followUp.followUpDate.compareTo(b.followUp.followUpDate));
      case SortMode.followUpsToday:
        return all
            .where((r) => service.getFollowUpRecordPriority(r.followUp) == 1)
            .toList()
          ..sort((a, b) =>
              a.followUp.followUpDate.compareTo(b.followUp.followUpDate));
      case SortMode.followUpsUpcoming:
        return all
            .where((r) => service.getFollowUpRecordPriority(r.followUp) == 2)
            .toList()
          ..sort((a, b) =>
              a.followUp.followUpDate.compareTo(b.followUp.followUpDate));
      case SortMode.followUpsCompleted:
        return all
            .where((r) => service.getFollowUpRecordPriority(r.followUp) == 3)
            .toList()
          ..sort((a, b) => (b.followUp.completedAt ?? DateTime(2000))
              .compareTo(a.followUp.completedAt ?? DateTime(2000)));
      case SortMode.followUpsAll:
        return List.from(all)
          ..sort((a, b) {
            final pa = service.getFollowUpRecordPriority(a.followUp);
            final pb = service.getFollowUpRecordPriority(b.followUp);
            if (pa != pb) return pa.compareTo(pb);
            return a.followUp.followUpDate
                .compareTo(b.followUp.followUpDate);
          });
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerService>(
      builder: (context, service, _) {
        if (service.isLoading || service.isSyncing) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        final records = _filterRecords(service.allFollowUpRecords, service);

        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 72,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _emptyTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _emptySubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn()
                .scale(duration: 400.ms, curve: Curves.easeOutBack),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
              AppSpacing.md, isInline ? 160 : AppSpacing.xl),
          itemCount: records.length,
          itemBuilder: (context, index) {
            return _FollowUpRecordCard(
              record: records[index],
              index: index,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual follow-up record card
// ─────────────────────────────────────────────────────────────────────────────
class _FollowUpRecordCard extends StatefulWidget {
  const _FollowUpRecordCard({required this.record, required this.index});
  final FollowUpWithCustomer record;
  final int index;

  @override
  State<_FollowUpRecordCard> createState() => _FollowUpRecordCardState();
}

class _FollowUpRecordCardState extends State<_FollowUpRecordCard> {
  bool _isBusy = false;

  FollowUp get fu => widget.record.followUp;
  Customer get customer => widget.record.customer;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  Future<void> _complete() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await context.read<CustomerService>().completeFollowUp(fu);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) =>
            NextFollowUpSheet(customer: customer, completedFollowUp: fu),
      );
    } catch (e) {
      _snack('Failed to complete follow-up.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _reschedule() async {
    if (_isBusy) return;

    final date = await showDatePicker(
      context: context,
      initialDate: fu.followUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;

    setState(() => _isBusy = true);
    try {
      String? formattedTime;
      if (time != null) {
        final dt =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
        formattedTime = DateFormat.jm().format(dt);
      }
      await context
          .read<CustomerService>()
          .rescheduleFollowUp(fu, date, formattedTime);
      _snack('Rescheduled to ${DateFormat('dd MMM yyyy').format(date)}');
    } catch (e) {
      _snack('Failed to reschedule.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _editNote() async {
    final ctrl = TextEditingController(text: fu.notes);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Edit Note',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: TextFormField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          style:
              GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter note...',
            hintStyle: GoogleFonts.poppins(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style:
                      GoogleFonts.poppins(color: AppColors.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text('Save',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w700))),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || saved == null) return;

    setState(() => _isBusy = true);
    try {
      await context
          .read<CustomerService>()
          .updateFollowUpNote(fu, saved.trim());
      _snack('Note updated.');
    } catch (e) {
      _snack('Failed to update note.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: customer.dialablePhoneNumber);
    if (!await launchUrl(uri) && mounted) {
      _snack('Could not open phone dialer.', isError: true);
    }
  }

  Future<void> _whatsApp() async {
    final message =
        WhatsAppService.getPrefilledMessage(customer.customerName);
    final app = await WhatsAppService.checkAvailableApps();
    if (!mounted) return;

    if (app == WhatsAppApp.none) {
      _snack('WhatsApp not available.', isError: true);
      return;
    }
    if (app == WhatsAppApp.both) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => WhatsAppSelectionSheet(
          onSelect: (selected) async {
            await WhatsAppService.launchWhatsApp(
                phone: customer.dialablePhoneNumber,
                message: message,
                app: selected);
          },
        ),
      );
    } else {
      await WhatsAppService.launchWhatsApp(
          phone: customer.dialablePhoneNumber,
          message: message,
          app: app);
    }
  }

  void _openDetails() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) =>
            CustomerDetailsScreen(customer: customer),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    if (fu.isCompleted) {
      statusColor = AppColors.statusBooked;
      statusBg = AppColors.statusBookedBg;
      statusLabel = 'Completed';
      statusIcon = Icons.check_circle_rounded;
    } else if (fu.status.toLowerCase() == 'rescheduled') {
      statusColor = AppColors.statusPending;
      statusBg = AppColors.statusPendingBg;
      statusLabel = 'Rescheduled';
      statusIcon = Icons.schedule_rounded;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final fDay = DateTime(
          fu.followUpDate.year, fu.followUpDate.month, fu.followUpDate.day);
      if (fDay.isBefore(today)) {
        statusColor = AppColors.statusRed;
        statusBg = AppColors.statusRedBg;
        statusLabel = 'Overdue';
        statusIcon = Icons.warning_rounded;
      } else if (fDay.isAtSameMomentAs(today)) {
        statusColor = AppColors.goldDark;
        statusBg = AppColors.gold.withValues(alpha: 0.12);
        statusLabel = 'Today';
        statusIcon = Icons.notifications_active_rounded;
      } else {
        statusColor = AppColors.primary;
        statusBg = AppColors.primary.withValues(alpha: 0.08);
        statusLabel = 'Upcoming';
        statusIcon = Icons.event_rounded;
      }
    }

    return GestureDetector(
      onTap: _openDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
          border: Border.all(
              color: statusColor.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer row + status chip
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLight
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: Center(
                          child: Text(
                            _initials(customer.customerName),
                            style: GoogleFonts.poppins(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
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
                              customer.customerName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              customer.phoneNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 11, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Follow-up number + date row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          'Follow-up #${fu.followUpNumber}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today_rounded,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${fu.formattedDate}${fu.followUpTime != null ? ' • ${fu.followUpTime}' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  if (fu.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            fu.notes,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Action chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (!fu.isCompleted)
                        _Chip(
                          label: 'Complete',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.statusBooked,
                          onTap: _isBusy ? null : _complete,
                        ),
                      if (!fu.isCompleted)
                        _Chip(
                          label: 'Reschedule',
                          icon: Icons.schedule_rounded,
                          color: AppColors.statusPending,
                          onTap: _isBusy ? null : _reschedule,
                        ),
                      _Chip(
                        label: 'Note',
                        icon: Icons.edit_note_rounded,
                        color: AppColors.primary,
                        onTap: _isBusy ? null : _editNote,
                      ),
                      _Chip(
                        label: 'Call',
                        icon: Icons.call_rounded,
                        color: AppColors.statusBooked,
                        onTap: _isBusy ? null : _call,
                      ),
                      _Chip(
                        label: 'WhatsApp',
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        onTap: _isBusy ? null : _whatsApp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 40 * (widget.index % 10)),
        )
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
