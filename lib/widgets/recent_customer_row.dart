import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer.dart';
import '../screens/customer_details_screen.dart';
import '../utils/theme.dart';

class RecentCustomerRow extends StatelessWidget {
  const RecentCustomerRow({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    // Generate avatar initial
    final initial = customer.customerName.isNotEmpty
        ? customer.customerName.substring(0, 1).toUpperCase()
        : '?';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerDetailsScreen(customer: customer),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name & Phone
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.customerName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    customer.phoneNumber,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Location
            Expanded(
              flex: 1,
              child: Text(
                customer.place,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Pills
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusPill(
                  customer.bookingStatus == BookingStatus.booked ? 'Booked' : 'Pending',
                  customer.bookingStatus == BookingStatus.booked ? AppColors.statusBooked : AppColors.statusPending,
                  customer.bookingStatus == BookingStatus.booked ? AppColors.statusBookedBg : AppColors.statusPendingBg,
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  customer.registrationStatus == RegistrationStatus.completed ? 'Reg. Done' : 'Reg. Pending',
                  customer.registrationStatus == RegistrationStatus.completed ? AppColors.statusPurple : AppColors.statusUpcoming,
                  customer.registrationStatus == RegistrationStatus.completed ? AppColors.statusPurpleBg : AppColors.statusUpcomingBg,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
