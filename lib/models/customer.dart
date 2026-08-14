import 'package:intl/intl.dart';

import 'follow_up.dart';

/// Booking status values available for a [Customer].
enum BookingStatus { pending, booked }

/// Registration status values available for a [Customer].
enum RegistrationStatus { pending, completed }

extension BookingStatusX on BookingStatus {
  String get label => this == BookingStatus.pending ? 'Pending' : 'Booked';

  static BookingStatus fromLabel(String value) {
    return value.trim().toLowerCase() == 'booked'
        ? BookingStatus.booked
        : BookingStatus.pending;
  }
}

extension RegistrationStatusX on RegistrationStatus {
  String get label =>
      this == RegistrationStatus.pending ? 'Pending' : 'Completed';

  static RegistrationStatus fromLabel(String value) {
    return value.trim().toLowerCase() == 'completed'
        ? RegistrationStatus.completed
        : RegistrationStatus.pending;
  }
}

/// Core data model representing a single customer/lead record.
///
/// Flutter identifies records by this backend [id] for CRUD, list keys, and Hero tags.
class Customer {
  final String? id;
  final String customerName;
  final String phoneNumber;
  final String place;
  final String leadGivenBy;
  final String siteVisited;
  final DateTime? date;
  final String notes;
  final BookingStatus bookingStatus;
  final RegistrationStatus registrationStatus;
  final DateTime? followUpDate;
  final String? followUpTime;
  final String followUpNotes;
  final bool followUpCompleted;
  final DateTime? followUpCompletedAt;
  final List<FollowUp> followUpHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    this.id,
    required this.customerName,
    required this.phoneNumber,
    required this.place,
    required this.leadGivenBy,
    required this.siteVisited,
    required this.date,
    this.notes = '',
    this.bookingStatus = BookingStatus.pending,
    this.registrationStatus = RegistrationStatus.pending,
    this.followUpDate,
    this.followUpTime,
    this.followUpNotes = '',
    this.followUpCompleted = false,
    this.followUpCompletedAt,
    this.followUpHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  String get formattedDate =>
      date != null ? DateFormat('dd MMM yyyy').format(date!) : '-';

  String get formattedFollowUpDate => followUpDate != null
      ? DateFormat('dd MMM yyyy').format(followUpDate!)
      : '-';

  /// Clean, dialable phone number (digits only, keeps leading + if present).
  String get dialablePhoneNumber {
    final trimmed = phoneNumber.trim();
    final keepPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return keepPlus ? '+$digits' : digits;
  }

  /// Formatted date string for DB requests (yyyy-MM-dd).
  String get dateForDatabase {
    if (date == null) return '';
    return '${date!.year.toString().padLeft(4, '0')}-'
        '${date!.month.toString().padLeft(2, '0')}-'
        '${date!.day.toString().padLeft(2, '0')}';
  }

  Customer copyWith({
    String? id,
    String? customerName,
    String? phoneNumber,
    String? place,
    String? leadGivenBy,
    String? siteVisited,
    DateTime? date,
    String? notes,
    BookingStatus? bookingStatus,
    RegistrationStatus? registrationStatus,
    DateTime? followUpDate,
    String? followUpTime,
    String? followUpNotes,
    bool? followUpCompleted,
    DateTime? followUpCompletedAt,
    List<FollowUp>? followUpHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      place: place ?? this.place,
      leadGivenBy: leadGivenBy ?? this.leadGivenBy,
      siteVisited: siteVisited ?? this.siteVisited,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpTime: followUpTime ?? this.followUpTime,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      followUpCompleted: followUpCompleted ?? this.followUpCompleted,
      followUpCompletedAt: followUpCompletedAt ?? this.followUpCompletedAt,
      followUpHistory: followUpHistory ?? this.followUpHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Supabase JSON mapping ──────────────────────────────────

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'customer_name': customerName,
      'phone_number': phoneNumber,
      'place': place,
      'lead_given_by': leadGivenBy,
      'site_visited': siteVisited,
      'date': date?.toIso8601String(),
      'notes': notes,
      'booking_status': bookingStatus.label,
      'registration_status': registrationStatus.label,
      'follow_up_date': followUpDate?.toIso8601String(),
      'follow_up_time': followUpTime,
      'follow_up_notes': followUpNotes,
      'follow_up_completed': followUpCompleted,
      'follow_up_completed_at': followUpCompletedAt?.toIso8601String(),
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString(),
      customerName: json['customer_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      place: json['place'] as String? ?? '',
      leadGivenBy: json['lead_given_by'] as String? ?? '',
      siteVisited: json['site_visited'] as String? ?? '',
      date: json['date'] != null && json['date'].toString().isNotEmpty
          ? DateTime.tryParse(json['date'].toString())
          : null,
      notes: json['notes'] as String? ?? '',
      bookingStatus: BookingStatusX.fromLabel(
          json['booking_status'] as String? ?? 'Pending'),
      registrationStatus: RegistrationStatusX.fromLabel(
          json['registration_status'] as String? ?? 'Pending'),
      followUpDate: json['follow_up_date'] != null &&
              json['follow_up_date'].toString().isNotEmpty
          ? DateTime.tryParse(json['follow_up_date'].toString())
          : null,
      followUpTime: json['follow_up_time'] as String?,
      followUpNotes: json['follow_up_notes'] as String? ?? '',
      followUpCompleted: json['follow_up_completed'] == true ||
          json['follow_up_completed'] == 'true',
      followUpCompletedAt: json['follow_up_completed_at'] != null &&
              json['follow_up_completed_at'].toString().isNotEmpty
          ? DateTime.tryParse(json['follow_up_completed_at'].toString())
          : null,
      followUpHistory: json['customer_follow_ups'] != null
          ? (json['customer_follow_ups'] as List)
              .map((e) => FollowUp.fromJson(e))
              .toList()
          : [],
      createdAt:
          json['created_at'] != null && json['created_at'].toString().isNotEmpty
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null && json['updated_at'].toString().isNotEmpty
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }

  // ── Equality ──────────────────────────────────────────────────
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id && id != null;
  }

  @override
  int get hashCode => id?.hashCode ?? super.hashCode;
}
