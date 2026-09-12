import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_PROJECT_URL',
    anonKey: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
  );

  runApp(const DamadamApp());
}

class DamadamApp extends StatelessWidget {
  const DamadamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Damadam',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Damadam',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
