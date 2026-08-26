import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/customer_service.dart';
import '../models/notification_item.dart';
import '../utils/theme.dart';
import 'customer_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerService>(
      builder: (context, service, child) {
        final notifications = NotificationItem.getNotifications(service);
        final unreadCount = notifications.where((n) => !service.readNotificationIds.contains(n.id)).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Notifications',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            actions: [
              if (unreadCount > 0)
                TextButton(
                  onPressed: () => service.markAllNotificationsAsRead(notifications.map((n) => n.id).toList()),
                  child: Text(
                    'Mark all as read',
                    style: GoogleFonts.poppins(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        "You're all caught up!",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 160),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final isRead = service.readNotificationIds.contains(item.id);

                    return InkWell(
                      onTap: () {
                        service.markNotificationAsRead(item.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailsScreen(customer: item.customer),
                          ),
                        );
                      },
                      child: Container(
                        color: isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: item.iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, color: item.iconColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: GoogleFonts.poppins(
                                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (item.date != null)
                                        Text(
                                          DateFormat('MMM d, h:mm a').format(item.date!),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      children: [
                                        TextSpan(text: '${item.message} '),
                                        TextSpan(
                                          text: item.customerName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                margin: const EdgeInsets.only(left: 12, top: 6),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
