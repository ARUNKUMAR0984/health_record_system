// lib/services/merkletree_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

String merkleRootFromHashes(List<String> hexHashes) {
  if (hexHashes.isEmpty) return '';
  List<String> layer = List<String>.from(hexHashes);
  while (layer.length > 1) {
    final List<String> next = [];
    for (var i = 0; i < layer.length; i += 2) {
      final left = layer[i];
      final right = (i + 1 < layer.length) ? layer[i + 1] : left;
      final combined = utf8.encode(left + right);
      next.add(_sha256Hex(combined));
    }
    layer = next;
  }
  return layer.first;
}
