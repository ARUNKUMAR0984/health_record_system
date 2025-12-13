// lib/pages/upload_page_advanced.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/blockchain_service.dart';
import '../services/crypto_service.dart';
import '../services/encryption_service.dart';
import '../services/merkletree_service.dart';

class UploadPageAdvanced extends StatefulWidget {
  final String patientId;
  const UploadPageAdvanced({super.key, required this.patientId});

  @override
  State<UploadPageAdvanced> createState() => _UploadPageAdvancedState();
}

class _UploadPageAdvancedState extends State<UploadPageAdvanced> {
  final supabase = SupabaseService();
  bool loading = false;
  String? selectedFileName;
  String? selectedFileSize;
  Map<String, dynamic>? patientInfo;

  @override
  void initState() {
    super.initState();
    loadPatientInfo();
  }

  /// Load patient information
  Future<void> loadPatientInfo() async {
    try {
      final patient = await Supabase.instance.client
          .from('patients')
          .select('name, age')
          .eq('user_id', widget.patientId)
          .maybeSingle();

      if (mounted && patient != null) {
        setState(() {
          patientInfo = patient;
        });
      }
    } catch (e) {
      debugPrint('Error loading patient info: $e');
    }
  }

  /// Proof of Work miner
  int mineNonce(String data, int difficulty) {
    int nonce = 0;
    while (true) {
      final h = BlockchainService.sha256bytes(
        utf8.encode('$data|$nonce'),
      );
      if (h.startsWith('0' * difficulty)) return nonce;
      nonce++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      // HEADER
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: const Text(
          'Secure File Upload',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      body: Column(
        children: [
          // ------------------------------
          // PATIENT INFO HEADER
          // ------------------------------
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Uploading for:",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          patientInfo != null 
                              ? patientInfo!['name'] ?? 'Patient'
                              : 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (patientInfo != null && patientInfo!['age'] != null)
                          Text(
                            'Age: ${patientInfo!['age']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ------------------------------
          // SECURITY FEATURES SECTION
          // ------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_rounded,
                        color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Security Features",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Security features grid
                Row(
                  children: [
                    Expanded(
                      child: _buildSecurityCard(
                        icon: Icons.lock_outline_rounded,
                        title: "AES-256",
                        subtitle: "Encryption",
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSecurityCard(
                        icon: Icons.verified_user_rounded,
                        title: "Digital",
                        subtitle: "Signature",
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecurityCard(
                        icon: Icons.link_rounded,
                        title: "Blockchain",
                        subtitle: "Verified",
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSecurityCard(
                        icon: Icons.psychology_rounded,
                        title: "Proof of",
                        subtitle: "Work",
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ------------------------------
          // FILE SELECTION AREA
          // ------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: loading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.blue[700],
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Processing secure upload...",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Encrypting • Signing • Mining",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Upload icon
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selectedFileName != null
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_rounded,
                              size: 64,
                              color: selectedFileName != null
                                  ? Colors.green[600]
                                  : Colors.blue[700],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // File info or prompt
                          if (selectedFileName != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.insert_drive_file_rounded,
                                      color: Colors.green[700]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedFileName!,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (selectedFileSize != null)
                                          Text(
                                            selectedFileSize!,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedFileName = null;
                                        selectedFileSize = null;
                                      });
                                    },
                                    icon: Icon(Icons.close_rounded,
                                        color: Colors.grey[600]),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: uploadAndSign,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_rounded),
                                      SizedBox(width: 8),
                                      Text(
                                        "Upload Securely",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              "Select a file to upload",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Your file will be encrypted and secured\nwith blockchain technology",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: selectFile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.folder_open_rounded),
                                      SizedBox(width: 8),
                                      Text(
                                        "Choose File",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> selectFile() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null) return;

    final file = File(picked.files.single.path!);
    final fileSize = await file.length();
    
    setState(() {
      selectedFileName = picked.files.single.name;
      selectedFileSize = _formatFileSize(fileSize);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> uploadAndSign() async {
    if (selectedFileName == null) {
      await selectFile();
      if (selectedFileName == null) return;
    }

    final picked = await FilePicker.platform.pickFiles();
    if (picked == null) return;

    final file = File(picked.files.single.path!);
    setState(() => loading = true);

    try {
      // STEP 1 — READ BYTES
      final bytes = await file.readAsBytes();

      // STEP 2 — FILE HASH
      final fileHash = BlockchainService.sha256bytes(bytes);

      // STEP 3 — AES ENCRYPTION
      final enc = EncryptionService.encryptBytes(bytes);
      final cipherBytes = enc['cipherBytes'] as List<int>;
      final keyB64 = enc['keyBase64'] as String;
      final ivB64 = enc['ivBase64'] as String;

      // STEP 4 — FETCH LAST BLOCK
      final lastBlock = await supabase.getLastBlock(widget.patientId);
      final lastId = lastBlock != null ? lastBlock['id'] as int : 0;

      final nextIndex = lastId + 1;
      final prevHash = lastBlock?['current_hash'] ?? "";
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // STEP 5 — COMPUTE BLOCK HASH
      final currHash = BlockchainService.computeHash(
        index: nextIndex,
        prevHash: prevHash,
        fileHash: fileHash,
        timestamp: timestamp,
      );

      // STEP 6 — OPTIONAL POW
      const difficulty = 2;
      final nonce = mineNonce(currHash, difficulty);

      // STEP 7 — UPLOAD ENCRYPTED BYTES
      final filename = "${const Uuid().v4()}_${p.basename(file.path)}.enc";

      final fileUrl = await supabase.uploadFileBytes(cipherBytes, filename);

      // STEP 8 — MERKLE ROOT
      final oldHashes = await supabase.getPatientHashes(widget.patientId);
      final merkleRoot = merkleRootFromHashes([...oldHashes, currHash]);

      // STEP 9 — SIGN BLOCK HASH
      final signature = await CryptoService.signBytes(utf8.encode(currHash));

      final doctorId = Supabase.instance.client.auth.currentUser!.id;

      // STEP 10 — INSERT BLOCK INTO DB
      await supabase.insertBlock({
        'patient_id': widget.patientId,
        'doctor_id': doctorId,
        'file_url': fileUrl,
        'file_hash': fileHash,
        'previous_hash': prevHash,
        'current_hash': currHash,
        'doctor_signature': signature,
        'merkle_root': merkleRoot,
        'nonce': nonce,
        'difficulty': difficulty,
        'iv': ivB64,
        'key_base64': keyB64,
        'timestamp': timestamp,
      });

      // STEP 11 — TOAST
      if (!mounted) return;
      MotionToast.success(
        title: const Text("Success"),
        description:
            const Text("Encrypted record uploaded & signed successfully"),
      ).show(context);

      // Clear selection and go back
      setState(() {
        selectedFileName = null;
        selectedFileSize = null;
      });
      
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint("UPLOAD ERROR → $e \n$st");

      if (!mounted) return;
      MotionToast.error(
        title: const Text("Error"),
        description: Text("Upload failed: $e"),
      ).show(context);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}