import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user_profile.dart';

/// Thin, testable wrapper around local persistence.
class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;
  String? _volatileToken;

  static const _kSession = 'carman.session.user';
  static const _kToken = 'carman.session.token';
  static const _kRemember = 'carman.session.remember';
  static const _kFavorites = 'carman.favorites';
  static const _kOnboarded = 'carman.onboarded';
  static const _kCity = 'carman.city';
  static const _kNotifications = 'carman.notifications.read';
  static const _kDemoAccounts = 'carman.demo.accounts';

  UserProfile? loadUser() {
    final raw = _prefs.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserProfile user) async {
    await _prefs.setString(_kSession, jsonEncode(user.toJson()));
  }

  String? loadToken() => _volatileToken ?? _prefs.getString(_kToken);

  Future<void> saveToken(String? token, {bool persistent = true}) async {
    _volatileToken = token;
    if (token == null || token.isEmpty) {
      await _prefs.remove(_kToken);
    } else if (!persistent) {
      await _prefs.remove(_kToken);
    } else {
      await _prefs.setString(_kToken, token);
    }
  }

  bool get rememberSession => _prefs.getBool(_kRemember) ?? true;

  Future<void> setRememberSession(bool value) async {
    await _prefs.setBool(_kRemember, value);
  }

  Future<void> clearSession() async {
    _volatileToken = null;
    await _prefs.remove(_kSession);
    await _prefs.remove(_kToken);
  }

  Set<String> loadFavorites({String? accountId}) =>
      (_prefs.getStringList(accountId == null ? _kFavorites : '$_kFavorites.$accountId') ??
          const <String>[]).toSet();

  Future<void> saveFavorites(Set<String> ids, {String? accountId}) async {
    await _prefs.setStringList(
      accountId == null ? _kFavorites : '$_kFavorites.$accountId', ids.toList(),
    );
  }

  bool get hasOnboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> markOnboarded() async {
    await _prefs.setBool(_kOnboarded, true);
  }

  String? get city => _prefs.getString(_kCity);

  Future<void> saveCity(String city) async {
    await _prefs.setString(_kCity, city);
  }

  Set<String> loadReadNotifications({String? accountId}) =>
      (_prefs.getStringList(accountId == null ? _kNotifications : '$_kNotifications.$accountId') ??
          const <String>[]).toSet();

  Future<void> saveReadNotifications(Set<String> ids, {String? accountId}) async {
    await _prefs.setStringList(
      accountId == null ? _kNotifications : '$_kNotifications.$accountId',
      ids.toList(),
    );
  }

  /// Demo accounts let a registered user log in again after signing out.
  Future<void> saveDemoAccount({
    required String email,
    required String password,
    required UserProfile profile,
  }) async {
    final accounts = _loadDemoAccounts();
    accounts[email.toLowerCase()] = {
      'password': password,
      'profile': profile.toJson(),
    };
    await _prefs.setString(_kDemoAccounts, jsonEncode(accounts));
  }

  Map<String, dynamic>? findDemoAccount(String email) {
    final accounts = _loadDemoAccounts();
    final account = accounts[email.toLowerCase()];
    if (account is Map<String, dynamic>) return account;
    return null;
  }

  Map<String, dynamic> _loadDemoAccounts() {
    final raw = _prefs.getString(_kDemoAccounts);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
