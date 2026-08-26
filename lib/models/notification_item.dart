import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../utils/theme.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String customerName;
  final DateTime? date;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Customer customer;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.customerName,
    this.date,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.customer,
  });

  static List<NotificationItem> getNotifications(CustomerService service) {
    final List<NotificationItem> items = [];
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    for (final c in service.allCustomersUnfiltered) {
      if (c.followUpDate != null) {
        final fDate = c.followUpDate!.toLocal();
        final followUpStart = DateTime(fDate.year, fDate.month, fDate.day);
        
        final id = '${c.id}_${fDate.toIso8601String()}';

        if (c.followUpCompleted) {
            if (c.followUpCompletedAt != null) {
               final cDate = c.followUpCompletedAt!.toLocal();
               if (DateTime(cDate.year, cDate.month, cDate.day).isAtSameMomentAs(todayStart)) {
                 items.add(NotificationItem(
                    id: '${id}_completed',
                    title: 'Follow-up Completed',
                    message: 'Completed follow-up for',
                    customerName: c.customerName,
                    date: c.followUpCompletedAt,
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.statusBooked,
                    iconBg: AppColors.statusBookedBg,
                    customer: c,
                 ));
               }
            }
        } else {
            if (followUpStart.isBefore(todayStart)) {
                items.add(NotificationItem(
                    id: '${id}_overdue',
                    title: 'Overdue Follow-up',
                    message: 'Follow-up is overdue for',
                    customerName: c.customerName,
                    date: c.followUpDate,
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.statusRed,
                    iconBg: AppColors.statusRedBg,
                    customer: c,
                ));
            } else if (followUpStart.isAtSameMomentAs(todayStart)) {
                items.add(NotificationItem(
                    id: '${id}_today',
                    title: 'Follow-up Today',
                    message: 'Scheduled follow-up with',
                    customerName: c.customerName,
                    date: c.followUpDate,
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppColors.statusPending,
                    iconBg: AppColors.statusPendingBg,
                    customer: c,
                ));
            } else if (followUpStart.isBefore(todayStart.add(const Duration(days: 3)))) {
                items.add(NotificationItem(
                    id: '${id}_upcoming',
                    title: 'Upcoming Follow-up',
                    message: 'Upcoming follow-up with',
                    customerName: c.customerName,
                    date: c.followUpDate,
                    icon: Icons.event_rounded,
                    iconColor: AppColors.statusUpcoming,
                    iconBg: AppColors.statusUpcomingBg,
                    customer: c,
                ));
            }
        }
      }
    }

    items.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
    return items;
  }
}
