import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../screens/customer_details_screen.dart';
import '../services/api_service.dart';
import '../services/customer_service.dart';
import '../utils/theme.dart';
import 'add_customer_bottom_sheet.dart';

/// Premium customer card with swipe, long-press, and tap interactions.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.index,
    this.onDeleted,
    this.onUpdated,
  });

  final Customer customer;
  final int index;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  // ─── Actions ──────────────────────────────────────────────────

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: customer.dialablePhoneNumber);
    if (!await launchUrl(uri)) {
      if (context.mounted) _snack(context, 'Could not open phone dialer.');
    }
  }

  Future<void> _whatsApp(BuildContext context) async {
    String phone = customer.dialablePhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) phone = '91$phone';

    final String message = 'Hello ${customer.customerName},\n'
        'Thank you for your interest in MCP Avadi.\n'
        'We are happy to assist you regarding your property enquiry.\n\n'
        'Regards,\n'
        'T. Meenakshi Sundaram\n'
        'GM Sales - MCP Avadi';
    final String encodedMessage = Uri.encodeComponent(message);

    final Uri businessUri = Uri.parse('intent://send?phone=$phone&text=$encodedMessage#Intent;package=com.whatsapp.w4b;scheme=whatsapp;end');
    final Uri normalUri = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    bool launched = false;
    try {
      launched = await launchUrl(businessUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        launched = await launchUrl(normalUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched && context.mounted) {
      _snack(context, 'Could not open WhatsApp.');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.statusRed,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'Delete Customer?',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently remove ${customer.customerName} from the CRM.',
          style: GoogleFonts.poppins(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddCustomerBottomSheet(existingCustomer: customer),
    ).then((_) => onUpdated?.call());
  }

  void _openLongPressMenu(BuildContext context, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      elevation: 8,
      color: AppColors.surface,
      items: [
        PopupMenuItem(
          value: 'call',
          child: _MenuRow(
              icon: Icons.call_rounded,
              label: 'Call',
              color: AppColors.statusBooked),
        ),
        PopupMenuItem(
          value: 'whatsapp',
          child: _MenuRow(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: const Color(0xFF25D366)),
        ),
        PopupMenuItem(
          value: 'edit',
          child: _MenuRow(
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: AppColors.primary),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
              icon: Icons.delete_rounded,
              label: 'Delete',
              color: AppColors.statusRed),
        ),
      ],
    );

    if (!context.mounted) return;
    switch (selected) {
      case 'call':
        _call(context);
        break;
      case 'whatsapp':
        _whatsApp(context);
        break;
      case 'edit':
        _openEditSheet(context);
        break;
      case 'delete':
        if (await _confirmDelete(context) && context.mounted) {
          try {
            await context.read<CustomerService>().deleteCustomer(customer);
            if (context.mounted) onDeleted?.call();
          } catch (e) {
            if (context.mounted) {
              final errorMsg = e is ApiException ? e.message : e.toString();
              _snack(context, 'Failed to delete: $errorMsg');
            }
          }
        }
        break;
    }
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
    final isBooked = customer.bookingStatus == BookingStatus.booked;
    final isCompleted =
        customer.registrationStatus == RegistrationStatus.completed;

    return Dismissible(
      key: ValueKey(customer.id), // ID is now guaranteed to be unique
      direction: DismissDirection.horizontal,
      background: _buildSwipeBg(
        alignLeft: true,
        color: AppColors.primary,
        icon: Icons.edit_rounded,
        label: 'Edit',
      ),
      secondaryBackground: _buildSwipeBg(
        alignLeft: false,
        color: AppColors.statusRed,
        icon: Icons.delete_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _openEditSheet(context);
          return false; // Don't dismiss — just open edit sheet
        }
        // Swipe-to-delete: confirm first, then perform the delete
        final confirmed = await _confirmDelete(context);
        if (!confirmed) return false;
        
        try {
          await context.read<CustomerService>().deleteCustomer(customer);
          if (context.mounted) onDeleted?.call();
          return false; // Return false — the item is already removed from the list by deleteCustomer
        } catch (e) {
          if (context.mounted) {
            final errorMsg = e is ApiException ? e.message : e.toString();
            _snack(context, 'Failed to delete: $errorMsg');
          }
          return false; // Don't dismiss on failure — customer was restored
        }
      },
      child: GestureDetector(
        onLongPressStart: (d) => _openLongPressMenu(context, d.globalPosition),
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (_, animation, __) => CustomerDetailsScreen(
                customer: customer,
              ),
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
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar ──────────────────────────────────────
                Hero(
                  tag: 'avatar_${customer.id}',
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials(customer.customerName),
                        style: GoogleFonts.poppins(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                // ── Content ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              customer.customerName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            customer.formattedDate,
                            style: GoogleFonts.poppins(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Info rows
                      _InfoLine(
                          icon: Icons.phone_rounded,
                          text: customer.phoneNumber,
                          color: AppColors.statusBooked),
                      _InfoLine(
                          icon: Icons.place_rounded,
                          text: customer.place),
                      _InfoLine(
                          icon: Icons.person_pin_circle_rounded,
                          text: 'Lead: ${customer.leadGivenBy}'),
                      _InfoLine(
                          icon: Icons.villa_rounded,
                          text: 'Site: ${customer.siteVisited}'),

                      const SizedBox(height: AppSpacing.sm),

                      // Status chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatusChip(
                            label: isBooked ? 'Booked' : 'Pending',
                            color: isBooked
                                ? AppColors.statusBooked
                                : AppColors.statusPending,
                            bgColor: isBooked
                                ? AppColors.statusBookedBg
                                : AppColors.statusPendingBg,
                          ),
                          _StatusChip(
                            label: isCompleted ? 'Reg. Done' : 'Reg. Pending',
                            color: isCompleted
                                ? AppColors.statusCompleted
                                : AppColors.statusRed,
                            bgColor: isCompleted
                                ? AppColors.statusCompletedBg
                                : AppColors.statusRedBg,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Arrow ────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 30 * (index % 15)),
        )
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildSwipeBg({
    required bool alignLeft,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.color,
  });
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color ?? AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: color ?? AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bgColor,
  });
  final String label;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
