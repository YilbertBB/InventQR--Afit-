import 'package:shared_preferences/shared_preferences.dart';

class FirstTimeService {
  static const String _firstTimeKey = 'is_first_time';
  static const String _firstInstallKey = 'is_first_install';

  // Verificar si es la primera vez
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  // Marcar que ya no es la primera vez
  static Future<void> markAsNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeKey, false);
  }

  // Verificar si es primera instalación
  static Future<bool> isFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstInstallKey) ?? true;
  }

  // Marcar que ya no es primera instalación
  static Future<void> markAsNotFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstInstallKey, false);
  }

  // Resetear para pruebas (solo desarrollo)
  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstTimeKey);
    await prefs.remove(_firstInstallKey);
  }
}
