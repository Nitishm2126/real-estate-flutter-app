import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/customer.dart';
import '../utils/theme.dart';

/// A timeline event derived from customer/follow-up data.
class _TimelineEvent {
  final DateTime time;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;

  const _TimelineEvent({
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
  });
}

/// Displays a chronological activity timeline derived from existing customer
/// and follow-up data. No additional database tables required.
class CustomerTimeline extends StatelessWidget {
  const CustomerTimeline({super.key, required this.customer});

  final Customer customer;

  List<_TimelineEvent> _buildEvents() {
    final events = <_TimelineEvent>[];

    // Customer created
    if (customer.createdAt != null) {
      events.add(_TimelineEvent(
        time: customer.createdAt!,
        icon: Icons.person_add_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.primary.withValues(alpha: 0.1),
        title: 'Customer Created',
        subtitle: 'Lead registered in CRM',
      ));
    }

    // Booking status changes captured via updatedAt if different from createdAt
    if (customer.updatedAt != null &&
        customer.createdAt != null &&
        customer.updatedAt!
            .difference(customer.createdAt!)
            .inMinutes
            .abs() >
            1) {
      String subtitle = 'Customer details updated';
      if (customer.bookingStatus == BookingStatus.booked) {
        subtitle = 'Booking status updated to Booked';
      } else if (customer.registrationStatus ==
          RegistrationStatus.completed) {
        subtitle = 'Registration marked as Completed';
      }
      events.add(_TimelineEvent(
        time: customer.updatedAt!,
        icon: Icons.edit_note_rounded,
        iconColor: AppColors.statusUpcoming,
        iconBg: AppColors.statusUpcomingBg,
        title: 'Customer Updated',
        subtitle: subtitle,
      ));
    }

    // Follow-up history events
    for (final fu in customer.followUpHistory) {
      // Scheduled event
      if (fu.createdAt != null) {
        events.add(_TimelineEvent(
          time: fu.createdAt!,
          icon: Icons.event_note_rounded,
          iconColor: AppColors.primary,
          iconBg: AppColors.primary.withValues(alpha: 0.1),
          title: 'Follow-up #${fu.followUpNumber} Scheduled',
          subtitle:
              '${DateFormat('dd MMM yyyy').format(fu.followUpDate)}${fu.followUpTime != null ? ' at ${fu.followUpTime}' : ''}${fu.notes.isNotEmpty ? ' — ${fu.notes}' : ''}',
        ));
      }

      // Rescheduled event (status == Rescheduled and has updatedAt)
      if (fu.status.toLowerCase() == 'rescheduled' && fu.updatedAt != null) {
        events.add(_TimelineEvent(
          time: fu.updatedAt!,
          icon: Icons.schedule_rounded,
          iconColor: AppColors.statusPending,
          iconBg: AppColors.statusPendingBg,
          title: 'Follow-up #${fu.followUpNumber} Rescheduled',
          subtitle:
              'New date: ${DateFormat('dd MMM yyyy').format(fu.followUpDate)}${fu.followUpTime != null ? ' at ${fu.followUpTime}' : ''}',
        ));
      }

      // Completed event
      if (fu.isCompleted && fu.completedAt != null) {
        events.add(_TimelineEvent(
          time: fu.completedAt!,
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.statusBooked,
          iconBg: AppColors.statusBookedBg,
          title: 'Follow-up #${fu.followUpNumber} Completed',
          subtitle: fu.notes.isNotEmpty ? fu.notes : null,
        ));
      }
    }

    // Sort chronologically (oldest first)
    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.timeline_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Activity Timeline',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        ...events.asMap().entries.map((entry) {
          final idx = entry.key;
          final event = entry.value;
          final isLast = idx == events.length - 1;
          return _TimelineTile(event: event, isLast: isLast);
        }),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, required this.isLast});

  final _TimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline spine
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: event.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, color: event.iconColor, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: AppColors.divider,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 14, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(event.time.toLocal()),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (event.subtitle != null && event.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.subtitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
