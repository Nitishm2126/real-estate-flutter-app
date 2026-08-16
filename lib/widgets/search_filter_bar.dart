import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/customer_service.dart';
import '../utils/theme.dart';

/// Combined search bar + sort/filter chip row.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.soft,
          ),
          child: TextField(
            onChanged: service.setSearchQuery,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search name, phone, place, lead by…',
              hintStyle: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.gold, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Newest',
                mode: SortMode.newest,
                current: service.sortMode,
                icon: Icons.arrow_downward_rounded,
                onTap: () => service.setSortMode(SortMode.newest),
              ),
              _FilterChip(
                label: 'Oldest',
                mode: SortMode.oldest,
                current: service.sortMode,
                icon: Icons.arrow_upward_rounded,
                onTap: () => service.setSortMode(SortMode.oldest),
              ),
              _FilterChip(
                label: 'A–Z',
                mode: SortMode.alphabetical,
                current: service.sortMode,
                icon: Icons.sort_by_alpha_rounded,
                onTap: () => service.setSortMode(SortMode.alphabetical),
              ),
              _FilterChip(
                label: 'Booked',
                mode: SortMode.booked,
                current: service.sortMode,
                icon: Icons.bookmark_added_rounded,
                onTap: () => service.setSortMode(SortMode.booked),
              ),
              _FilterChip(
                label: 'Pending',
                mode: SortMode.pending,
                current: service.sortMode,
                icon: Icons.pending_rounded,
                onTap: () => service.setSortMode(SortMode.pending),
              ),
              _FilterChip(
                label: 'Reg. Done',
                mode: SortMode.completedReg,
                current: service.sortMode,
                icon: Icons.verified_rounded,
                onTap: () => service.setSortMode(SortMode.completedReg),
              ),
              _FilterChip(
                label: 'Reg. Pending',
                mode: SortMode.pendingReg,
                current: service.sortMode,
                icon: Icons.pending_actions_rounded,
                onTap: () => service.setSortMode(SortMode.pendingReg),
              ),
              // Follow-up Filters
              _FilterChip(
                label: 'All Follow-ups',
                mode: SortMode.followUpsAll,
                current: service.sortMode,
                icon: Icons.event_available_rounded,
                onTap: () => service.setSortMode(SortMode.followUpsAll),
              ),
              _FilterChip(
                label: 'F. Today',
                mode: SortMode.followUpsToday,
                current: service.sortMode,
                icon: Icons.notifications_active_rounded,
                onTap: () => service.setSortMode(SortMode.followUpsToday),
              ),
              _FilterChip(
                label: 'F. Upcoming',
                mode: SortMode.followUpsUpcoming,
                current: service.sortMode,
                icon: Icons.calendar_month_rounded,
                onTap: () => service.setSortMode(SortMode.followUpsUpcoming),
              ),
              _FilterChip(
                label: 'F. Overdue',
                mode: SortMode.followUpsOverdue,
                current: service.sortMode,
                icon: Icons.warning_rounded,
                onTap: () => service.setSortMode(SortMode.followUpsOverdue),
              ),
              _FilterChip(
                label: 'F. Completed',
                mode: SortMode.followUpsCompleted,
                current: service.sortMode,
                icon: Icons.check_circle_rounded,
                onTap: () => service.setSortMode(SortMode.followUpsCompleted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.mode,
    required this.current,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final SortMode mode, current;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = mode == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
            width: isActive ? 0 : 1,
          ),
          boxShadow: isActive ? AppShadows.soft : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.gold : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
