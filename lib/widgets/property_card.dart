import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/property.dart';
import '../services/property_service.dart';
import '../utils/theme.dart';

/// Premium property card matching the existing CRM card design system.
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });

  final Property property;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final service = context.read<PropertyService>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image / Thumbnail ──
                if (property.imagePaths.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg)),
                    child: Image.network(
                      service.getImageUrl(property.imagePaths.first),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderImage(),
                    ),
                  ),
                ] else ...[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg)),
                    child: _placeholderImage(),
                  ),
                ],

                // ── Card Content ──
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project name + Availability badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              property.projectName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _availabilityBadge(property.availability),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Location
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.location,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Price & Plot sizes row
                      Row(
                        children: [
                          if (property.pricePerSqft != null) ...[
                            _infoChip(
                              icon: Icons.currency_rupee_rounded,
                              label: '${property.formattedPrice}/sq.ft',
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          if (property.plotSizes.isNotEmpty)
                            _infoChip(
                              icon: Icons.square_foot_rounded,
                              label:
                                  '${property.plotSizes.length} Size${property.plotSizes.length != 1 ? 's' : ''}',
                              color: AppColors.gold,
                            ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.sm),

                      // Quick Actions
                      Row(
                        children: [
                          _actionButton(
                            icon: Icons.visibility_rounded,
                            label: 'View',
                            onTap: onTap,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _actionButton(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            onTap: onEdit,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _actionButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: onShare,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: index * 60), duration: 350.ms)
          .slideY(begin: 0.04, curve: Curves.easeOut),
    );
  }

  Widget _placeholderImage() {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment_rounded,
              size: 42, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 6),
          Text(
            'No Image',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityBadge(PropertyAvailability availability) {
    Color bg;
    Color fg;
    switch (availability) {
      case PropertyAvailability.available:
        bg = AppColors.statusBookedBg;
        fg = AppColors.statusBooked;
        break;
      case PropertyAvailability.limitedAvailability:
        bg = AppColors.statusPendingBg;
        fg = AppColors.statusPending;
        break;
      case PropertyAvailability.soldOut:
        bg = AppColors.statusRedBg;
        fg = AppColors.statusRed;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        availability.label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
