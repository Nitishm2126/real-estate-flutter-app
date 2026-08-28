import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';

/// Service to manage application theme mode (Light/Dark) and persist choices.
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _glassEnabledKey = 'glass_enabled';
  static const String _glassBlurKey = 'glass_blur';
  static const String _glassOpacityKey = 'glass_opacity';
  static const String _glassBorderKey = 'glass_border';
  static const String _glassShadowKey = 'glass_shadow';
  static const String _glassPresetKey = 'glass_preset';

  bool _isDarkMode = false;
  bool _glassEnabled = true;
  double _glassBlur = 24.0;
  double _glassOpacity = 0.55;
  double _glassBorder = 0.15;
  double _glassShadow = 8.0;
  String _glassPreset = 'Balanced';

  bool get isDarkMode => _isDarkMode;
  bool get glassEnabled => _glassEnabled;
  double get glassBlur => _glassBlur;
  double get glassOpacity => _glassOpacity;
  double get glassBorder => _glassBorder;
  double get glassShadow => _glassShadow;
  String get glassPreset => _glassPreset;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      _glassEnabled = prefs.getBool(_glassEnabledKey) ?? true;
      _glassBlur = prefs.getDouble(_glassBlurKey) ?? 24.0;
      _glassOpacity = prefs.getDouble(_glassOpacityKey) ?? 0.55;
      _glassBorder = prefs.getDouble(_glassBorderKey) ?? 0.15;
      _glassShadow = prefs.getDouble(_glassShadowKey) ?? 8.0;
      _glassPreset = prefs.getString(_glassPresetKey) ?? 'Balanced';
      
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

  Future<void> setGlassEnabled(bool value) async {
    _glassEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassEnabledKey, value);
  }

  Future<void> setGlassBlur(double value) async {
    _glassBlur = value;
    _glassPreset = 'Custom';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_glassBlurKey, value);
    await prefs.setString(_glassPresetKey, 'Custom');
  }

  Future<void> setGlassOpacity(double value) async {
    _glassOpacity = value;
    _glassPreset = 'Custom';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_glassOpacityKey, value);
    await prefs.setString(_glassPresetKey, 'Custom');
  }

  Future<void> setGlassBorder(double value) async {
    _glassBorder = value;
    _glassPreset = 'Custom';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_glassBorderKey, value);
    await prefs.setString(_glassPresetKey, 'Custom');
  }

  Future<void> setGlassShadow(double value) async {
    _glassShadow = value;
    _glassPreset = 'Custom';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_glassShadowKey, value);
    await prefs.setString(_glassPresetKey, 'Custom');
  }

  Future<void> setGlassPreset(String preset) async {
    _glassPreset = preset;
    if (preset == 'Subtle') {
      _glassBlur = 10.0;
      _glassOpacity = 0.85;
      _glassBorder = 0.05;
      _glassShadow = 4.0;
    } else if (preset == 'Balanced') {
      _glassBlur = 24.0;
      _glassOpacity = 0.55;
      _glassBorder = 0.15;
      _glassShadow = 8.0;
    } else if (preset == 'Strong') {
      _glassBlur = 40.0;
      _glassOpacity = 0.30;
      _glassBorder = 0.30;
      _glassShadow = 16.0;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_glassPresetKey, preset);
    if (preset != 'Custom') {
      await prefs.setDouble(_glassBlurKey, _glassBlur);
      await prefs.setDouble(_glassOpacityKey, _glassOpacity);
      await prefs.setDouble(_glassBorderKey, _glassBorder);
      await prefs.setDouble(_glassShadowKey, _glassShadow);
    }
  }
}
