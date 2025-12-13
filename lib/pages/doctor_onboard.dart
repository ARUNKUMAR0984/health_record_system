// lib/pages/doctor_onboarding.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/crypto_service.dart';
import 'package:motion_toast/motion_toast.dart';

// UI COLOR CONSTANTS (Reused for consistency)
const Color primaryColor = Color(0xFF2C5F7C); // Deep Ocean Blue
const Color secondaryColor = Color(0xFF5AB693); // Soft Teal Green for accents/success
const Color backgroundColor = Color(0xFFF0F4F8); // Light Blue-Grey Background
const Color cardColor = Colors.white;
const Color errorColor = Color(0xFFE57373); // Light Red
const Color successColor = secondaryColor;

class DoctorOnboarding extends StatefulWidget {
  const DoctorOnboarding({super.key});
  @override
  State<DoctorOnboarding> createState() => _DoctorOnboardingState();
}

class _DoctorOnboardingState extends State<DoctorOnboarding> {
  bool loading = false;
  String? status;

  Future<void> createKeysAndUpload() async {
    setState(() => loading = true);
    try {
      // 1. Generate the keypair (Public Key and Private Key)
      final pubB64 = await CryptoService.generateAndStoreKeypair();
      
      // 2. Upload only the Public Key to the database
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('doctors')
          .update({'public_key': pubB64})
          .eq('user_id', userId);
      
      // 3. Success Feedback
      MotionToast.success(
        title: const Text('Success!'),
        description: const Text('Keypair generated and Public Key uploaded successfully.'),
        toastDuration: const Duration(seconds: 4),
      ).show(context);
      setState(() => status = 'Keypair setup complete! Public key uploaded.');
      
      // Optionally, navigate to the main dashboard after success
      // Note: You would typically add a navigation step here.
      
    } catch (e) {
      // 4. Error Feedback
      MotionToast.error(
        title: const Text('Key Generation Error'),
        description: Text('Failed to generate or upload keys. Details: ${e.toString()}'),
        toastDuration: const Duration(seconds: 6),
      ).show(context);
      setState(() => status = 'Error: Key generation failed.');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Doctor Setup', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Security Info Card ---
              _buildInfoCard(),
              const SizedBox(height: 32),

              // --- Action Button ---
              if (loading)
                const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              else
                ElevatedButton.icon(
                  onPressed: createKeysAndUpload,
                  icon: const Icon(Icons.vpn_key_rounded, size: 24),
                  label: const Text(
                    'Generate Keys & Activate Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                ),

              // --- Status Display ---
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: status!.contains("Error") ? errorColor.withOpacity(0.1) : successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: status!.contains("Error") ? errorColor : successColor),
                    ),
                    child: Text(
                      status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: status!.contains("Error") ? errorColor : primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ---------------------------------------------------------------------
  // Informative Security Card
  // ---------------------------------------------------------------------
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: primaryColor, size: 30),
              SizedBox(width: 10),
              Text(
                "Digital Signature Setup",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.grey),
          Text(
            "This critical step generates your unique cryptographic keypair (Private and Public keys).",
            style: TextStyle(fontSize: 15, color: Colors.grey[800]),
          ),
          const SizedBox(height: 12),
          _buildBulletPoint(
            "Your **Private Key** is stored locally and securely. It is used to digitally sign every medical record you create.",
            Icons.fingerprint,
          ),
          _buildBulletPoint(
            "Your **Public Key** is uploaded to the server. It allows patients to verify that the record truly came from you and hasn't been tampered with.",
            Icons.cloud_upload_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: secondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: text.split('**').map((span) {
                  if (span.startsWith('Private Key') || span.startsWith('Public Key')) {
                    return TextSpan(
                      text: span,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                    );
                  }
                  return TextSpan(text: span, style: TextStyle(color: Colors.grey[700], height: 1.4));
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}