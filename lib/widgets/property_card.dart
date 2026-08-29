import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/property.dart';
import '../services/property_service.dart';
import '../utils/theme.dart';
import 'full_screen_image_viewer.dart';

/// Premium property card matching the existing CRM card design system.
///
/// Uses [FutureBuilder] + [PropertyService.getSignedImageUrl] to load images
/// from a Supabase Storage bucket (works for both public and private buckets).
class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
  });

  final Property property;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  late final Future<String> _imageUrlFuture;

  @override
  void initState() {
    super.initState();
    final service = context.read<PropertyService>();
    final firstPath = widget.property.imagePaths.isNotEmpty
        ? widget.property.imagePaths.first
        : null;
    debugPrint(
        '[PropertyCard] "${widget.property.projectName}" imagePaths=${widget.property.imagePaths}, firstPath=$firstPath');
    if (firstPath != null && firstPath.isNotEmpty) {
      _imageUrlFuture = service.getSignedImageUrl(firstPath);
    } else {
      _imageUrlFuture = Future.value('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;

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
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image / Thumbnail ──
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                  child: FutureBuilder<String>(
                    future: _imageUrlFuture,
                    builder: (ctx, snapshot) {
                      final url = snapshot.data ?? '';
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _loadingImage();
                      }
                      if (url.isEmpty) {
                        debugPrint(
                            '[PropertyCard] "${property.projectName}": empty URL → showing placeholder');
                        return _placeholderImage();
                      }
                      debugPrint(
                          '[PropertyCard] "${property.projectName}": loading image from $url');
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                property: property,
                                initialIndex: 0,
                              ),
                            ),
                          );
                        },
                        child: Image.network(
                          url,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, __) {
                            debugPrint(
                                '[PropertyCard] "${property.projectName}": Image.network ERROR: $error  url=$url');
                            return _placeholderImage();
                          },
                        ),
                      );
                    },
                  ),
                ),

                // ── Card Content ──
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project name + Availability badge + 3-dot menu
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
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'view') widget.onTap();
                              if (value == 'edit') widget.onEdit();
                              if (value == 'delete') widget.onDelete();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility_rounded, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text('View', style: GoogleFonts.poppins(fontSize: 13)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded, size: 18, color: AppColors.statusRed),
                                    const SizedBox(width: 8),
                                    Text('Delete', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.statusRed)),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                            onTap: widget.onTap,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _actionButton(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            onTap: widget.onEdit,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _actionButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: widget.onShare,
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
          .fadeIn(
              delay: Duration(milliseconds: widget.index * 60), duration: 350.ms)
          .slideY(begin: 0.04, curve: Curves.easeOut),
    );
  }

  Widget _loadingImage() {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
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
