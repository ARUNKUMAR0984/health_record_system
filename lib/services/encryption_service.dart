// lib/services/encryption_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class EncryptionService {
  static final _rnd = Random.secure();

  static Uint8List randomBytes(int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => _rnd.nextInt(256)));

  /// Returns cipher bytes, keyBase64, ivBase64
  static Map<String, dynamic> encryptBytes(List<int> plainBytes) {
    final keyBytes = randomBytes(32);
    final ivBytes = randomBytes(16);
    final key = Key(keyBytes);
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(Uint8List.fromList(plainBytes), iv: iv);
    return {
      'cipherBytes': encrypted.bytes,
      'keyBase64': base64Encode(keyBytes),
      'ivBase64': base64Encode(ivBytes),
    };
  }

  static List<int> decryptBytes(List<int> cipherBytes, String keyB64, String ivB64) {
    final key = Key(base64Decode(keyB64));
    final iv = IV(base64Decode(ivB64));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);
    return decrypted;
  }
}
