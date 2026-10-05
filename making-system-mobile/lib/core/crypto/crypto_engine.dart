import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';

import '../storage/key_vault.dart';

class Identity {
  final RSAPrivateKey rsaPrivate;
  final RSAPublicKey rsaPublic;
  final SimpleKeyPair edPrivate;
  final SimplePublicKey edPublic;

  const Identity({
    required this.rsaPrivate,
    required this.rsaPublic,
    required this.edPrivate,
    required this.edPublic,
  });

  Map<String, dynamic> publicBundle() => {
        'rsa': {
          'n': _bigIntToB64(rsaPublic.modulus),
          'e': _bigIntToB64(rsaPublic.exponent),
          'alg': 'RSA-OAEP-256',
        },
        'ed25519': {
          'publicKey': base64UrlEncode(edPublic.bytes),
          'alg': 'Ed25519',
        },
      };
}

class EncryptedEnvelope {
  final String version;
  final String key;
  final String nonce;
  final String ciphertext;
  final String mac;
  final String senderEd25519;
  final String signature;

  const EncryptedEnvelope({
    required this.version,
    required this.key,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.senderEd25519,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'alg': 'RSA-OAEP-256/AES-256-GCM/Ed25519',
        'key': key,
        'nonce': nonce,
        'ciphertext': ciphertext,
        'mac': mac,
        'senderEd25519': senderEd25519,
        'signature': signature,
      };

  String encode() => jsonEncode(toJson());
}

class CryptoEngine {
  final KeyVault vault;
  final _ed25519 = Ed25519();
  final _aes = AesGcm.with256bits();

  Identity? _identity;

  CryptoEngine(this.vault);

  Future<Identity> ensureIdentity() async {
    if (_identity != null) return _identity!;

    final rsaPrivateJson = await vault.rsaPrivate();
    final rsaPublicJson = await vault.rsaPublic();
    final edPrivateBytes = await vault.edPrivate();
    final edPublicBytes = await vault.edPublic();

    if (rsaPrivateJson != null &&
        rsaPublicJson != null &&
        edPrivateBytes != null &&
        edPublicBytes != null) {
      final rsaPrivate = _rsaPrivateFromJson(rsaPrivateJson);
      final rsaPublic = _rsaPublicFromJson(rsaPublicJson);
      final edPublic = SimplePublicKey(edPublicBytes, type: KeyPairType.ed25519);
      final edPrivate = SimpleKeyPairData(
        edPrivateBytes,
        publicKey: edPublic,
        type: KeyPairType.ed25519,
      );
      _identity = Identity(
        rsaPrivate: rsaPrivate,
        rsaPublic: rsaPublic,
        edPrivate: edPrivate,
        edPublic: edPublic,
      );
      return _identity!;
    }

    final rsaPair = _generateRsaKeyPair();
    final edPair = await _ed25519.newKeyPair();
    final edPrivate = await edPair.extractPrivateKeyBytes();
    final edPublic = await edPair.extractPublicKey();

    final identity = Identity(
      rsaPrivate: rsaPair.privateKey as RSAPrivateKey,
      rsaPublic: rsaPair.publicKey as RSAPublicKey,
      edPrivate: SimpleKeyPairData(
        edPrivate,
        publicKey: edPublic,
        type: KeyPairType.ed25519,
      ),
      edPublic: edPublic,
    );

    await vault.saveIdentity(
      rsaPrivate: _rsaPrivateToJson(identity.rsaPrivate),
      rsaPublic: _rsaPublicToJson(identity.rsaPublic),
      edPrivate: edPrivate,
      edPublic: edPublic.bytes,
    );

    _identity = identity;
    return identity;
  }

  Future<String> encryptDirectMessage({
    required String plaintext,
    required Map<String, dynamic> receiverRsaPublic,
    required String receiverEd25519Public,
  }) async {
    final identity = await ensureIdentity();
    final receiverKey = _rsaPublicFromJson(receiverRsaPublic);

    final contentKey = await _aes.newSecretKey();
    final contentKeyBytes = await contentKey.extractBytes();
    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: contentKey,
    );

    final rsa = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(receiverKey));
    final wrappedKey = rsa.process(Uint8List.fromList(contentKeyBytes));

    final unsigned = [
      base64UrlEncode(wrappedKey),
      base64UrlEncode(secretBox.nonce),
      base64UrlEncode(secretBox.cipherText),
      base64UrlEncode(secretBox.mac.bytes),
      receiverEd25519Public,
    ].join('.');

    final signature = await _ed25519.sign(
      utf8.encode(unsigned),
      keyPair: identity.edPrivate,
    );

    return EncryptedEnvelope(
      version: '1',
      key: base64UrlEncode(wrappedKey),
      nonce: base64UrlEncode(secretBox.nonce),
      ciphertext: base64UrlEncode(secretBox.cipherText),
      mac: base64UrlEncode(secretBox.mac.bytes),
      senderEd25519: base64UrlEncode(identity.edPublic.bytes),
      signature: base64UrlEncode(signature.bytes),
    ).encode();
  }

  Future<String> decryptDirectMessage(String encodedEnvelope) async {
    final identity = await ensureIdentity();
    final map = jsonDecode(encodedEnvelope) as Map<String, dynamic>;
    final wrappedKey = base64Url.decode(map['key'] as String);
    final nonce = base64Url.decode(map['nonce'] as String);
    final ciphertext = base64Url.decode(map['ciphertext'] as String);
    final mac = base64Url.decode(map['mac'] as String);

    final rsa = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(identity.rsaPrivate));
    final keyBytes = rsa.process(Uint8List.fromList(wrappedKey));

    final box = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );
    return utf8.decode(await _aes.decrypt(box, secretKey: SecretKey(keyBytes)));
  }

  Future<String> exportPublicIdentity() async {
    final identity = await ensureIdentity();
    return jsonEncode(identity.publicBundle());
  }

  Future<String> exportEncryptedPrivateBackup(String passphrase) async {
    if (passphrase.length < 12) {
      throw ArgumentError('Backup passphrase must contain at least 12 characters.');
    }
    final identity = await ensureIdentity();
    final payload = jsonEncode({
      'version': 1,
      'rsaPrivate': _rsaPrivateToJson(identity.rsaPrivate),
      'rsaPublic': _rsaPublicToJson(identity.rsaPublic),
      'edPrivate': base64UrlEncode(await identity.edPrivate.extractPrivateKeyBytes()),
      'edPublic': base64UrlEncode(identity.edPublic.bytes),
    });

    final salt = _randomBytes(16);
    final kdf = Argon2id(memory: 16 * 1024, parallelism: 2, iterations: 2, hashLength: 32);
    final key = await kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
    final box = await _aes.encrypt(utf8.encode(payload), secretKey: key);

    return jsonEncode({
      'version': 1,
      'kdf': 'Argon2id',
      'salt': base64UrlEncode(salt),
      'nonce': base64UrlEncode(box.nonce),
      'ciphertext': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    });
  }

  AsymmetricKeyPair<PublicKey, PrivateKey> _generateRsaKeyPair() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List.fromList(_randomBytes(32));
    secureRandom.seed(KeyParameter(seed));

    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));
    return generator.generateKeyPair();
  }

  Map<String, dynamic> _rsaPublicToJson(RSAPublicKey key) => {
        'n': _bigIntToB64(key.modulus),
        'e': _bigIntToB64(key.exponent),
      };

  Map<String, dynamic> _rsaPrivateToJson(RSAPrivateKey key) => {
        'n': _bigIntToB64(key.modulus),
        'e': _bigIntToB64(key.publicExponent),
        'd': _bigIntToB64(key.privateExponent),
        'p': _bigIntToB64(key.p!),
        'q': _bigIntToB64(key.q!),
      };

  RSAPublicKey _rsaPublicFromJson(Map<String, dynamic> value) => RSAPublicKey(
        _b64ToBigInt(value['n'] as String),
        _b64ToBigInt(value['e'] as String),
      );

  RSAPrivateKey _rsaPrivateFromJson(Map<String, dynamic> value) => RSAPrivateKey(
        _b64ToBigInt(value['n'] as String),
        _b64ToBigInt(value['e'] as String),
        _b64ToBigInt(value['d'] as String),
        _b64ToBigInt(value['p'] as String),
        _b64ToBigInt(value['q'] as String),
      );

  static String _bigIntToB64(BigInt value) => base64UrlEncode(_bigIntBytes(value));

  static BigInt _b64ToBigInt(String value) => _bytesToBigInt(base64Url.decode(value));

  static Uint8List _bigIntBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList([0]);
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static BigInt _bytesToBigInt(List<int> bytes) => BigInt.parse(
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );

  static List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));
}
