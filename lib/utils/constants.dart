/// App-wide constant values for MCP Avadi CRM.
class AppConstants {
  AppConstants._();

  static const String appName = 'MCP Avadi';
  static const String companyFullName = 'Madras City Properties';
  static const String branch = 'Avadi Branch';

  static const String gmName = 'T. Meenakshi Sundaram';
  static const String gmTitle = 'GM Sales – Avadi Branch';

  static const String logoAsset = 'assets/logo.png';
  static const String photoAsset = 'assets/photo.png';

  // Dropdown option sets
  static const List<String> bookingStatusOptions = ['Pending', 'Booked'];
  static const List<String> registrationStatusOptions = [
    'Pending',
    'Completed'
  ];

  // Supabase Configuration
  static const String supabaseUrl = 'https://pwiedgucmiuvcejhlpuu.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_ZS2zU00RQDQwD14xGLmpVQ_AfJpoJnN';
}
