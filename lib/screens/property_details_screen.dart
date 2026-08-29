import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/property.dart';
import '../services/property_service.dart';
import '../utils/theme.dart';
import '../widgets/add_property_bottom_sheet.dart';

/// Full detail view for a single [Property].
class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({super.key, required this.property});

  final Property property;

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late final Future<List<String>> _signedUrlsFuture;
  Property get property => widget.property;

  @override
  void initState() {
    super.initState();
    final service = context.read<PropertyService>();
    debugPrint('[Detail] imagePaths for "${property.projectName}": ${property.imagePaths}');
    if (property.imagePaths.isNotEmpty) {
      _signedUrlsFuture = Future.wait(
        property.imagePaths.map((p) => service.getSignedImageUrl(p)).toList(),
      ).then((urls) => urls.where((u) => u.isNotEmpty).toList());
    } else {
      _signedUrlsFuture = Future.value([]);
    }
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddPropertyBottomSheet(existingProperty: property),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('Delete Property?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete "${property.projectName}" and all associated images from storage. This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            child: Text('Delete',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<PropertyService>().deleteProperty(property);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Property deleted.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete property. Try again.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            backgroundColor: AppColors.statusRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ));
        }
      }
    }
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln('🏘 *${property.projectName}*');
    buffer.writeln('📍 ${property.location}');
    if (property.description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(property.description);
    }
    if (property.pricePerSqft != null) {
      buffer.writeln();
      buffer.writeln('💰 Price: ${property.formattedPrice}/sq.ft');
    }
    if (property.offerPricePerSqft != null) {
      buffer.writeln('🏷 Offer: ${property.formattedOfferPrice}/sq.ft');
    }
    if (property.plotSizes.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📐 Available Sizes:');
      for (final size in property.plotSizes) {
        buffer.writeln('  • $size sq.ft');
      }
    }
    buffer.writeln();
    buffer.writeln('✅ Availability: ${property.availability.label}');
    if (property.amenities.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🏡 Amenities:');
      for (final a in property.amenities) {
        buffer.writeln('  • $a');
      }
    }
    final approvalLines = <String>[
      if (property.approvalType.isNotEmpty) 'Type: ${property.approvalType}',
      if (property.approvalNumber.isNotEmpty)
        'No: ${property.approvalNumber}',
      if (property.approvalAuthority.isNotEmpty)
        'Authority: ${property.approvalAuthority}',
      if (property.approvalNotes.isNotEmpty) property.approvalNotes,
    ];
    if (approvalLines.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📋 Approval:');
      for (final line in approvalLines) {
        buffer.writeln('  $line');
      }
    }
    buffer.writeln();
    buffer.writeln('— MCP Avadi, Madras City Properties');
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<String>>(
        future: _signedUrlsFuture,
        builder: (context, snapshot) {
          final signedUrls = snapshot.data ?? [];
          return _buildBody(context, signedUrls);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<String> signedUrls) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // SliverAppBar with images
        SliverAppBar(
          expandedHeight: signedUrls.isNotEmpty ? 260 : 80,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
              title: Text(
                property.projectName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: signedUrls.isNotEmpty
                  ? _imageCarousel(signedUrls)
                  : Container(color: AppColors.primaryDark),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => _openEditSheet(context),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.white),
                onPressed: () => _confirmDelete(context),
                tooltip: 'Delete',
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.location,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),

                      // Availability badge
                      const SizedBox(height: 12),
                      _availabilityBadge(property.availability),

                      // Description
                      if (property.description.isNotEmpty) ...[
                        _sectionTitle('Description'),
                        Text(
                          property.description,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.6),
                        ),
                      ],

                      // Pricing
                      if (property.pricePerSqft != null ||
                          property.offerPricePerSqft != null) ...[
                        _sectionTitle('Pricing'),
                        Row(
                          children: [
                            if (property.pricePerSqft != null)
                              _infoCard('Price',
                                  '${property.formattedPrice}/sq.ft',
                                  AppColors.primary),
                            if (property.pricePerSqft != null &&
                                property.offerPricePerSqft != null)
                              const SizedBox(width: 12),
                            if (property.offerPricePerSqft != null)
                              _infoCard('Offer Price',
                                  '${property.formattedOfferPrice}/sq.ft',
                                  AppColors.gold),
                          ],
                        ),
                      ],

                      // Plot sizes
                      if (property.plotSizes.isNotEmpty) ...[
                        _sectionTitle('Available Sizes'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: property.plotSizes
                              .map((size) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      '$size sq.ft',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],

                      // Amenities
                      if (property.amenities.isNotEmpty) ...[
                        _sectionTitle('Amenities'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: property.amenities
                              .map((a) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      a,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.goldDark),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],

                      // Approval
                      if (property.approvalType.isNotEmpty ||
                          property.approvalNumber.isNotEmpty ||
                          property.approvalAuthority.isNotEmpty ||
                          property.approvalNotes.isNotEmpty) ...[
                        _sectionTitle('Approval Details'),
                        _approvalBlock(),
                      ],

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openEditSheet(context),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showShareSheet(context),
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon: Icon(Icons.delete_rounded,
                              size: 16, color: AppColors.statusRed),
                          label: Text('Delete Property',
                              style: GoogleFonts.poppins(
                                  color: AppColors.statusRed,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side:
                                BorderSide(color: AppColors.statusRed),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04),
          ),
        ],
      );
  }

  Widget _imageCarousel(List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
      itemCount: imageUrls.length,
      itemBuilder: (_, index) {
        return Image.network(
          imageUrls[index],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.primaryDark,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment_rounded,
                    size: 64, color: AppColors.gold.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  'No Image',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.3),
      ),
    );
  }

  Widget _infoCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(availability.label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _approvalBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (property.approvalType.isNotEmpty)
            _approvalRow('Type', property.approvalType),
          if (property.approvalNumber.isNotEmpty)
            _approvalRow('Number', property.approvalNumber),
          if (property.approvalAuthority.isNotEmpty)
            _approvalRow('Authority', property.approvalAuthority),
          if (property.approvalNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                property.approvalNotes,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _approvalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    final shareText = _buildShareText();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share Property',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Choose how to share "${property.projectName}"',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _shareOption(
                    ctx: ctx,
                    icon: Icons.copy_rounded,
                    label: 'Copy Text',
                    color: AppColors.primary,
                    onTap: () async {
                      await Clipboard.setData(
                          ClipboardData(text: shareText));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Copied to clipboard.',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.white)),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm)),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _shareOption(
                    ctx: ctx,
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final encoded = Uri.encodeComponent(shareText);
                      final uri =
                          Uri.parse('https://wa.me/?text=$encoded');
                      try {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Could not open WhatsApp.',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.white)),
                          backgroundColor: AppColors.statusRed,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm)),
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _shareOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
