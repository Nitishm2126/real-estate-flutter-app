import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/property.dart';
import '../services/property_service.dart';
import '../utils/theme.dart';

/// Bottom sheet for adding or editing a [Property].
///
/// Pass [existingProperty] to switch to edit mode.
class AddPropertyBottomSheet extends StatefulWidget {
  const AddPropertyBottomSheet({super.key, this.existingProperty});

  final Property? existingProperty;

  @override
  State<AddPropertyBottomSheet> createState() => _AddPropertyBottomSheetState();
}

class _AddPropertyBottomSheetState extends State<AddPropertyBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // ── Controllers ───────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _offerPriceCtrl;
  late final TextEditingController _approvalTypeCtrl;
  late final TextEditingController _approvalNumberCtrl;
  late final TextEditingController _approvalAuthorityCtrl;
  late final TextEditingController _approvalNotesCtrl;

  // ── Dynamic lists ─────────────────────────────────────────────
  late List<TextEditingController> _plotSizeCtrls;
  late List<String> _amenities;
  final TextEditingController _amenityInputCtrl = TextEditingController();

  // ── Availability ──────────────────────────────────────────────
  late PropertyAvailability _availability;

  // ── Images ────────────────────────────────────────────────────
  /// Existing Supabase Storage paths (already uploaded from edit mode)
  late List<String> _existingImagePaths;

  /// Newly picked local XFile paths (not yet uploaded)
  final List<XFile> _newLocalImages = [];

  /// Paths that the user explicitly removed from the existing set
  final List<String> _removedStoragePaths = [];

  final ImagePicker _picker = ImagePicker();

  // ─────────────────────────────────────────────────────────────

  bool get _isEditMode => widget.existingProperty != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProperty;
    _nameCtrl = TextEditingController(text: p?.projectName ?? '');
    _locationCtrl = TextEditingController(text: p?.location ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl =
        TextEditingController(text: p?.pricePerSqft?.toString() ?? '');
    _offerPriceCtrl =
        TextEditingController(text: p?.offerPricePerSqft?.toString() ?? '');
    _approvalTypeCtrl = TextEditingController(text: p?.approvalType ?? '');
    _approvalNumberCtrl = TextEditingController(text: p?.approvalNumber ?? '');
    _approvalAuthorityCtrl =
        TextEditingController(text: p?.approvalAuthority ?? '');
    _approvalNotesCtrl = TextEditingController(text: p?.approvalNotes ?? '');

    // Plot sizes – seed from existing or one empty row
    _plotSizeCtrls = (p?.plotSizes.isNotEmpty == true)
        ? p!.plotSizes.map((s) => TextEditingController(text: s)).toList()
        : [TextEditingController()];

    _amenities = List<String>.from(p?.amenities ?? []);
    _availability = p?.availability ?? PropertyAvailability.available;
    _existingImagePaths = List<String>.from(p?.imagePaths ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _offerPriceCtrl.dispose();
    _approvalTypeCtrl.dispose();
    _approvalNumberCtrl.dispose();
    _approvalAuthorityCtrl.dispose();
    _approvalNotesCtrl.dispose();
    _amenityInputCtrl.dispose();
    for (final c in _plotSizeCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Image picking ────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked.isEmpty) return;
      setState(() => _newLocalImages.addAll(picked));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not access photos. Please check permissions.', isError: true);
    }
  }

  void _removeExistingImage(String storagePath) {
    setState(() {
      _existingImagePaths.remove(storagePath);
      _removedStoragePaths.add(storagePath);
    });
  }

  void _removeNewImage(int index) {
    setState(() => _newLocalImages.removeAt(index));
  }

  // ─── Amenities ────────────────────────────────────────────────

  void _addAmenity() {
    final text = _amenityInputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_amenities.contains(text)) {
      _amenityInputCtrl.clear();
      return;
    }
    setState(() {
      _amenities.add(text);
      _amenityInputCtrl.clear();
    });
  }

  void _removeAmenity(String amenity) {
    setState(() => _amenities.remove(amenity));
  }

  // ─── Plot sizes ───────────────────────────────────────────────

  void _addPlotSize() {
    setState(() => _plotSizeCtrls.add(TextEditingController()));
  }

  void _removePlotSize(int index) {
    if (_plotSizeCtrls.length <= 1) return; // keep at least one row
    setState(() {
      _plotSizeCtrls[index].dispose();
      _plotSizeCtrls.removeAt(index);
    });
  }

  // ─── Save ─────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final service = context.read<PropertyService>();

      final plotSizes = _plotSizeCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final property = Property(
        id: widget.existingProperty?.id,
        projectName: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        pricePerSqft: double.tryParse(_priceCtrl.text.trim()),
        offerPricePerSqft: double.tryParse(_offerPriceCtrl.text.trim()),
        plotSizes: plotSizes,
        availability: _availability,
        // imagePaths will be set inside service methods
        imagePaths: _existingImagePaths,
        amenities: _amenities,
        approvalType: _approvalTypeCtrl.text.trim(),
        approvalNumber: _approvalNumberCtrl.text.trim(),
        approvalAuthority: _approvalAuthorityCtrl.text.trim(),
        approvalNotes: _approvalNotesCtrl.text.trim(),
      );

      final localPaths = _newLocalImages.map((f) => f.path).toList();

      if (_isEditMode) {
        await service.updateProperty(
          property,
          newImages: _newLocalImages,
          newLocalImagePaths: localPaths,
          removedStoragePaths: _removedStoragePaths,
        );
      } else {
        await service.addProperty(
          property,
          newImages: _newLocalImages,
          localImagePaths: localPaths,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar(
        _isEditMode ? 'Property updated.' : 'Property added.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save property: ${e.toString().replaceAll('PostgrestException', '').replaceAll('Exception:', '').trim()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.apartment_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditMode ? 'Edit Property' : 'Add Property',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _sectionHeader('Basic Details'),
                  _field('Project Name *', _nameCtrl,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                  _field('Location *', _locationCtrl,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                  _field('Description', _descCtrl, maxLines: 3),

                  _sectionHeader('Pricing'),
                  Row(
                    children: [
                      Expanded(
                        child: _field('Price / sq.ft', _priceCtrl,
                            prefix: '₹',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field('Offer Price / sq.ft', _offerPriceCtrl,
                            prefix: '₹',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ]),
                      ),
                    ],
                  ),

                  _sectionHeader('Plot / Unit Sizes'),
                  ..._buildPlotSizeRows(),
                  TextButton.icon(
                    onPressed: _addPlotSize,
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primary, size: 18),
                    label: Text('Add Size',
                        style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),

                  _sectionHeader('Availability'),
                  _availabilityDropdown(),

                  _sectionHeader('Images'),
                  _buildImageSection(),

                  _sectionHeader('Amenities'),
                  _buildAmenitiesSection(),

                  _sectionHeader('Approval Details'),
                  _field('Approval Type', _approvalTypeCtrl),
                  _field('Approval Number', _approvalNumberCtrl),
                  _field('Approval Authority', _approvalAuthorityCtrl),
                  _field('Additional Notes', _approvalNotesCtrl, maxLines: 3),

                  const SizedBox(height: 24),
                  _saveButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section builders ────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.4,
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefix,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixIcon: suffix,
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  List<Widget> _buildPlotSizeRows() {
    return List.generate(_plotSizeCtrls.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _plotSizeCtrls[i],
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Size ${i + 1} (sq.ft)',
                  suffixText: 'sq.ft',
                  labelStyle: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ),
            if (_plotSizeCtrls.length > 1)
              IconButton(
                icon: Icon(Icons.remove_circle_outline_rounded,
                    color: AppColors.statusRed, size: 20),
                onPressed: () => _removePlotSize(i),
              ),
          ],
        ),
      );
    });
  }

  Widget _availabilityDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<PropertyAvailability>(
        initialValue: _availability,
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
        dropdownColor: AppColors.surface,
        decoration: InputDecoration(
          labelText: 'Availability',
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        items: PropertyAvailability.values
            .map((a) => DropdownMenuItem(
                  value: a,
                  child: Text(a.label, style: GoogleFonts.poppins(fontSize: 14)),
                ))
            .toList(),
        onChanged: (val) {
          if (val != null) setState(() => _availability = val);
        },
      ),
    );
  }

  Widget _buildImageSection() {
    final totalCount = _existingImagePaths.length + _newLocalImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalCount > 0) ...[
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing uploaded images
                ..._existingImagePaths.asMap().entries.map((entry) {
                  final path = entry.value;
                  final service = context.read<PropertyService>();
                  return _imageThumbnail(
                    imageWidget: Image.network(
                      service.getImageUrl(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_rounded),
                    ),
                    onRemove: () => _removeExistingImage(path),
                  );
                }),
                // New local images (not yet uploaded)
                ..._newLocalImages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final xfile = entry.value;
                  return _imageThumbnail(
                    imageWidget: kIsWeb
                        ? Image.network(xfile.path, fit: BoxFit.cover)
                        : Image.file(File(xfile.path), fit: BoxFit.cover),
                    onRemove: () => _removeNewImage(idx),
                    isNew: true,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: Icon(Icons.add_photo_alternate_outlined,
              color: AppColors.primary, size: 18),
          label: Text(
            totalCount == 0 ? 'Select Images' : 'Add More Images',
            style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Images upload when you save the property.',
          style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _imageThumbnail({
    required Widget imageWidget,
    required VoidCallback onRemove,
    bool isNew = false,
  }) {
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color:
              isNew ? AppColors.primary.withValues(alpha: 0.4) : AppColors.divider,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm - 1),
            child: imageWidget,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
          if (isNew)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('NEW',
                    style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_amenities.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenities
                .map((a) => InputChip(
                      label: Text(a,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.primary)),
                      deleteIcon: Icon(Icons.close_rounded,
                          size: 14, color: AppColors.primary),
                      onDeleted: () => _removeAmenity(a),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.08),
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                      deleteIconColor: AppColors.primary,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _amenityInputCtrl,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Add amenity',
                  labelStyle: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                onFieldSubmitted: (_) => _addAmenity(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addAmenity,
              icon: const Icon(Icons.add_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ))
            : Text(
                _isEditMode ? 'Save Changes' : 'Add Property',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
      ),
    );
  }
}
