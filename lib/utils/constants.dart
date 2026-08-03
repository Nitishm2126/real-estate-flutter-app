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
  static const List<String> registrationStatusOptions = ['Pending', 'Completed'];

  // Live Apps Script endpoint backing this CRM's Google Sheet.
  static const String appsScriptApiUrl = 'https://script.google.com/macros/s/AKfycby5IZR7qP9uXhO8M47AWOGH6Wez9gV1gY32SDHWsUsTr4mgcQGXaqAgP6v0B_VMgpDA7Q/exec';

  // Auto-sync interval: 5 seconds as required.
  static const Duration apiSyncInterval = Duration(seconds: 5);
}
