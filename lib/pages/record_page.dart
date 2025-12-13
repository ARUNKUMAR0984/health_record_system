// lib/pages/records_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:health_record_system/pages/view_page.dart';

import 'package:health_record_system/services/blockchain_service.dart';

import 'package:health_record_system/services/crypto_service.dart';
import '../services/supabase_service.dart';
import '../services/merkletree_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordsPage extends StatefulWidget {
  final String patientId;
  const RecordsPage({super.key, required this.patientId});
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final supabase = SupabaseService();
  List<Map<String, dynamic>> blocks = [];
  bool chainOk = true;
  bool merkleOk = true;
  List<Map<String, dynamic>> verificationResults = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    blocks = await supabase.getPatientBlocks(widget.patientId);
    await verifyAll();
    setState(() => loading = false);
  }

  Future<void> verifyAll() async {
    verificationResults.clear();

    // chain structural check
    chainOk = BlockchainService.verifyChain(blocks);

    // per-block signature verification
    for (final block in blocks) {
      final docId = block['doctor_id'] as String?;
      bool sigOk = false;
      String docName = 'Unknown';
      if (docId != null) {
        final doc = await Supabase.instance.client.from('doctors').select('public_key, name').eq('user_id', docId).maybeSingle();
        if (doc != null) {
          final pub = doc['public_key'] as String?;
          docName = doc['name'] ?? docName;
          if (pub != null && block['doctor_signature'] != null) {
            try {
              sigOk = await CryptoService.verifySignature(
                bytes: utf8.encode(block['current_hash']),
                signatureB64: block['doctor_signature'],
                publicKeyB64: pub,
              );
            } catch (_) {
              sigOk = false;
            }
          }
        }
      }
      verificationResults.add({'block_id': block['id'], 'doctor': docName, 'signature_valid': sigOk});
    }

    // merkle check
    final hashes = await supabase.getPatientHashes(widget.patientId);
    final merkle = merkleRootFromHashes(hashes);
    final lastBlockMerkle = blocks.isNotEmpty ? blocks.last['merkle_root'] as String? : null;
    merkleOk = (merkle == lastBlockMerkle);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Medical Records')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ListTile(
                  title: Text(chainOk ? 'CHAIN VALID ✓' : 'CHAIN TAMPERED ✗', style: TextStyle(color: chainOk ? Colors.green : Colors.red)),
                  trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: load),
                ),
                ListTile(
                  title: Text(merkleOk ? 'MERKLE ROOT VALID ✓' : 'MERKLE ROOT TAMpered ✗', style: TextStyle(color: merkleOk ? Colors.green : Colors.red)),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: blocks.length,
                    itemBuilder: (context, i) {
                      final b = blocks[i];
                      final v = verificationResults.length > i ? verificationResults[i] : null;
                      final url = b['file_url'] as String;
                      final fileName = url.split('/').last;
                      final sigOk = v != null ? v['signature_valid'] as bool : false;
                      final doctorName = v != null ? v['doctor'] as String : 'Unknown';

                      return Card(
                        child: ListTile(
                          leading: Icon(sigOk ? Icons.verified : Icons.error, color: sigOk ? Colors.green : Colors.red),
                          title: Text(fileName),
                          subtitle: Text('Block: ${b['id']}\nDoctor: $doctorName\nHash: ${b['current_hash'].toString().substring(0, 16)}...'),
                          trailing: IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewFilePage(block: b,)))),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
    );
  }
}
