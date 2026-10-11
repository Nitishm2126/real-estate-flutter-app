/// Data model for a row in the `public.profiles` Supabase table.
///
/// Linked 1:1 to `auth.users` via [id].
class UserProfile {
  final String id;
  final String fullName;
  final String role; // 'gm' or 'bdm'
  final String branch;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.branch,
    this.createdAt,
  });

  /// Deserialises a row returned by Supabase.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'bdm',
      branch: json['branch'] as String? ?? 'Avadi Branch',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Friendly role label for display.
  String get roleLabel {
    switch (role) {
      case 'gm':
        return 'General Manager, Sales';
      case 'bdm':
        return 'Business Development Manager';
      default:
        return role.toUpperCase();
    }
  }

  /// Short role abbreviation for compact UI elements.
  String get roleAbbr {
    switch (role) {
      case 'gm':
        return 'GM';
      case 'bdm':
        return 'BDM';
      default:
        return role.toUpperCase();
    }
  }

  bool get isGM => role == 'gm';
  bool get isBDM => role == 'bdm';
}
