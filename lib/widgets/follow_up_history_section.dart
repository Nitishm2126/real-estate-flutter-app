import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../utils/theme.dart';

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
          child: Text(
            'Follow-up History',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: customer.followUpHistory.length,
          itemBuilder: (context, index) {
            final followUp = customer.followUpHistory[index];
            final isLast = index == customer.followUpHistory.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline line
                  SizedBox(
                    width: 30,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 24),
                          decoration: BoxDecoration(
                            color: followUp.isCompleted ? AppColors.statusBooked : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: AppColors.divider,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Follow-up #${followUp.followUpNumber}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (!followUp.isCompleted && followUp.followUpTime != null && followUp.followUpTime!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.notifications_active_rounded, size: 12, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Reminder Scheduled',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (followUp.isCompleted)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.statusBooked, size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${followUp.formattedDate}${followUp.followUpTime != null ? ' • ${followUp.followUpTime}' : ''}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (followUp.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                followUp.notes,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                            if (followUp.isCompleted && followUp.completedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Completed: ${DateFormat('dd MMM yyyy, hh:mm a').format(followUp.completedAt!.toLocal())}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.statusBooked,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
