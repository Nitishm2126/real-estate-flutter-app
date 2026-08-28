import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/follow_up.dart';
import '../services/customer_service.dart';
import '../utils/theme.dart';

/// Premium bottom sheet for adding / editing a customer.
/// Passing [existingCustomer] switches to edit mode.
class AddCustomerBottomSheet extends StatefulWidget {
  const AddCustomerBottomSheet(
      {super.key,
      this.existingCustomer,
      this.isSchedulingNextFollowUp = false});

  final Customer? existingCustomer;
  final bool isSchedulingNextFollowUp;

  @override
  State<AddCustomerBottomSheet> createState() => _AddCustomerBottomSheetState();
}

class _AddCustomerBottomSheetState extends State<AddCustomerBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _leadByCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime _selectedDate;
  late BookingStatus _bookingStatus;
  late RegistrationStatus _registrationStatus;

  late final TextEditingController _followUpNotesCtrl;
  DateTime? _followUpDate;
  TimeOfDay? _followUpTime;

  bool _isSaving = false;
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  bool get _isEditing => widget.existingCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCustomer;
    _nameCtrl = TextEditingController(text: c?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: c?.phoneNumber ?? '');
    _placeCtrl = TextEditingController(text: c?.place ?? '');
    _leadByCtrl = TextEditingController(text: c?.leadGivenBy ?? '');
    _siteCtrl = TextEditingController(text: c?.siteVisited ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _selectedDate = c?.date ?? DateTime.now();
    _bookingStatus = c?.bookingStatus ?? BookingStatus.pending;
    _registrationStatus = c?.registrationStatus ?? RegistrationStatus.pending;

    _followUpNotesCtrl = TextEditingController(text: c?.followUpNotes ?? '');
    _followUpDate = c?.followUpDate;

    if (widget.isSchedulingNextFollowUp) {
      _followUpNotesCtrl.clear();
      _followUpDate = null;
      _followUpTime = null;
    } else {
      if (c?.followUpTime != null && c!.followUpTime!.isNotEmpty) {
        try {
          final parsed = DateFormat.jm().parse(c.followUpTime!);
          _followUpTime = TimeOfDay.fromDateTime(parsed);
        } catch (e) {
          _followUpTime = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _placeCtrl.dispose();
    _leadByCtrl.dispose();
    _siteCtrl.dispose();
    _notesCtrl.dispose();
    _followUpNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                secondary: AppColors.gold,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickContact() async {
    // 1. Web safety check
    if (kIsWeb) {
      if (!mounted) return;
      _showContactSnackBar(
        message: 'Contact import is available on Android devices.',
        isError: false,
      );
      return;
    }

    // 2. Permission check on Mobile (Android / iOS)
    try {
      var status = await Permission.contacts.status;
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        _showContactSnackBar(
          message: 'Enable Contacts permission in Android Settings to import a number.',
          isError: true,
          actionLabel: 'Settings',
          onActionPressed: () => openAppSettings(),
        );
        return;
      }

      if (!status.isGranted) {
        status = await Permission.contacts.request();
        if (status.isPermanentlyDenied) {
          if (!mounted) return;
          _showContactSnackBar(
            message: 'Enable Contacts permission in Android Settings to import a number.',
            isError: true,
            actionLabel: 'Settings',
            onActionPressed: () => openAppSettings(),
          );
          return;
        }
        if (!status.isGranted) {
          if (!mounted) return;
          _showContactSnackBar(
            message: 'Contacts permission is required to import a phone number.',
            isError: true,
          );
          return;
        }
      }

      // 3. Open Native Contact Picker
      final contact = await _contactPicker.selectContact();
      
      // User cancelled picker -> silently return without error
      if (contact == null) {
        return;
      }

      // 4. Validate phone numbers
      if (contact.phoneNumbers == null || contact.phoneNumbers!.isEmpty) {
        if (!mounted) return;
        _showContactSnackBar(
          message: "This contact doesn't have a phone number.",
          isError: true,
        );
        return;
      }

      final rawNumbers = contact.phoneNumbers!;
      final sanitizedNumbers = rawNumbers
          .map((e) => e.replaceAll(RegExp(r'[^\d+]'), ''))
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (sanitizedNumbers.isEmpty) {
        if (!mounted) return;
        _showContactSnackBar(
          message: "This contact doesn't have a valid phone number.",
          isError: true,
        );
        return;
      }

      // 5. Populate Field (Single or Multiple selection)
      if (sanitizedNumbers.length == 1) {
        setState(() {
          _phoneCtrl.text = sanitizedNumbers.first;
        });
      } else {
        if (!mounted) return;
        final selectedNumber = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            title: Text('Select Phone Number', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: sanitizedNumbers.map((number) => ListTile(
                leading: Icon(Icons.phone_rounded, color: AppColors.primary),
                title: Text(number, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, number),
              )).toList(),
            ),
          ),
        );
        if (selectedNumber != null) {
          setState(() {
            _phoneCtrl.text = selectedNumber;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error importing contact: $e\n$stackTrace');
      if (!mounted) return;
      _showContactSnackBar(
        message: 'Unable to import contact. Please enter the number manually.',
        isError: true,
      );
    }
  }

  void _showContactSnackBar({
    required String message,
    required bool isError,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        action: actionLabel != null && onActionPressed != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.gold,
                onPressed: onActionPressed,
              )
            : null,
        backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                secondary: AppColors.gold,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _pickFollowUpTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _followUpTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                secondary: AppColors.gold,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _followUpTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final service = context.read<CustomerService>();

    try {
      String? formattedTime;
      if (_followUpTime != null) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, _followUpTime!.hour,
            _followUpTime!.minute);
        formattedTime = DateFormat.jm().format(dt);
      }

      final bool wasCompleted =
          widget.existingCustomer?.followUpCompleted ?? false;

      final customer = Customer(
        id: widget.existingCustomer?.id,
        customerName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        place: _placeCtrl.text.trim(),
        leadGivenBy: _leadByCtrl.text.trim(),
        siteVisited: _siteCtrl.text.trim(),
        date: _selectedDate,
        notes: _notesCtrl.text.trim(),
        bookingStatus: _bookingStatus,
        registrationStatus: _registrationStatus,
        followUpDate: _followUpDate,
        followUpTime: formattedTime,
        followUpNotes: _followUpNotesCtrl.text.trim(),
        followUpCompleted:
            widget.isSchedulingNextFollowUp ? false : wasCompleted,
        followUpCompletedAt: widget.isSchedulingNextFollowUp
            ? null
            : widget.existingCustomer?.followUpCompletedAt,
        followUpHistory: widget.existingCustomer?.followUpHistory ?? [],
        createdAt: widget.existingCustomer?.createdAt,
        updatedAt: widget.existingCustomer?.updatedAt,
      );

      if (_isEditing) {
        await service.updateCustomer(customer);

        if (_followUpDate != null &&
            (widget.isSchedulingNextFollowUp ||
                widget.existingCustomer?.followUpDate == null)) {
          final historyCount =
              widget.existingCustomer?.followUpHistory.length ?? 0;
          final newFollowUp = FollowUp(
            customerId: customer.id!,
            followUpNumber: historyCount + 1,
            followUpDate: _followUpDate!,
            followUpTime: formattedTime,
            notes: _followUpNotesCtrl.text.trim(),
          );
          await service.addFollowUpHistory(customer.id!, newFollowUp);
        }
      } else {
        final newCustomer = await service.addCustomer(customer);
        if (_followUpDate != null && newCustomer?.id != null) {
          final newFollowUp = FollowUp(
            customerId: newCustomer!.id!,
            followUpNumber: 1,
            followUpDate: _followUpDate!,
            followUpTime: formattedTime,
            notes: _followUpNotesCtrl.text.trim(),
          );
          await service.addFollowUpHistory(newCustomer.id!, newFollowUp);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(_isEditing
                    ? 'Customer Updated Successfully'
                    : 'Customer Added Successfully'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(e.toString().contains('PostgrestException') 
                    ? 'Database Error. Please check connection and try again.' 
                    : 'Unable to connect to database.')),
              ],
            ),
            backgroundColor: AppColors.statusRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    Widget formContent(ScrollController? scrollController) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: isDesktop
              ? BorderRadius.circular(AppRadius.lg)
              : const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: Column(
          children: [
            // Drag handle (only on mobile bottom sheet)
            if (!isDesktop) ...[
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ],

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_rounded
                          : Icons.person_add_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Customer' : 'Add Customer',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? 'Update customer information'
                              : 'Add a new customer lead',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            const Divider(),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
                  children: [
                    _sectionLabel('Personal Details'),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      controller: _nameCtrl,
                      label: 'Customer Name',
                      icon: Icons.person_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Customer name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.perm_contact_calendar_rounded, size: 20),
                        color: AppColors.primary,
                        tooltip: 'Pick from Contacts',
                        onPressed: _pickContact,
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Phone number is required';
                        if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(val)) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      controller: _placeCtrl,
                      label: 'Place',
                      icon: Icons.place_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Place is required'
                          : null,
                    ),

                    const SizedBox(height: AppSpacing.md),
                    _sectionLabel('Lead Details'),
                    const SizedBox(height: AppSpacing.sm),

                    _field(
                      controller: _leadByCtrl,
                      label: 'Lead Given By',
                      icon: Icons.person_pin_circle_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Lead source is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      controller: _siteCtrl,
                      label: 'Site Visited',
                      icon: Icons.villa_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Site is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _dateField(),

                    const SizedBox(height: AppSpacing.md),
                    _sectionLabel('Status'),
                    const SizedBox(height: AppSpacing.sm),

                    _dropdownField<BookingStatus>(
                      label: 'Booking Status',
                      icon: Icons.bookmark_rounded,
                      value: _bookingStatus,
                      items: BookingStatus.values,
                      labelBuilder: (v) => v.label,
                      onChanged: (v) => setState(() => _bookingStatus = v!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _dropdownField<RegistrationStatus>(
                      label: 'Registration Status',
                      icon: Icons.verified_rounded,
                      value: _registrationStatus,
                      items: RegistrationStatus.values,
                      labelBuilder: (v) => v.label,
                      onChanged: (v) =>
                          setState(() => _registrationStatus = v!),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    _sectionLabel('Notes'),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      controller: _notesCtrl,
                      label: 'Notes (Optional)',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),

                    const SizedBox(height: AppSpacing.md),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel('Follow-up Details'),
                        if (_followUpDate != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _followUpDate = null;
                                _followUpTime = null;
                                _followUpNotesCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.clear_all_rounded,
                                size: 16),
                            label: Text(
                              'Clear',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.statusRed,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Row(
                      children: [
                        Expanded(child: _followUpDateField()),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _followUpTimeField()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      controller: _followUpNotesCtrl,
                      label: 'Follow-up Notes (Optional)',
                      icon: Icons.note_alt_rounded,
                      maxLines: 2,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: Text('Cancel',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Text(
                                    _isEditing
                                        ? 'Update Customer'
                                        : 'Save Customer',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return Material(
        color: Colors.transparent,
        child: formContent(null),
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scrollController) {
          return formContent(scrollController);
        },
      ),
    )
        .animate()
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn();
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date Visited',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 20),
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(_selectedDate),
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _followUpDateField() {
    return InkWell(
      onTap: _pickFollowUpDate,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date (Optional)',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.event_available_rounded,
                color: AppColors.primary, size: 20),
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Text(
          _followUpDate != null
              ? DateFormat('dd MMM yyyy').format(_followUpDate!)
              : 'Select Date',
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _followUpDate != null
                  ? AppColors.textPrimary
                  : AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _followUpTimeField() {
    return InkWell(
      onTap: _pickFollowUpTime,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Time (Optional)',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.access_time_rounded,
                color: AppColors.primary, size: 20),
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Text(
          _followUpTime != null
              ? _followUpTime!.format(context)
              : 'Select Time',
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _followUpTime != null
                  ? AppColors.textPrimary
                  : AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
      style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(labelBuilder(item),
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
