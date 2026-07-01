import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère le mode clair/sombre et le persiste entre les sessions.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    switch (p.getString(_key)) {
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      case 'light':
        _mode = ThemeMode.light;
        break;
      default:
        _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      m == ThemeMode.dark
          ? 'dark'
          : m == ThemeMode.light
              ? 'light'
              : 'system',
    );
  }

  Future<void> toggleDark(bool on) =>
      setMode(on ? ThemeMode.dark : ThemeMode.light);
}
