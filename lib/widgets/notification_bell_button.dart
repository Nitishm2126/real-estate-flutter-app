import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/customer_service.dart';
import '../models/customer.dart';
import '../utils/theme.dart';
import '../screens/customer_details_screen.dart';

class _NotificationItem {
  final String id;
  final String title;
  final String message;
  final String customerName;
  final DateTime? date;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Customer customer;

  _NotificationItem({
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
}

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final Set<String> _readIds = {};
  final MenuController _menuController = MenuController();
  
  List<_NotificationItem> _getNotifications(CustomerService service) {
    final List<_NotificationItem> items = [];
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
                 items.add(_NotificationItem(
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
                items.add(_NotificationItem(
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
                items.add(_NotificationItem(
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
                items.add(_NotificationItem(
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

  void _markAsRead(String id) {
    setState(() {
      _readIds.add(id);
    });
  }

  void _markAllAsRead(List<_NotificationItem> items) {
    setState(() {
      _readIds.addAll(items.map((e) => e.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();
    final notifications = _getNotifications(service);
    final unreadCount = notifications.where((n) => !_readIds.contains(n.id)).length;

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
                        onTap: () => _markAllAsRead(notifications),
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
                          final isRead = _readIds.contains(item.id);

                          return InkWell(
                            onTap: () {
                              _markAsRead(item.id);
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
