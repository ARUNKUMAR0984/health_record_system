// lib/services/blockchain_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class BlockchainService {
  static String sha256bytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  static String computeHash({
    required int index,
    required String prevHash,
    required String fileHash,
    required int timestamp,
  }) {
    final input = "$index|$prevHash|$fileHash|$timestamp";
    return sha256.convert(utf8.encode(input)).toString();
  }

  static bool verifyChain(List<Map<String, dynamic>> blocks) {
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      final id = block['id'];
      final prev = block['previous_hash'] ?? "";
      final fileHash = block['file_hash'];
      final ts = block['timestamp'];
      final stored = block['current_hash'];

      final recalculated = computeHash(
        index: id,
        prevHash: prev,
        fileHash: fileHash,
        timestamp: ts,
      );

      if (stored != recalculated) return false;

      if (i > 0) {
        if (prev != blocks[i - 1]['current_hash']) return false;
      }
    }
    return true;
  }
}
