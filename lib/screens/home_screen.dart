import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_sync_service.dart';
import 'document_scanner_screen.dart';
import '../screens/projects_list_screen.dart';
import '../screens/qr_scanner_screen.dart';
import 'technical_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CloudSyncService _cloudSyncService = CloudSyncService();
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    final status = await _cloudSyncService.getSyncStatus();
    setState(() {
      _syncStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('InSpectra', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(FirebaseAuth.instance.currentUser?.email ?? 'Guest'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'sync_status',
                child: Row(
                  children: [
                    Icon(
                      _syncStatus?['isAuthenticated'] == true ? Icons.cloud_done : Icons.cloud_off,
                      color: _syncStatus?['isAuthenticated'] == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(_syncStatus?['isAuthenticated'] == true ? 'Synced' : 'Not Synced'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'manual_sync',
                child: Row(
                  children: const [
                    Icon(Icons.sync, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Sync Now'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'version',
                child: Row(
                  children: const [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Version 1.03'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'sign_out',
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (String? value) async {
              if (value == 'sign_out') {
                await _cloudSyncService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/auth');
                }
              } else if (value == 'manual_sync') {
                try {
                  await _cloudSyncService.manualSync();
                  _loadSyncStatus(); // Refresh sync status
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync completed successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync failed: $e')),
                  );
                }
              } else if (value == 'sync_status') {
                // Show sync status details
                if (_syncStatus != null) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Sync Status'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Authenticated: ${_syncStatus!['isAuthenticated']}'),
                            Text('Local Projects: ${_syncStatus!['localProjectsCount']}'),
                            Text('Cloud Projects: ${_syncStatus!['cloudProjectsCount']}'),
                            Text('Status: ${_syncStatus!['syncStatus']}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              } else if (value == 'version') {
                // Navigate to technical details screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TechnicalDetailsScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to InSpectra',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DocumentScannerScreen()),
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: Text('Scan Document', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      minimumSize: const Size(200, 50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProjectsListScreen()),
                      );
                    },
                    icon: const Icon(Icons.folder),
                    label: Text('View Folders', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      minimumSize: const Size(200, 50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      minimumSize: const Size(200, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer with image
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset(
              'assets/images/qyra.png', // Path to the image
              width: 300, // 3x bigger (was 100)
              height: 150, // 3x bigger (was 50)
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}