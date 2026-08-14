import 'package:intl/intl.dart';

class FollowUp {
  final String? id;
  final String customerId;
  final int followUpNumber;
  final DateTime followUpDate;
  final String? followUpTime;
  final String notes;
  final String status;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FollowUp({
    this.id,
    required this.customerId,
    required this.followUpNumber,
    required this.followUpDate,
    this.followUpTime,
    this.notes = '',
    this.status = 'Pending',
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isCompleted =>
      status.toLowerCase() == 'completed' || completedAt != null;

  String get formattedDate => DateFormat('dd MMM yyyy').format(followUpDate);

  FollowUp copyWith({
    String? id,
    String? customerId,
    int? followUpNumber,
    DateTime? followUpDate,
    String? followUpTime,
    String? notes,
    String? status,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowUp(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      followUpNumber: followUpNumber ?? this.followUpNumber,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpTime: followUpTime ?? this.followUpTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'customer_id': customerId,
      'follow_up_number': followUpNumber,
      'follow_up_date': followUpDate.toIso8601String(),
      'follow_up_time': followUpTime,
      'notes': notes,
      'status': status,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      id: json['id']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      followUpNumber: json['follow_up_number'] as int? ?? 1,
      followUpDate: json['follow_up_date'] != null
          ? DateTime.tryParse(json['follow_up_date'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      followUpTime: json['follow_up_time'] as String?,
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
