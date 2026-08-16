import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';

/// Service to manage application theme mode (Light/Dark) and persist choices.
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      AppColors.isDarkMode = _isDarkMode;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    AppColors.isDarkMode = _isDarkMode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, value);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
}
