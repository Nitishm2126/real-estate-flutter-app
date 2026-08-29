import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FcmTokenService {
  static final FcmTokenService _instance = FcmTokenService._internal();
  factory FcmTokenService() => _instance;
  FcmTokenService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _deviceId;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return; // FCM logic mostly targets Android for now

    try {
      _deviceId = await _getOrCreateDeviceId();
      
      // Request permission (mostly for iOS, but good practice. Android 13+ is handled in NotificationService)
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[FCM] Permission not granted: ${settings.authorizationStatus}');
        return;
      }

      // Get initial token
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveTokenToSupabase(token);
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _saveTokenToSupabase(newToken);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  Future<void> _saveTokenToSupabase(String token) async {
    if (_deviceId == null) return;

    try {
      debugPrint('[FCM] Saving token to Supabase for device: $_deviceId');
      
      // Use upsert to insert or update based on device_id
      // For this to work smoothly without specifying the id (if not known),
      // Supabase supports upsert based on a unique column if onConflict is provided.
      await _supabase.from('fcm_tokens').upsert({
        'device_id': _deviceId,
        'token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id');
      
      debugPrint('[FCM] Token saved successfully.');
    } catch (e) {
      debugPrint('[FCM] Failed to save token to Supabase: $e');
    }
  }
}
