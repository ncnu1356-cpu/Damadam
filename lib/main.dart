import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fhmshhmklsqgiyvcdvbr.supabase.co',
    anonKey: 'sb_publishable_gTJUg-94UMGG7FF73Ey58g_ZLoeEZoW',
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
