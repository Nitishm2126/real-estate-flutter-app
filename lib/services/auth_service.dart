import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Authentication and profile service.
///
/// Wraps [supabase.auth] and exposes:
///  - [currentUser] — the signed-in Supabase [User] (null when logged out)
///  - [profile]     — the matching [UserProfile] row from `public.profiles`
///  - [isGM] / [isBDM] — role shortcuts
///
/// Listens to auth-state changes so consumers receive automatic rebuilds
/// through [ChangeNotifier].
class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  UserProfile? _profile;
  bool _isLoadingProfile = false;
  String? _authError;

  StreamSubscription<AuthState>? _authSub;

  User? get currentUser => _user;
  UserProfile? get profile => _profile;
  bool get isLoadingProfile => _isLoadingProfile;
  String? get authError => _authError;

  bool get isSignedIn => _user != null;
  bool get isGM => _profile?.isGM ?? false;
  bool get isBDM => _profile?.isBDM ?? false;
  String get displayName => _profile?.fullName ?? _user?.email ?? '';
  String get displayRole => _profile?.roleLabel ?? '';
  String get displayBranch => _profile?.branch ?? 'Avadi Branch';
  String get roleAbbr => _profile?.roleAbbr ?? '';

  AuthService() {
    _init();
  }

  /// Starts listening to Supabase auth state changes.
  void _init() {
    // Hydrate from any existing session immediately
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _fetchProfile(_user!.id);
    }

    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('[AUTH] Event: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          _user = session?.user;
          if (_user != null) _fetchProfile(_user!.id);
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
          _user = null;
          _profile = null;
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  /// Loads the [UserProfile] row for the given [userId] from `public.profiles`.
  Future<void> _fetchProfile(String userId) async {
    _isLoadingProfile = true;
    _authError = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      _profile = UserProfile.fromJson(response as Map<String, dynamic>);
      debugPrint('[AUTH] Profile loaded: ${_profile?.fullName} (${_profile?.role})');
    } catch (e) {
      debugPrint('[AUTH] Failed to load profile: $e');
      _authError = 'Could not load user profile.';
      _profile = null;
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  // ── Public Actions ────────────────────────────────────────────────────────

  /// Signs in with email and password.
  ///
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    _authError = null;
    try {
      await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null; // success
    } on AuthException catch (e) {
      _authError = e.message;
      debugPrint('[AUTH] signIn error: ${e.message}');
      notifyListeners();
      return e.message;
    } catch (e) {
      _authError = 'Unexpected error. Please try again.';
      debugPrint('[AUTH] signIn unexpected: $e');
      notifyListeners();
      return _authError;
    }
  }

  /// Signs out the current user and clears profile state.
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[AUTH] signOut error: $e');
    }
    _user = null;
    _profile = null;
    _authError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
