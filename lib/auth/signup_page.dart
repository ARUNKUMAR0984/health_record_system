// lib/pages/signup_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/doctor_dashboard.dart';
import '../pages/patient_dashboard.dart';
import 'package:motion_toast/motion_toast.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final nameC = TextEditingController();
  final ageC = TextEditingController();
  final specializationC = TextEditingController();

  String selectedRole = "patient";
  String? selectedDoctor;
  bool loading = false;
  bool _obscurePassword = true;
  List<Map<String, dynamic>> doctors = [];

  @override
  void initState() {
    super.initState();
    loadDoctors();
  }

  Future<void> loadDoctors() async {
    final res = await Supabase.instance.client.from('doctors').select('user_id, name, specialization').order('name');
    setState(() => doctors = List<Map<String, dynamic>>.from(res));
  }

  Future<void> signup() async {
    if (emailC.text.isEmpty || passC.text.isEmpty || nameC.text.isEmpty) {
      MotionToast.error(title: const Text('Error'), description: const Text('Fill required fields')).show(context);
      return;
    }
    if (selectedRole == 'patient' && (ageC.text.isEmpty || selectedDoctor == null)) {
      MotionToast.error(title: const Text('Error'), description: const Text('Patient needs age & assigned doctor')).show(context);
      return;
    }
    if (selectedRole == 'doctor' && specializationC.text.isEmpty) {
      MotionToast.error(title: const Text('Error'), description: const Text('Doctor needs specialization')).show(context);
      return;
    }

    setState(() => loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(email: emailC.text.trim(), password: passC.text.trim());
      final user = res.user;
      if (user == null) throw 'Signup failed';
      final userId = user.id;

      await Supabase.instance.client.from('roles').insert({'user_id': userId, 'role': selectedRole});

      if (selectedRole == 'doctor') {
        await Supabase.instance.client.from('doctors').insert({
          'user_id': userId,
          'name': nameC.text.trim(),
          'specialization': specializationC.text.trim(),
        });
        MotionToast.success(title: const Text('Success'), description: const Text('Doctor account created')).show(context);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoctorDashboard()));
      } else {
        final patient = await Supabase.instance.client.from('patients').insert({
          'user_id': userId,
          'name': nameC.text.trim(),
          'age': int.parse(ageC.text.trim()),
        }).select().single();

        final patientId = patient['id'];
        await Supabase.instance.client.from('patient_doctor').insert({
          'patient_id': patientId,
          'doctor_id': selectedDoctor,
        });

        MotionToast.success(title: const Text('Success'), description: const Text('Patient account created')).show(context);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PatientDashboard()));
      }
    } catch (e) {
      MotionToast.error(title: const Text('Error'), description: Text('Signup failed: $e')).show(context);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join our Health Chain System',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Signup Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Role Selection
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.badge_outlined, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'I am a:',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: selectedRole,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    icon: Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'patient',
                                        child: Text('Patient'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'doctor',
                                        child: Text('Doctor'),
                                      ),
                                    ],
                                    onChanged: (v) => setState(() => selectedRole = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email Field
                        TextField(
                          controller: emailC,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.blue[700]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextField(
                          controller: passC,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Create a password',
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.blue[700]),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name Field
                        TextField(
                          controller: nameC,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icon(Icons.person_outline, color: Colors.blue[700]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),

                        // Doctor-specific fields
                        if (selectedRole == 'doctor') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: specializationC,
                            decoration: InputDecoration(
                              labelText: 'Specialization',
                              hintText: 'e.g., Cardiology, Pediatrics',
                              prefixIcon: Icon(Icons.medical_services_outlined, color: Colors.blue[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ],

                        // Patient-specific fields
                        if (selectedRole == 'patient') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: ageC,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Age',
                              hintText: 'Enter your age',
                              prefixIcon: Icon(Icons.cake_outlined, color: Colors.blue[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_hospital_outlined, color: Colors.blue[700], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Assign Primary Doctor',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: DropdownButton<String>(
                                    hint: Text(
                                      'Select your doctor',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    value: selectedDoctor,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    icon: Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
                                    items: doctors.map((doc) {
                                      return DropdownMenuItem<String>(
                                        value: doc['user_id'].toString(),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              doc['name'],
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            Text(
                                              doc['specialization'],
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => selectedDoctor = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Create Account Button
                        SizedBox(
                          height: 56,
                          child: loading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.blue[700],
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}