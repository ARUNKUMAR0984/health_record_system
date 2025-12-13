// lib/pages/doctor_dashboard.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';
import 'doctor_onboard.dart';
import 'upload_page_advanced.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final client = Supabase.instance.client;

  bool loading = true;
  String doctorName = "Doctor";
  String doctorSpecialization = "";
  List<Map<String, dynamic>> assignedPatients = [];

  @override
  void initState() {
    super.initState();
    initAll();
  }

  // ------------------------------
  // INIT WORKFLOW
  // ------------------------------
  Future<void> initAll() async {
    await ensureOnboarded();
    await loadDoctorInfo();
    await loadAssignedPatients();

    if (mounted) {
      setState(() => loading = false);
    }
  }

  // ------------------------------
  // CHECK IF DOCTOR HAS A PUBLIC KEY
  // ------------------------------
  Future<void> ensureOnboarded() async {
    final userId = client.auth.currentUser!.id;

    final doc = await client
        .from("doctors")
        .select("public_key")
        .eq("user_id", userId)
        .maybeSingle();

    if (doc == null || doc["public_key"] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DoctorOnboarding()),
        );
      });

      return; // ⭐ CRITICAL FIX → prevents running next functions too early
    }
  }

  // ------------------------------
  // LOAD NAME & SPECIALIZATION
  // ------------------------------
  Future<void> loadDoctorInfo() async {
    final userId = client.auth.currentUser!.id;

    final doc = await client
        .from("doctors")
        .select("name, specialization")
        .eq("user_id", userId)
        .maybeSingle();

    if (doc != null && mounted) {
      setState(() {
        doctorName = doc["name"] ?? "Doctor";
        doctorSpecialization = doc["specialization"] ?? "";
      });
    }
  }

  // ------------------------------
  // LOAD ASSIGNED PATIENTS
  // ------------------------------
  Future<void> loadAssignedPatients() async {
    final doctorId = client.auth.currentUser!.id;

    final res = await client
        .from("patient_doctor")
        .select("patient_id, patients(name, age)")
        .eq("doctor_id", doctorId);

    if (mounted) {
      setState(() {
        assignedPatients = List<Map<String, dynamic>>.from(res);
      });
    }
  }

  // ------------------------------
  // UI
  // ------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      // HEADER
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        title: const Text(
          "Doctor Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await client.auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: "Logout",
          ),
        ],
      ),

      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.blue[700],
              ),
            )
          : Column(
              children: [
                // ------------------------------
                // DOCTOR INFO HEADER
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
                            Icons.medical_services_rounded,
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
                                "Welcome back,",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Dr. $doctorName",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (doctorSpecialization.isNotEmpty)
                                Text(
                                  doctorSpecialization,
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

                // ------------------------------
                // PATIENT COUNTER CARD
                // ------------------------------
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[600]!,
                          Colors.blue[800]!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.people_rounded,
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
                                "Total Patients",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${assignedPatients.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ------------------------------
                // PATIENT LIST TITLE
                // ------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.folder_shared_rounded,
                          color: Colors.grey[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Your Patients",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ------------------------------
                // PATIENT LIST
                // ------------------------------
                Expanded(
                  child: assignedPatients.isEmpty
                      ? Center(
                          child: Text(
                            "No patients assigned yet.",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: assignedPatients.length,
                          itemBuilder: (context, index) {
                            final patient = assignedPatients[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.person,
                                      color: Colors.blue[700]),
                                ),

                                title: Text(
                                  patient['patients']['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),

                                subtitle: Text(
                                  "Age: ${patient['patients']['age']}",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14),
                                ),

                                trailing: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UploadPageAdvanced(
                                          patientId: patient['patient_id'],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: const Text("Upload"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
