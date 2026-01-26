// This is a diagnostic script to help troubleshoot sync issues
// Place this in lib/utils/sync_diagnostics.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_sync_service.dart';

class SyncDiagnostics {
  final CloudSyncService _cloudSyncService;
  
  SyncDiagnostics(this._cloudSyncService);

  Future<Map<String, dynamic>> runDiagnostics() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    
    final diagnostics = <String, dynamic>{};
    
    // Check authentication status
    diagnostics['isAuthenticated'] = auth.currentUser != null;
    diagnostics['userId'] = auth.currentUser?.uid ?? 'N/A';
    
    // Check Firestore connectivity
    try {
      await firestore.collection('test_connection').limit(1).get();
      diagnostics['firestoreConnected'] = true;
    } catch (e) {
      diagnostics['firestoreConnected'] = false;
      diagnostics['firestoreError'] = e.toString();
    }
    
    // Get sync status
    try {
      final syncStatus = await _cloudSyncService.getSyncStatus();
      diagnostics.addAll(syncStatus);
    } catch (e) {
      diagnostics['syncStatusError'] = e.toString();
    }
    
    // Check for specific collections
    try {
      final userProjects = await _cloudSyncService.firebaseService.getUserProjects().first;
      diagnostics['cloudProjectsCountDetailed'] = userProjects.length;
      
      int totalCloudDocs = 0;
      for (final project in userProjects) {
        final docs = await _cloudSyncService.firebaseService.getProjectDocuments(project.id).first;
        totalCloudDocs += docs.length;
      }
      diagnostics['totalCloudDocumentsDetailed'] = totalCloudDocs;
    } catch (e) {
      diagnostics['cloudDataRetrievalError'] = e.toString();
    }
    
    return diagnostics;
  }
}