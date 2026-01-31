import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/firebase_config.dart';
import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/projects_list_screen.dart';
import 'screens/project_detail_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/esp32_transfer_screen.dart';
import 'package:provider/provider.dart';
import 'services/supabase_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseConfig.initializeFirebase();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize Supabase storage service to check bucket existence
  final storageService = SupabaseStorageService();
  await storageService.initializeBucket();

  runApp(const InSpectraApp());
}

class InSpectraApp extends StatelessWidget {
  const InSpectraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InSpectra',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      // Check if user is authenticated to determine initial route
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            return const HomeScreen(); // User is signed in
          } else {
            return const AuthScreen(); // User is not signed in
          }
        },
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/projects': (context) => const ProjectsListScreen(),
        '/project-detail': (context) => ProjectDetailScreen(
              projectName: ModalRoute.of(context)?.settings.arguments as String?,
            ),
        '/qr-scanner': (context) => const QrScannerScreen(),
        '/auth': (context) => const AuthScreen(),
        '/esp32-transfer': (context) => Esp32TransferScreen(
              projectName: ModalRoute.of(context)?.settings.arguments as String?,
            ),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}