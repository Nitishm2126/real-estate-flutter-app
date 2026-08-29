import 'package:intl/intl.dart';

/// Availability status for a property/project.
enum PropertyAvailability { available, limitedAvailability, soldOut }

extension PropertyAvailabilityX on PropertyAvailability {
  String get label {
    switch (this) {
      case PropertyAvailability.available:
        return 'Available';
      case PropertyAvailability.limitedAvailability:
        return 'Limited Availability';
      case PropertyAvailability.soldOut:
        return 'Sold Out';
    }
  }

  static PropertyAvailability fromLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'limited availability':
        return PropertyAvailability.limitedAvailability;
      case 'sold out':
        return PropertyAvailability.soldOut;
      default:
        return PropertyAvailability.available;
    }
  }
}

/// Core data model representing a single property/project record.
class Property {
  final String? id;
  final String projectName;
  final String location;
  final String description;
  final double? pricePerSqft;
  final double? offerPricePerSqft;

  /// List of plot/unit sizes as strings (e.g., "549", "820").
  final List<String> plotSizes;
  final PropertyAvailability availability;

  /// List of Supabase Storage paths (not full URLs) for images.
  final List<String> imagePaths;
  final List<String> amenities;
  final String approvalType;
  final String approvalNumber;
  final String approvalAuthority;
  final String approvalNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Property({
    this.id,
    required this.projectName,
    required this.location,
    this.description = '',
    this.pricePerSqft,
    this.offerPricePerSqft,
    this.plotSizes = const [],
    this.availability = PropertyAvailability.available,
    this.imagePaths = const [],
    this.amenities = const [],
    this.approvalType = '',
    this.approvalNumber = '',
    this.approvalAuthority = '',
    this.approvalNotes = '',
    this.createdAt,
    this.updatedAt,
  });

  String get formattedCreatedAt => createdAt != null
      ? DateFormat('dd MMM yyyy').format(createdAt!)
      : '-';

  String get formattedPrice =>
      pricePerSqft != null ? '₹${_fmt(pricePerSqft!)}' : '-';

  String get formattedOfferPrice =>
      offerPricePerSqft != null ? '₹${_fmt(offerPricePerSqft!)}' : '-';

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  Property copyWith({
    String? id,
    String? projectName,
    String? location,
    String? description,
    double? pricePerSqft,
    double? offerPricePerSqft,
    List<String>? plotSizes,
    PropertyAvailability? availability,
    List<String>? imagePaths,
    List<String>? amenities,
    String? approvalType,
    String? approvalNumber,
    String? approvalAuthority,
    String? approvalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      location: location ?? this.location,
      description: description ?? this.description,
      pricePerSqft: pricePerSqft ?? this.pricePerSqft,
      offerPricePerSqft: offerPricePerSqft ?? this.offerPricePerSqft,
      plotSizes: plotSizes ?? this.plotSizes,
      availability: availability ?? this.availability,
      imagePaths: imagePaths ?? this.imagePaths,
      amenities: amenities ?? this.amenities,
      approvalType: approvalType ?? this.approvalType,
      approvalNumber: approvalNumber ?? this.approvalNumber,
      approvalAuthority: approvalAuthority ?? this.approvalAuthority,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Supabase JSON mapping ─────────────────────────────────────

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'project_name': projectName,
      'location': location,
      'image_paths': imagePaths,
    };

    if (description.trim().isNotEmpty) {
      map['description'] = description.trim();
    }
    if (pricePerSqft != null) {
      map['price_per_sqft'] = pricePerSqft;
    }
    if (offerPricePerSqft != null) {
      map['offer_price_per_sqft'] = offerPricePerSqft;
    }
    if (plotSizes.isNotEmpty) {
      map['plot_sizes'] = plotSizes;
    }
    if (availability != PropertyAvailability.available && availability.label.isNotEmpty) {
      map['availability'] = availability.label;
    }
    if (amenities.isNotEmpty) {
      map['amenities'] = amenities;
    }
    if (approvalType.trim().isNotEmpty) {
      map['approval_type'] = approvalType.trim();
    }
    if (approvalNumber.trim().isNotEmpty) {
      map['approval_number'] = approvalNumber.trim();
    }
    if (approvalAuthority.trim().isNotEmpty) {
      map['approval_authority'] = approvalAuthority.trim();
    }
    if (approvalNotes.trim().isNotEmpty) {
      map['approval_notes'] = approvalNotes.trim();
    }

    return map;
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        final trimmed = val.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          final content = trimmed.substring(1, trimmed.length - 1).trim();
          if (content.isEmpty) return [];
          return content.split(',').map((e) => e.replaceAll('"', '').trim()).toList();
        }
      }
      return [];
    }

    return Property(
      id: json['id']?.toString(),
      projectName: json['project_name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricePerSqft: (json['price_per_sqft'] as num?)?.toDouble(),
      offerPricePerSqft: (json['offer_price_per_sqft'] as num?)?.toDouble(),
      plotSizes: parseStringList(json['plot_sizes']),
      availability: PropertyAvailabilityX.fromLabel(
          json['availability'] as String? ?? 'Available'),
      imagePaths: parseStringList(json['image_paths']),
      amenities: parseStringList(json['amenities']),
      approvalType: json['approval_type'] as String? ?? '',
      approvalNumber: json['approval_number'] as String? ?? '',
      approvalAuthority: json['approval_authority'] as String? ?? '',
      approvalNotes: (json['approval_notes'] as String?) ??
          (json['approval_details'] as String?) ??
          '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Property && other.id == id && id != null;
  }

  @override
  int get hashCode => id?.hashCode ?? super.hashCode;
}
