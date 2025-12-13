// lib/services/supabase_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  Future<String> uploadFile(File file, String filename) async {
    final path = 'records/$filename';
    final bytes = await file.readAsBytes();
    await client.storage.from('health-records').uploadBinary(path, Uint8List.fromList(bytes));
    return client.storage.from('health-records').getPublicUrl(path);
  }

  Future<String> uploadFileBytes(List<int> bytes, String filename) async {
    final path = 'records/$filename';
    await client.storage.from('health-records').uploadBinary(path, Uint8List.fromList(bytes));
    return client.storage.from('health-records').getPublicUrl(path);
  }

  Future<Map<String, dynamic>?> getLastBlock(String patientId) async {
    final res = await client
        .from('blockchain_records')
        .select('*')
        .eq('patient_id', patientId)
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  Future<void> insertBlock(Map<String, dynamic> data) async {
    await client.from('blockchain_records').insert(data);
  }

  Future<List<Map<String, dynamic>>> getPatientBlocks(String patientId) async {
    final res = await client
        .from('blockchain_records')
        .select('*')
        .eq('patient_id', patientId)
        .order('id');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<String>> getPatientHashes(String patientId) async {
    final res = await client
        .from('blockchain_records')
        .select('current_hash')
        .eq('patient_id', patientId)
        .order('id');
    final list = List<Map<String, dynamic>>.from(res);
    return list.map((r) => r['current_hash'] as String).toList();
  }

  Future<void> insertAudit({
    required String who,
    required String action,
    required String targetTable,
    String? targetId,
    Map<String, dynamic>? payload,
  }) async {
    await client.from('audit_log').insert({
      'who': who,
      'action': action,
      'target_table': targetTable,
      'target_id': targetId,
      'payload': payload,
    });
  }
}
