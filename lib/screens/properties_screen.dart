import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/property.dart';
import '../screens/property_details_screen.dart';
import '../services/property_service.dart';
import '../utils/theme.dart';
import '../widgets/add_property_bottom_sheet.dart';
import '../widgets/property_card.dart';

/// Main Properties list screen accessible from the More menu.
class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  PropertyAvailability? _filterAvailability;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PropertyService>().initialize();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddSheet({Property? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => AddPropertyBottomSheet(existingProperty: existing),
    );
  }

  Future<void> _confirmDelete(Property property) async {
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

    if (confirmed == true && mounted) {
      try {
        await context.read<PropertyService>().deleteProperty(property);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(_snackBar('Property deleted.'));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              _snackBar('Failed to delete property. Try again.', isError: true));
        }
      }
    }
  }

  String _buildShareText(Property property) {
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

  void _shareProperty(Property property) {
    final shareText = _buildShareText(property);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    icon: Icons.copy_rounded,
                    label: 'Copy Text',
                    color: AppColors.primary,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(_snackBar(
                          'Property details copied to clipboard.'));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _shareOption(
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
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          _snackBar('Could not open WhatsApp.',
                              isError: true),
                        );
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

  SnackBar _snackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Text(message,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm)),
    );
  }

  Widget _shareOption({
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

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertyService>(
      builder: (context, service, _) {
        List<Property> properties = service.properties;

        // Apply local availability filter on top of search
        if (_filterAvailability != null) {
          properties = properties
              .where((p) => p.availability == _filterAvailability)
              .toList();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Properties',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            actions: [
              if (service.isSyncing)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add_property_fab',
            onPressed: () => _openAddSheet(),
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text('Add Property',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            strokeWidth: 2.5,
            onRefresh: () => service.syncWithDatabase(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                // Search bar
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: service.setSearchQuery,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by name or location…',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textMuted),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppColors.textMuted, size: 20),
                        suffixIcon: service.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  service.setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Filter chips
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(null, 'All'),
                          ...PropertyAvailability.values
                              .map((a) => _filterChip(a, a.label)),
                        ],
                      ),
                    ),
                  ),
                ),

                // Count label
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${properties.length} Propert${properties.length != 1 ? 'ies' : 'y'}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Content
                if (service.isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (service.errorMessage != null && properties.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _errorState(service),
                  )
                else if (properties.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(service),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList.builder(
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final p = properties[index];
                        return PropertyCard(
                          property: p,
                          index: index,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PropertyDetailsScreen(property: p),
                            ),
                          ),
                          onEdit: () => _openAddSheet(existing: p),
                          onShare: () => _shareProperty(p),
                          onDelete: () => _confirmDelete(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(PropertyAvailability? value, String label) {
    final isSelected = _filterAvailability == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterAvailability = value),
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : AppColors.divider.withValues(alpha: 0.6)),
        showCheckmark: false,
      ),
    );
  }

  Widget _emptyState(PropertyService service) {
    final hasFilter = _filterAvailability != null ||
        service.searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.gold.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilter
                    ? Icons.search_off_rounded
                    : Icons.apartment_rounded,
                size: 52,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .fadeIn(),
            const SizedBox(height: 24),
            Text(
              hasFilter
                  ? 'No Matching Properties'
                  : 'No Properties Added Yet',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try adjusting your search or filters.'
                  : 'Add your first property to get started.',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _errorState(PropertyService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.statusRed),
            const SizedBox(height: 16),
            Text(
              service.errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: service.syncWithDatabase,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
