import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';

/// Beautiful empty state illustration shown when there are no customers
/// or a search returns no results.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.isSearchResult = false});

  final bool isSearchResult;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.gold.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isSearchResult
                          ? AppColors.statusCompletedBg
                          : AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    isSearchResult
                        ? Icons.search_off_rounded
                        : Icons.groups_2_rounded,
                    size: 52,
                    color: isSearchResult
                        ? AppColors.statusCompleted
                        : AppColors.primary,
                  ),
                ],
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              isSearchResult ? 'No Matches Found' : 'No Customers Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            Text(
              isSearchResult
                  ? 'Try a different name, phone number,\nplace, or lead source.'
                  : 'Tap the gold button below to add\nyour first customer lead.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

            if (!isSearchResult) ...[
              const SizedBox(height: AppSpacing.xl),
              // Decorative arrow hint
              Column(
                children: [
                  const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.gold, size: 32)
                      .animate(onPlay: (c) => c.repeat())
                      .moveY(
                          begin: -6,
                          end: 6,
                          duration: 800.ms,
                          curve: Curves.easeInOut),
                  Text(
                    'Add Customer',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms),
            ],
          ],
        ),
      ),
    );
  }
}
