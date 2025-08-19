import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefUtil {
  static const String _lastRoleKey = 'lastRole';

  static Future<void> setLastRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRoleKey, role);
  }

  static Future<String?> getLastRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastRoleKey);
  }

  static Future<void> clearLastRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRoleKey);
  }
}
