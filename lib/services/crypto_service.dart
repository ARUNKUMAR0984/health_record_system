// lib/services/crypto_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _secureStorage = const FlutterSecureStorage();
final _ed = Ed25519();

class CryptoService {
  static const _seedKey = 'doctor_private_seed_b64';
  static const _pubKey = 'doctor_public_key_b64';

  static Uint8List _randomSeed32() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return Uint8List.fromList(bytes);
  }

  /// Generate keypair and store seed & public key locally. Returns public key base64.
  static Future<String> generateAndStoreKeypair() async {
    final seed = _randomSeed32();
    final keyPair = await _ed.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    await _secureStorage.write(key: _seedKey, value: base64Encode(seed));
    await _secureStorage.write(key: _pubKey, value: base64Encode(publicKey.bytes));
    return base64Encode(publicKey.bytes);
  }

  static Future<KeyPair> _loadKeyPairFromSeed() async {
    final seedB64 = await _secureStorage.read(key: _seedKey);
    if (seedB64 == null) throw Exception('Private seed not found.');
    final seed = base64Decode(seedB64);
    return _ed.newKeyPairFromSeed(Uint8List.fromList(seed));
  }

  static Future<String> signBytes(List<int> bytes) async {
    final kp = await _loadKeyPairFromSeed();
    final sig = await _ed.sign(bytes, keyPair: kp);
    return base64Encode(sig.bytes);
  }

  static Future<bool> verifySignature({
    required List<int> bytes,
    required String signatureB64,
    required String publicKeyB64,
  }) async {
    final sig = base64Decode(signatureB64);
    final pub = base64Decode(publicKeyB64);
    final publicKey = SimplePublicKey(Uint8List.fromList(pub), type: KeyPairType.ed25519);
    try {
      return await _ed.verify(bytes, signature: Signature(Uint8List.fromList(sig), publicKey: publicKey));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPrivateKey() async {
    final v = await _secureStorage.read(key: _seedKey);
    return v != null;
  }

  static Future<String?> getStoredPublicKey() async {
    return await _secureStorage.read(key: _pubKey);
  }
}
