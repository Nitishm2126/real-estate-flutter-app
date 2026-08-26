import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/follow_up.dart';
import '../services/customer_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/theme.dart';
import 'next_followup_sheet.dart';
import 'whatsapp_selection_sheet.dart';

/// Displays the full follow-up history for a customer with inline quick actions.
class FollowUpHistorySection extends StatelessWidget {
  const FollowUpHistorySection({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    if (customer.followUpHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Follow-up History',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${customer.followUpHistory.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: customer.followUpHistory.length,
          itemBuilder: (context, index) {
            final followUp = customer.followUpHistory[index];
            final isLast = index == customer.followUpHistory.length - 1;
            return _FollowUpHistoryCard(
              followUp: followUp,
              customer: customer,
              isLast: isLast,
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual follow-up history card with quick actions
// ─────────────────────────────────────────────────────────────────────────────
class _FollowUpHistoryCard extends StatefulWidget {
  const _FollowUpHistoryCard({
    required this.followUp,
    required this.customer,
    required this.isLast,
  });

  final FollowUp followUp;
  final Customer customer;
  final bool isLast;

  @override
  State<_FollowUpHistoryCard> createState() => _FollowUpHistoryCardState();
}

class _FollowUpHistoryCardState extends State<_FollowUpHistoryCard> {
  bool _isBusy = false;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  Future<void> _complete() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await context.read<CustomerService>().completeFollowUp(widget.followUp);
      if (!mounted) return;
      // Show next follow-up sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => NextFollowUpSheet(
          customer: widget.customer,
          completedFollowUp: widget.followUp,
        ),
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
      initialDate: widget.followUp.followUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (!mounted || date == null) return;

    TimeOfDay? time;
    if (widget.followUp.followUpTime != null) {
      time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppColors.primary, onPrimary: Colors.white),
          ),
          child: child!,
        ),
      );
      if (!mounted) return;
    }

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
          .rescheduleFollowUp(widget.followUp, date, formattedTime);
      _snack('Follow-up rescheduled to ${DateFormat('dd MMM yyyy').format(date)}');
    } catch (e) {
      _snack('Failed to reschedule.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _editNote() async {
    final ctrl = TextEditingController(text: widget.followUp.notes);
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
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter note...',
            hintStyle: GoogleFonts.poppins(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Save',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || saved == null) return;

    setState(() => _isBusy = true);
    try {
      await context
          .read<CustomerService>()
          .updateFollowUpNote(widget.followUp, saved.trim());
      _snack('Note updated.');
    } catch (e) {
      _snack('Failed to update note.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _call() async {
    final uri =
        Uri(scheme: 'tel', path: widget.customer.dialablePhoneNumber);
    if (!await launchUrl(uri) && mounted) {
      _snack('Could not open phone dialer.', isError: true);
    }
  }

  Future<void> _whatsApp() async {
    final message =
        WhatsAppService.getPrefilledMessage(widget.customer.customerName);
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
                phone: widget.customer.dialablePhoneNumber,
                message: message,
                app: selected);
          },
        ),
      );
    } else {
      await WhatsAppService.launchWhatsApp(
          phone: widget.customer.dialablePhoneNumber,
          message: message,
          app: app);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fu = widget.followUp;

    Color statusColor;
    Color statusBg;
    String statusLabel;
    if (fu.isCompleted) {
      statusColor = AppColors.statusBooked;
      statusBg = AppColors.statusBookedBg;
      statusLabel = 'Completed';
    } else if (fu.status.toLowerCase() == 'rescheduled') {
      statusColor = AppColors.statusPending;
      statusBg = AppColors.statusPendingBg;
      statusLabel = 'Rescheduled';
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final fDay = DateTime(
          fu.followUpDate.year, fu.followUpDate.month, fu.followUpDate.day);
      if (fDay.isBefore(today)) {
        statusColor = AppColors.statusRed;
        statusBg = AppColors.statusRedBg;
        statusLabel = 'Overdue';
      } else if (fDay.isAtSameMomentAs(today)) {
        statusColor = AppColors.goldDark;
        statusBg = AppColors.gold.withValues(alpha: 0.1);
        statusLabel = 'Today';
      } else {
        statusColor = AppColors.primary;
        statusBg = AppColors.primary.withValues(alpha: 0.08);
        statusLabel = 'Upcoming';
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline spine
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(
                    color: fu.isCompleted
                        ? AppColors.statusBooked
                        : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.divider),
                  ),
              ],
            ),
          ),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.divider, width: 1),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
                      child: Row(
                        children: [
                          Text(
                            'Follow-up #${fu.followUpNumber}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Date / time / notes
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 6, AppSpacing.md, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 5),
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
                            const SizedBox(height: 4),
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
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (fu.isCompleted && fu.completedAt != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.done_all_rounded,
                                    size: 13,
                                    color: AppColors.statusBooked),
                                const SizedBox(width: 5),
                                Text(
                                  'Completed: ${DateFormat('dd MMM yyyy, hh:mm a').format(fu.completedAt!.toLocal())}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.statusBooked,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm, 8, AppSpacing.sm, AppSpacing.sm),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!fu.isCompleted)
                            _ActionChip(
                              label: 'Complete',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.statusBooked,
                              onTap: _isBusy ? null : _complete,
                            ),
                          if (!fu.isCompleted)
                            _ActionChip(
                              label: 'Reschedule',
                              icon: Icons.schedule_rounded,
                              color: AppColors.statusPending,
                              onTap: _isBusy ? null : _reschedule,
                            ),
                          _ActionChip(
                            label: 'Edit Note',
                            icon: Icons.edit_note_rounded,
                            color: AppColors.primary,
                            onTap: _isBusy ? null : _editNote,
                          ),
                          _ActionChip(
                            label: 'Call',
                            icon: Icons.call_rounded,
                            color: AppColors.statusBooked,
                            onTap: _isBusy ? null : _call,
                          ),
                          _ActionChip(
                            label: 'WhatsApp',
                            icon: Icons.chat_rounded,
                            color: const Color(0xFF25D366),
                            onTap: _isBusy ? null : _whatsApp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
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
