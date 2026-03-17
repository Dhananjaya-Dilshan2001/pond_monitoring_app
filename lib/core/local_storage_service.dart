import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const IOSOptions _iosOptions = IOSOptions();
  static const MacOsOptions _macOsOptions = MacOsOptions();

  Future<void> saveUserCredential({
    required String username,
    required String password,
  }) async {
    await _storage.write(
      key: _usernameKey,
      value: username,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );

    await _storage.write(
      key: _passwordKey,
      value: password,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );
  }

  Future<Map<String, String>?> getUserCredential() async {
    final username = await _storage.read(
      key: _usernameKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );

    final password = await _storage.read(
      key: _passwordKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );

    if (username == null || password == null) {
      return null;
    }

    return {
      'username': username,
      'password': password,
    };
  }

  Future<void> clearUserCredential() async {
    await _storage.delete(
      key: _usernameKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );

    await _storage.delete(
      key: _passwordKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );
  }

  Future<void> clearStorage() async {
    await _storage.deleteAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
    );
  }
}
