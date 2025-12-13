import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:health_record_system/pages/view_page.dart';

import 'package:health_record_system/services/blockchain_service.dart';
import 'package:health_record_system/services/crypto_service.dart';
import '../services/supabase_service.dart';
import '../services/merkletree_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final supabase = SupabaseService();

  String? patientId;
  String patientName = "Patient";

  List<Map<String, dynamic>> blocks = [];
  List<Map<String, dynamic>> verificationResults = [];

  bool chainOk = true;
  bool merkleOk = true;
  bool loading = true;
  bool recordsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPatientProfile();
  }

  // ---------------------------------------------------------------------
  // LOAD PATIENT PROFILE FROM `patients`
  // ---------------------------------------------------------------------
  Future<void> _loadPatientProfile() async {
    setState(() => loading = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;

    final profile = await Supabase.instance.client
        .from('patients')
        .select('id, name')
        .eq('user_id', userId)
        .maybeSingle();

    if (profile != null) {
      patientId = profile['id'];
      patientName = (profile['name'] ?? "Patient").toString();
      await _loadRecords();
    }

    setState(() => loading = false);
  }

  // ---------------------------------------------------------------------
  // LOAD BLOCKS
  // ---------------------------------------------------------------------
  Future<void> _loadRecords() async {
    if (patientId == null) return;

    setState(() => recordsLoading = true);

    blocks = await supabase.getPatientBlocks(patientId!);

    await _verifyBlocks();

    setState(() => recordsLoading = false);
  }

  // ---------------------------------------------------------------------
  // VERIFY SIGNATURE + CHAIN + MERKLE
  // ---------------------------------------------------------------------
  Future<void> _verifyBlocks() async {
    verificationResults.clear();

    // Chain structural validation
    chainOk = BlockchainService.verifyChain(blocks);

    // Signature validation per-block
    for (final block in blocks) {
      final docId = block['doctor_id'];
      bool sigOk = false;
      String docName = "Unknown";

      if (docId != null) {
        final doc = await Supabase.instance.client
            .from("doctors")
            .select("name, public_key")
            .eq("user_id", docId)
            .maybeSingle();

        if (doc != null) {
          docName = doc["name"] ?? "Unknown";

          if (doc["public_key"] != null && block["doctor_signature"] != null) {
            sigOk = await CryptoService.verifySignature(
              bytes: utf8.encode(block["current_hash"]),
              signatureB64: block["doctor_signature"],
              publicKeyB64: doc["public_key"],
            );
          }
        }
      }

      verificationResults.add({
        "doctor": docName,
        "signature_valid": sigOk,
      });
    }

    // Merkle verification
    final hashes = await supabase.getPatientHashes(patientId!);
    final merkleLocal = merkleRootFromHashes(hashes);
    final merkleStored =
        blocks.isNotEmpty ? blocks.last["merkle_root"] : null;

    merkleOk = (merkleLocal == merkleStored);

    setState(() {});
  }

  // ---------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medical_services, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              "HealthChain",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F36),
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : patientId == null
              ? _buildProfileMissing()
              : _buildDashboardContent(),
    );
  }

  // ---------------------------------------------------------------------
  // UI if patient has no profile
  // ---------------------------------------------------------------------
  Widget _buildProfileMissing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_off, size: 64, color: Colors.red.shade400),
          ),
          const SizedBox(height: 20),
          const Text(
            "Patient profile not found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please contact support for assistance",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // MAIN DASHBOARD UI
  // ---------------------------------------------------------------------
  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadRecords,
      color: const Color(0xFF00B4DB),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
            const SizedBox(height: 24),
            _buildRecordsList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // HEADER UI
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B4DB).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF00B4DB).withOpacity(0.1),
              child: Text(
                patientName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00B4DB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // STATS CARDS
  // ---------------------------------------------------------------------
  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              "Total Records",
              blocks.length.toString(),
              Icons.description,
              const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              "Verified",
              verificationResults.where((v) => v["signature_valid"] == true).length.toString(),
              Icons.verified_user,
              const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SECURITY STATUS SECTION
  // ---------------------------------------------------------------------
  Widget _buildSecuritySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Security Verification",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVerificationCard(
                  "Blockchain\nIntegrity",
                  chainOk,
                  Icons.link,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVerificationCard(
                  "Merkle Root\nValidation",
                  merkleOk,
                  Icons.account_tree,
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(String title, bool valid, IconData icon, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: valid ? Colors.green.shade100 : Colors.red.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (valid ? Colors.green : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              valid ? Icons.check_circle : Icons.error,
              color: valid ? Colors.green : Colors.red,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valid ? "Valid" : "Tampered",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // RECORD LIST
  // ---------------------------------------------------------------------
  Widget _buildRecordsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4DB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.folder_shared,
                  color: Color(0xFF00B4DB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Medical Records",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        recordsLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : blocks.isEmpty
                ? _buildEmptyRecords()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: blocks.length,
                    itemBuilder: (context, i) {
                      final b = blocks[i];
                      final v = verificationResults[i];

                      final fileName =
                          (b["file_url"] as String).split("/").last;

                      return _buildRecordCard(
                        fileName: fileName,
                        doctor: v["doctor"],
                        hash: b["current_hash"],
                        blockId: b["id"].toString(),
                        verified: v["signature_valid"],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewFilePage(block: b),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildEmptyRecords() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox, color: Colors.grey[400], size: 60),
            ),
            const SizedBox(height: 16),
            const Text(
              "No medical records found",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Your records will appear here",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // CARD ITEM
  // ---------------------------------------------------------------------
  Widget _buildRecordCard({
    required String fileName,
    required String doctor,
    required String hash,
    required String blockId,
    required bool verified,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file,
                    color: Color(0xFF00B4DB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1F36),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Dr. $doctor",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (verified ? Colors.green : Colors.red).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        verified ? Icons.verified : Icons.error,
                        color: verified ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}