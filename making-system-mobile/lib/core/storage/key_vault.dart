import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyVault {
  static const _rsaPrivate = 'identity.rsa.private';
  static const _rsaPublic = 'identity.rsa.public';
  static const _edPrivate = 'identity.ed25519.private';
  static const _edPublic = 'identity.ed25519.public';
  static const _dbKey = 'local.db.key';

  final FlutterSecureStorage _storage;

  const KeyVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String> getOrCreateDbKey() async {
    final existing = await read(_dbKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    final value = base64UrlEncode(bytes);
    await write(_dbKey, value);
    return value;
  }

  Future<void> saveIdentity({
    required Map<String, dynamic> rsaPrivate,
    required Map<String, dynamic> rsaPublic,
    required List<int> edPrivate,
    required List<int> edPublic,
  }) async {
    await write(_rsaPrivate, jsonEncode(rsaPrivate));
    await write(_rsaPublic, jsonEncode(rsaPublic));
    await write(_edPrivate, base64UrlEncode(edPrivate));
    await write(_edPublic, base64UrlEncode(edPublic));
  }

  Future<Map<String, dynamic>?> rsaPrivate() async {
    final value = await read(_rsaPrivate);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> rsaPublic() async {
    final value = await read(_rsaPublic);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<List<int>?> edPrivate() async {
    final value = await read(_edPrivate);
    return value == null ? null : base64Url.decode(value);
  }

  Future<List<int>?> edPublic() async {
    final value = await read(_edPublic);
    return value == null ? null : base64Url.decode(value);
  }
}
