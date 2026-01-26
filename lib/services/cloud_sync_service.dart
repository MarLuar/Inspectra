import '../models/project_model.dart';
import 'firebase_sync_service.dart';
import 'database_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CloudSyncService {
  final FirebaseSyncService _firebaseService = FirebaseSyncService();
  FirebaseSyncService get firebaseService => _firebaseService;
  final DatabaseService _localDbService = DatabaseService();

  // Check if user is authenticated
  bool get isAuthenticated => _firebaseService.isAuthenticated;

  // Sign in
  Future<void> signIn(String email, String password) async {
    try {
      await _firebaseService.signIn(email, password);
    } catch (e) {
      print('CloudSyncService sign in error: $e');
      rethrow; // Re-throw the exception so it can be handled upstream
    }
  }

  // Sign up
  Future<void> signUp(String email, String password) async {
    try {
      await _firebaseService.signUp(email, password);
    } catch (e) {
      print('CloudSyncService sign up error: $e');
      rethrow; // Re-throw the exception so it can be handled upstream
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseService.signOut();
  }

  // Sync a single project to cloud
  Future<void> syncProjectToCloud(Project project) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Sync to Firebase
    await _firebaseService.syncProject(project);
  }

  // Sync a single document to cloud
  Future<void> syncDocumentToCloud(Document document) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Sync to Firebase
    await _firebaseService.syncDocument(document);
  }

  // Sync all projects and documents to cloud
  Future<void> syncAllToCloud() async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Get all local projects
    final localProjects = await _localDbService.getProjects();
    
    // Sync each project to cloud
    for (final project in localProjects) {
      await syncProjectToCloud(project);
      
      // Get all documents for this project
      final documents = await _localDbService.getDocumentsByProject(project.id);
      
      // Sync each document to cloud
      for (final document in documents) {
        await syncDocumentToCloud(document);
      }
    }
  }

  // Pull all data from cloud to local
  Future<void> pullAllFromCloud() async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Get all projects from Firebase
    final cloudProjectsStream = _firebaseService.getUserProjects();
    
    // Listen once to get current projects
    final cloudProjects = await cloudProjectsStream.first;
    
    // Update local database with cloud data
    for (final cloudProject in cloudProjects) {
      // Insert or update project in local database
      await _localDbService.insertProject(cloudProject);
      
      // Get documents for this project from cloud
      final cloudDocumentsStream = _firebaseService.getProjectDocuments(cloudProject.id);
      final cloudDocuments = await cloudDocumentsStream.first;
      
      // Update local documents
      for (final cloudDocument in cloudDocuments) {
        await _localDbService.insertDocument(cloudDocument);
      }
    }
  }

  // Enable real-time sync between local and cloud
  void enableRealTimeSync() {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Listen for changes in local projects and sync to cloud
    // This would typically involve setting up listeners
    // For now, we'll just return
  }

  // Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    if (!isAuthenticated) {
      return {
        'isAuthenticated': false,
        'localProjectsCount': 0,
        'cloudProjectsCount': 0,
        'syncStatus': 'Not authenticated',
      };
    }

    final localProjects = await _localDbService.getProjects();
    final cloudProjectsStream = _firebaseService.getUserProjects();
    final cloudProjects = await cloudProjectsStream.first;

    // Count total documents locally
    int totalLocalDocuments = 0;
    for (final project in localProjects) {
      final documents = await _localDbService.getDocumentsByProject(project.id);
      totalLocalDocuments += documents.length;
    }

    // Count total documents in cloud
    int totalCloudDocuments = 0;
    for (final project in cloudProjects) {
      final documentsStream = _firebaseService.getProjectDocuments(project.id);
      final documents = await documentsStream.first;
      totalCloudDocuments += documents.length;
    }

    // Compare not just counts but also check if projects exist in both locations
    bool projectsMatch = true;
    for (final localProject in localProjects) {
      bool foundInCloud = cloudProjects.any((cloudProject) => cloudProject.id == localProject.id);
      if (!foundInCloud) {
        projectsMatch = false;
        break;
      }
    }

    // Check if documents match for each project
    bool documentsMatch = true;
    for (final localProject in localProjects) {
      final localDocs = await _localDbService.getDocumentsByProject(localProject.id);
      final cloudDocsStream = _firebaseService.getProjectDocuments(localProject.id);
      final cloudDocs = await cloudDocsStream.first;

      if (localDocs.length != cloudDocs.length) {
        documentsMatch = false;
        break;
      }

      // Check if each document exists in both locations
      for (final localDoc in localDocs) {
        bool foundInCloud = cloudDocs.any((cloudDoc) => cloudDoc.id == localDoc.id);
        if (!foundInCloud) {
          documentsMatch = false;
          break;
        }
      }
    }

    String syncStatus = 'Out of sync';
    if (localProjects.length == cloudProjects.length &&
        totalLocalDocuments == totalCloudDocuments &&
        projectsMatch &&
        documentsMatch) {
      syncStatus = 'Synced';
    } else if (localProjects.length == 0 && cloudProjects.length == 0) {
      syncStatus = 'Synced (no data)';
    } else if (localProjects.length > 0 || cloudProjects.length > 0) {
      syncStatus = 'Out of sync';
    }

    return {
      'isAuthenticated': true,
      'localProjectsCount': localProjects.length,
      'cloudProjectsCount': cloudProjects.length,
      'localDocumentsCount': totalLocalDocuments,
      'cloudDocumentsCount': totalCloudDocuments,
      'syncStatus': syncStatus,
    };
  }

  // Manual sync trigger
  Future<void> manualSync() async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    try {
      // First, pull any changes from cloud (cloud -> local)
      await pullAllFromCloud();

      // Then, push local changes to cloud (local -> cloud)
      await syncAllToCloud();

      print('Manual sync completed successfully');
    } catch (e) {
      print('Error during manual sync: $e');
      rethrow;
    }
  }
}