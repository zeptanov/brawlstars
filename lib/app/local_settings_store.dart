import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalPreferencesBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

abstract interface class LocalSecretsBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class CorruptLocalDataException implements Exception {
  const CorruptLocalDataException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class LocalSettingsStore {
  LocalSettingsStore({
    LocalPreferencesBackend? preferences,
    LocalSecretsBackend? secrets,
  }) : _preferences = preferences ?? _SharedPreferencesBackend(),
       _secrets = secrets ?? _SecureStorageBackend();

  static const String _settingsKey = 'maze_royale.settings.v1';
  static const String _statisticsKey = 'maze_royale.statistics.v1';
  static const String _encryptionKey = 'maze_royale.statistics_key.v1';
  static final AesGcm _cipher = AesGcm.with256bits();

  final LocalPreferencesBackend _preferences;
  final LocalSecretsBackend _secrets;

  Future<Map<String, Object?>?> readSettings() async {
    final value = await _preferences.read(_settingsKey);
    if (value == null) return null;
    return _decodeMap(value, 'Настройки');
  }

  Future<void> writeSettings(Map<String, Object?> value) =>
      _preferences.write(_settingsKey, jsonEncode(value));

  Future<Map<String, Object?>?> readStatistics() async {
    final stored = await _preferences.read(_statisticsKey);
    if (stored == null) return null;
    try {
      if (!stored.startsWith('v1:')) {
        throw const FormatException('Unknown encrypted statistics format');
      }
      final envelope = _decodeMap(
        utf8.decode(base64Decode(stored.substring(3))),
        'Зашифрованная статистика',
      );
      final secretBox = SecretBox(
        _decodeBytes(envelope, 'ciphertext'),
        nonce: _decodeBytes(envelope, 'nonce'),
        mac: Mac(_decodeBytes(envelope, 'mac')),
      );
      final clearText = await _cipher.decrypt(
        secretBox,
        secretKey: await _readOrCreateEncryptionKey(create: false),
      );
      return _decodeMap(utf8.decode(clearText), 'Статистика');
    } on CorruptLocalDataException {
      rethrow;
    } on Exception catch (error) {
      throw CorruptLocalDataException(
        'Не удалось расшифровать статистику',
        error,
      );
    }
  }

  Future<void> writeStatistics(Map<String, Object?> value) async {
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: await _readOrCreateEncryptionKey(create: true),
      nonce: _cipher.newNonce(),
    );
    final envelope = <String, Object?>{
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    final stored = 'v1:${base64Encode(utf8.encode(jsonEncode(envelope)))}';
    await _preferences.write(_statisticsKey, stored);
  }

  Future<SecretKey> _readOrCreateEncryptionKey({required bool create}) async {
    final encoded = await _secrets.read(_encryptionKey);
    if (encoded != null) {
      try {
        final bytes = base64Decode(encoded);
        if (bytes.length == 32) return SecretKey(bytes);
      } on FormatException catch (error) {
        throw CorruptLocalDataException(
          'Повреждён ключ локальной статистики',
          error,
        );
      }
      throw const CorruptLocalDataException(
        'Некорректная длина ключа локальной статистики',
      );
    }
    if (!create) {
      throw const CorruptLocalDataException(
        'Ключ локальной статистики не найден',
      );
    }
    final random = math.Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _secrets.write(_encryptionKey, base64Encode(keyBytes));
    return SecretKey(keyBytes);
  }

  static Map<String, Object?> _decodeMap(String value, String label) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded.cast<String, Object?>();
      }
    } on FormatException catch (error) {
      throw CorruptLocalDataException('$label повреждены', error);
    }
    throw CorruptLocalDataException('Некорректный формат: $label');
  }

  static List<int> _decodeBytes(Map<String, Object?> value, String key) {
    final encoded = value[key];
    if (encoded is! String) {
      throw CorruptLocalDataException('Некорректное поле "$key"');
    }
    try {
      return base64Decode(encoded);
    } on FormatException catch (error) {
      throw CorruptLocalDataException('Повреждено поле "$key"', error);
    }
  }
}

class _SharedPreferencesBackend implements LocalPreferencesBackend {
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _instance.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _instance.setString(key, value);
}

class _SecureStorageBackend implements LocalSecretsBackend {
  const _SecureStorageBackend();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
