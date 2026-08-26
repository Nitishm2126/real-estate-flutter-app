import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/follow_up.dart';
import '../services/customer_service.dart';
import '../utils/theme.dart';

/// Bottom sheet shown after completing a follow-up.
/// Offers quick scheduling options for the next follow-up.
class NextFollowUpSheet extends StatefulWidget {
  const NextFollowUpSheet({
    super.key,
    required this.customer,
    required this.completedFollowUp,
  });

  final Customer customer;
  final FollowUp completedFollowUp;

  @override
  State<NextFollowUpSheet> createState() => _NextFollowUpSheetState();
}

class _NextFollowUpSheetState extends State<NextFollowUpSheet> {
  bool _isSaving = false;
  DateTime? _customDate;
  TimeOfDay? _customTime;
  final _notesCtrl = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _schedule(DateTime date, {TimeOfDay? time}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final service = context.read<CustomerService>();
    final customer = widget.customer;

    String? formattedTime;
    if (time != null) {
      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      formattedTime = DateFormat.jm().format(dt);
    }

    try {
      final historyCount = customer.followUpHistory.length;
      final newFollowUp = FollowUp(
        customerId: customer.id!,
        followUpNumber: historyCount + 1,
        followUpDate: date,
        followUpTime: formattedTime,
        notes: _notesCtrl.text.trim(),
      );
      await service.addFollowUpHistory(customer.id!, newFollowUp);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                    'Next follow-up scheduled for ${DateFormat('dd MMM yyyy').format(date)}'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule: $e'),
            backgroundColor: AppColors.statusRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    }
  }

  Future<void> _pickCustom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
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
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;

    setState(() {
      _customDate = date;
      _customTime = time;
      _showCustom = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final in3Days = DateTime(now.year, now.month, now.day + 3);
    final in1Week = DateTime(now.year, now.month, now.day + 7);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Success header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusBookedBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: AppColors.statusBooked, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow-up Completed!',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.customer.customerName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Text(
            'SCHEDULE NEXT FOLLOW-UP?',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Quick options
          Row(
            children: [
              Expanded(
                  child: _QuickOption(
                label: 'Tomorrow',
                date: DateFormat('dd MMM').format(tomorrow),
                onTap: () => _schedule(tomorrow),
                isSaving: _isSaving,
              )),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _QuickOption(
                label: 'In 3 Days',
                date: DateFormat('dd MMM').format(in3Days),
                onTap: () => _schedule(in3Days),
                isSaving: _isSaving,
              )),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _QuickOption(
                label: 'In 1 Week',
                date: DateFormat('dd MMM').format(in1Week),
                onTap: () => _schedule(in1Week),
                isSaving: _isSaving,
              )),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Custom date picker row
          if (_showCustom && _customDate != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd MMM yyyy').format(_customDate!)}${_customTime != null ? ' at ${_customTime!.format(context)}' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Add a note for this follow-up...',
                      hintStyle:
                          GoogleFonts.poppins(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _schedule(_customDate!, time: _customTime),
                      child: _isSaving
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            )
                          : Text('Schedule This',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickCustom,
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text('Custom Date & Time',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Skip',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickOption extends StatelessWidget {
  const _QuickOption({
    required this.label,
    required this.date,
    required this.onTap,
    required this.isSaving,
  });

  final String label;
  final String date;
  final VoidCallback onTap;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.event_rounded, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
                textAlign: TextAlign.center),
            Text(date,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
