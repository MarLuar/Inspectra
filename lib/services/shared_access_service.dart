import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'firebase_sync_service.dart';
import '../models/project_model.dart';

class SharedAccessService {
  final DatabaseService _dbService = DatabaseService();
  final FirebaseSyncService _firebaseService = FirebaseSyncService();

  // Grant access to a project for another user
  Future<void> grantProjectAccess({
    required String projectId,
    required String granteeEmail,
    String accessLevel = 'view',
  }) async {
    if (!_firebaseService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final grantorUserId = _firebaseService.currentUserId!;
    
    // Find the grantee user by email
    // Note: In a real implementation, you'd need a way to look up user IDs by email
    // For now, we'll assume we have the user ID
    // This would require a user lookup service or similar
    String? granteeUserId = await _findUserIdByEmail(granteeEmail);
    
    if (granteeUserId == null) {
      throw Exception('User with email $granteeEmail not found');
    }

    // Update the project to be shared
    final project = await _dbService.getProjectById(projectId);
    if (project != null) {
      final updatedProject = Project(
        id: project.id,
        name: project.name,
        createdAt: project.createdAt,
        qrCodePath: project.qrCodePath,
        documentCount: project.documentCount,
        location: project.location,
        ownerUserId: project.ownerUserId,
        isShared: 1, // Mark as shared
      );
      await _dbService.insertProject(updatedProject);
      
      // Also update in Firebase
      if (_firebaseService.isAuthenticated) {
        await _firebaseService.syncProject(updatedProject);
      }
    }

    // Add shared access record
    await _dbService.addSharedAccess(
      resourceId: projectId,
      resourceType: 'project',
      grantorUserId: grantorUserId,
      granteeUserId: granteeUserId,
      accessLevel: accessLevel,
    );
  }

  // Grant access to a document for another user
  Future<void> grantDocumentAccess({
    required String documentId,
    required String granteeEmail,
    String accessLevel = 'view',
  }) async {
    if (!_firebaseService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final grantorUserId = _firebaseService.currentUserId!;
    
    // Find the grantee user by email
    String? granteeUserId = await _findUserIdByEmail(granteeEmail);
    
    if (granteeUserId == null) {
      throw Exception('User with email $granteeEmail not found');
    }

    // Update the document to be shared
    final document = await _dbService.getDocumentById(documentId);
    if (document != null) {
      final updatedDocument = Document(
        id: document.id,
        projectId: document.projectId,
        name: document.name,
        path: document.path,
        category: document.category,
        createdAt: document.createdAt,
        fileType: document.fileType,
        qrCodePath: document.qrCodePath,
        ownerUserId: document.ownerUserId,
        isShared: 1, // Mark as shared
      );
      await _dbService.updateDocument(updatedDocument);
      
      // Also update in Firebase
      if (_firebaseService.isAuthenticated) {
        await _firebaseService.syncDocument(updatedDocument);
      }
    }

    // Add shared access record
    await _dbService.addSharedAccess(
      resourceId: documentId,
      resourceType: 'document',
      grantorUserId: grantorUserId,
      granteeUserId: granteeUserId,
      accessLevel: accessLevel,
    );
  }

  // Get all projects accessible to the current user
  Future<List<Project>> getAccessibleProjects() async {
    if (!_firebaseService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final userId = _firebaseService.currentUserId!;
    return await _dbService.getProjectsForUser(userId);
  }

  // Get all documents in a project accessible to the current user
  Future<List<Document>> getAccessibleDocumentsInProject(String projectId) async {
    if (!_firebaseService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final userId = _firebaseService.currentUserId!;
    return await _dbService.getDocumentsForUserInProject(projectId, userId);
  }

  // Check if current user has access to a specific project
  Future<bool> hasProjectAccess(String projectId) async {
    if (!_firebaseService.isAuthenticated) {
      return false;
    }

    final userId = _firebaseService.currentUserId!;
    return await _dbService.hasResourceAccess(
      resourceId: projectId,
      userId: userId,
      resourceType: 'project',
    );
  }

  // Check if current user has access to a specific document
  Future<bool> hasDocumentAccess(String documentId) async {
    if (!_firebaseService.isAuthenticated) {
      return false;
    }

    final userId = _firebaseService.currentUserId!;
    return await _dbService.hasResourceAccess(
      resourceId: documentId,
      userId: userId,
      resourceType: 'document',
    );
  }

  // Helper method to find user ID by email
  // In a real implementation, this would query a users collection in Firestore
  Future<String?> _findUserIdByEmail(String email) async {
    // This is a simplified implementation
    // In a real app, you'd need a proper user lookup mechanism
    try {
      // For demo purposes, we'll just return the current user ID
      // In a real implementation, you would query Firestore for the user ID
      return _firebaseService.currentUserId;
    } catch (e) {
      print('Error finding user by email: $e');
      return null;
    }
  }
}