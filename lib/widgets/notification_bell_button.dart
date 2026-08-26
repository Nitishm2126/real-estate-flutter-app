import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/customer_service.dart';
import '../utils/theme.dart';
import '../screens/customer_details_screen.dart';
import '../models/notification_item.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final MenuController _menuController = MenuController();
  
  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();
    final notifications = NotificationItem.getNotifications(service);
    final unreadCount = notifications.where((n) => !service.readNotificationIds.contains(n.id)).length;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-280, 10),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.surface),
        elevation: WidgetStateProperty.all(AppShadows.card.first.blurRadius * 2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        )),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
              if (unreadCount > 0)
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
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: GoogleFonts.poppins(fontSize: 8, color: AppColors.primaryDark, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      menuChildren: [
        SizedBox(
          width: 350,
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (unreadCount > 0)
                      InkWell(
                        onTap: () => service.markAllNotificationsAsRead(notifications.map((n) => n.id).toList()),
                        child: Text(
                          'Mark all as read',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              "You're all caught up!",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          final isRead = service.readNotificationIds.contains(item.id);

                          return InkWell(
                            onTap: () {
                              service.markNotificationAsRead(item.id);
                              if (_menuController.isOpen) {
                                _menuController.close();
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailsScreen(customer: item.customer),
                                ),
                              );
                            },
                            child: Container(
                              color: isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.05),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: item.iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(item.icon, color: item.iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
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
                                                  fontSize: 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (item.date != null)
                                              Text(
                                                DateFormat('MMM d, h:mm a').format(item.date!),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
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
                                      margin: const EdgeInsets.only(left: 8, top: 4),
                                      width: 8,
                                      height: 8,
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
