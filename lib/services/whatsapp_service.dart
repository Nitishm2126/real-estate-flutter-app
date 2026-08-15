import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum WhatsAppApp {
  normal,
  business,
  both,
  none,
}

class WhatsAppService {
  static const MethodChannel _appCheckChannel =
      MethodChannel('com.mcp_avadi/app_check');

  /// Normalizes an Indian phone number
  static String normalizeNumber(String phone) {
    String number = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.length == 10) {
      number = '91$number';
    }
    return number;
  }

  /// Gets the standard pre-filled message
  static String getPrefilledMessage(String customerName) {
    return 'Hello $customerName,\n'
        'Thank you for your interest in MCP Avadi.\n'
        'We are happy to assist you regarding your property enquiry.\n\n'
        'Regards,\n'
        'T. Meenakshi Sundaram\n'
        'GM Sales - MCP Avadi';
  }

  /// Checks which WhatsApp applications are installed natively on Android.
  /// On Web, it returns `WhatsAppApp.normal` (as fallback to web).
  static Future<WhatsAppApp> checkAvailableApps() async {
    if (kIsWeb) {
      return WhatsAppApp.normal;
    }

    try {
      final bool hasNormal = await _appCheckChannel.invokeMethod<bool>(
            'isAppInstalled',
            {'packageName': 'com.whatsapp'},
          ) ??
          false;

      final bool hasBusiness = await _appCheckChannel.invokeMethod<bool>(
            'isAppInstalled',
            {'packageName': 'com.whatsapp.w4b'},
          ) ??
          false;

      if (hasNormal && hasBusiness) {
        return WhatsAppApp.both;
      } else if (hasNormal) {
        return WhatsAppApp.normal;
      } else if (hasBusiness) {
        return WhatsAppApp.business;
      }
    } catch (e) {
      // Fallback in case method channel fails
      debugPrint('Error checking apps: $e');
    }

    return WhatsAppApp.none;
  }

  /// Launches the specified WhatsApp application with the pre-filled data.
  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
    required WhatsAppApp app,
  }) async {
    final String normalizedPhone = normalizeNumber(phone);
    if (normalizedPhone.isEmpty) return false;

    final String encodedMessage = Uri.encodeComponent(message);

    if (kIsWeb) {
      final Uri webUri =
          Uri.parse('https://wa.me/$normalizedPhone?text=$encodedMessage');
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    Uri? uri;
    if (app == WhatsAppApp.business) {
      uri = Uri.parse(
          'intent://send?phone=$normalizedPhone&text=$encodedMessage#Intent;package=com.whatsapp.w4b;scheme=whatsapp;end');
    } else if (app == WhatsAppApp.normal) {
      uri = Uri.parse(
          'intent://send?phone=$normalizedPhone&text=$encodedMessage#Intent;package=com.whatsapp;scheme=whatsapp;end');
    }

    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } catch (_) {}
    }

    // Ultimate fallback to generic web intent if explicit intents fail
    final Uri fallbackUri =
        Uri.parse('https://wa.me/$normalizedPhone?text=$encodedMessage');
    try {
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
