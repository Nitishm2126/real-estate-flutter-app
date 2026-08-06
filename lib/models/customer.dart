import 'package:intl/intl.dart';

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
/// The Google Sheet has NO ID column. The [id] field is a LOCAL-ONLY
/// deterministic identifier generated from the customer's data fields.
/// Same data → same ID, so the ID is stable across syncs.
///
/// GAS identifies rows by field matching (name + phone + place + lead + date).
/// Flutter identifies records by this local [id] for list keys and Hero tags.
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
  });

  String get formattedDate =>
      date != null ? DateFormat('dd MMM yyyy').format(date!) : '-';

  /// Clean, dialable phone number (digits only, keeps leading + if present).
  String get dialablePhoneNumber {
    final trimmed = phoneNumber.trim();
    final keepPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return keepPlus ? '+$digits' : digits;
  }

  /// Formatted date string for API requests (yyyy-MM-dd).
  String get dateForApi {
    if (date == null) return '';
    return '${date!.year.toString().padLeft(4, '0')}-'
        '${date!.month.toString().padLeft(2, '0')}-'
        '${date!.day.toString().padLeft(2, '0')}';
  }

  /// Generate a deterministic local ID from the customer's identifying fields.
  /// Same data = same ID, so the ID is stable across syncs.
  /// This is the ONLY stable identifier since GAS has no ID column.
  static String generateLocalId(
    String name,
    String phone,
    String place,
    String lead,
    String dateStr,
  ) {
    final key = '${name.trim().toLowerCase()}|'
        '${phone.trim().toLowerCase()}|'
        '${place.trim().toLowerCase()}|'
        '${lead.trim().toLowerCase()}|'
        '${dateStr.trim().toLowerCase()}';
    return 'local_${key.hashCode.toUnsigned(32)}';
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
    );
  }

  // ── Local JSON serialization ──────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id ?? '',
        'customerName': customerName,
        'phoneNumber': phoneNumber,
        'place': place,
        'leadGivenBy': leadGivenBy,
        'siteVisited': siteVisited,
        'date': date?.toIso8601String() ?? '',
        'notes': notes,
        'bookingStatus': bookingStatus.label,
        'registrationStatus': registrationStatus.label,
      };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String?,
      customerName: json['customerName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      place: json['place'] as String? ?? '',
      leadGivenBy: json['leadGivenBy'] as String? ?? '',
      siteVisited: json['siteVisited'] as String? ?? '',
      date: json['date'] != null && json['date'].toString().isNotEmpty
          ? DateTime.tryParse(json['date'].toString())
          : null,
      notes: json['notes'] as String? ?? '',
      bookingStatus: BookingStatusX.fromLabel(
          json['bookingStatus'] as String? ?? 'Pending'),
      registrationStatus: RegistrationStatusX.fromLabel(
          json['registrationStatus'] as String? ?? 'Pending'),
    );
  }

  // ── Google Sheet JSON mapping ─────────────────────────────────
  //
  // Sheet columns (A–I, NO ID column):
  // A: Customer Name | B: Phone Number | C: Place | D: Lead Given by |
  // E: Site Visited  | F: Date         | G: Notes | H: Booking Status |
  // I: Registration Status

  /// JSON for sending to Google Apps Script (create / update).
  Map<String, dynamic> toSheetJson() {
    return {
      'Customer Name': customerName,
      'Phone Number': phoneNumber,
      'Place': place,
      'Lead Given by': leadGivenBy,
      'Site Visited': siteVisited,
      'Date': dateForApi,
      'Notes': notes,
      'Booking Status': bookingStatus.label,
      'Registration Status': registrationStatus.label,
    };
  }

  /// Parse a customer from the Google Sheet JSON response.
  /// Handles trailing spaces in column headers (e.g. "Phone Number ").
  factory Customer.fromSheetJson(Map<String, dynamic> rawJson) {
    // Trim all keys to handle trailing spaces in sheet headers
    final json = <String, dynamic>{};
    rawJson.forEach((key, value) {
      json[key.trim()] = value;
    });

    // Parse date
    DateTime? parsedDate;
    final dateString = json['Date']?.toString().trim() ?? '';
    if (dateString.isNotEmpty) {
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parse(dateString);
      } catch (_) {
        parsedDate = DateTime.tryParse(dateString);
      }
    }

    final name = json['Customer Name']?.toString().trim() ?? '';
    final phone = json['Phone Number']?.toString().trim() ?? '';
    final place = json['Place']?.toString().trim() ?? '';
    final lead = json['Lead Given by']?.toString().trim() ?? '';
    final dateStr = parsedDate != null
        ? '${parsedDate.year}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}'
        : '';

    // Generate a deterministic local ID from the fields
    final localId = generateLocalId(name, phone, place, lead, dateStr);

    return Customer(
      id: localId,
      customerName: name,
      phoneNumber: phone,
      place: place,
      leadGivenBy: lead,
      siteVisited: json['Site Visited']?.toString().trim() ?? '',
      date: parsedDate,
      notes: json['Notes']?.toString().trim() ?? '',
      bookingStatus:
          BookingStatusX.fromLabel(json['Booking Status']?.toString() ?? ''),
      registrationStatus: RegistrationStatusX.fromLabel(
          json['Registration Status']?.toString() ?? ''),
    );
  }
}
