import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qswrhxldcmkvkbwtwurm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFzd3JoeGxkY21rdmtid3R3dXJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0MTkyODAsImV4cCI6MjA3ODk5NTI4MH0.WOTYPpes_y1bZrd57wBUE37AtW8ooFp3OZsRd-36Ypk',
  );

  runApp(const HealthChainApp());
}

class HealthChainApp extends StatelessWidget {
  const HealthChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthChain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}
