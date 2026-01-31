import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/project_model.dart'; // Contains both Project and Document models
import 'supabase_storage_service.dart';
import 'database_service.dart';

class FirebaseSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseStorageService _supabaseStorage = SupabaseStorageService();
  SupabaseStorageService get supabaseStorage => _supabaseStorage;

  // Reference to user's data in Firestore
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _projectsCollection => _firestore.collection('projects');
  CollectionReference get _documentsCollection => _firestore.collection('documents');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Sign up a new user
  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Firebase sign up error: $e');
      rethrow; // Re-throw the exception so it can be handled upstream
    }
  }

  // Sign in a user
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Firebase sign in error: $e');
      rethrow; // Re-throw the exception so it can be handled upstream
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Sync a project to Firebase
  Future<void> syncProject(Project project) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    await _projectsCollection.doc(project.id).set({
      'id': project.id,
      'name': project.name,
      'created_at': Timestamp.fromDate(project.createdAt),
      'qr_code_path': project.qrCodePath,
      'document_count': project.documentCount,
      'location': project.location,
      'user_id': currentUserId,
      'owner_user_id': project.ownerUserId ?? currentUserId,
      'is_shared': project.isShared,
    });
  }

  // Sync a document to Firebase
  Future<void> syncDocument(Document document) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Upload file to Supabase Storage first
    String? downloadUrl;
    if (document.path.isNotEmpty) {
      downloadUrl = await _uploadFileToSupabase(document.path, document.id);
    }

    await _documentsCollection.doc(document.id).set({
      'id': document.id,
      'project_id': document.projectId,
      'name': document.name,
      'path': downloadUrl ?? document.path, // Use cloud URL if uploaded, otherwise local path
      'category': document.category,
      'created_at': Timestamp.fromDate(document.createdAt),
      'file_type': document.fileType,
      'user_id': currentUserId,
      'owner_user_id': document.ownerUserId ?? currentUserId,
      'is_shared': document.isShared,
      'qr_code_path': document.qrCodePath,
    });
  }

  // Upload file to Supabase Storage
  Future<String?> _uploadFileToSupabase(String localPath, String documentId) async {
    try {
      if (!await File(localPath).exists()) {
        return null;
      }

      // Get the document to retrieve its project ID and then get the project name
      final DatabaseService dbService = DatabaseService();
      final Document? document = await dbService.getDocumentById(documentId);

      String? projectName;
      if (document != null) {
        final Project? project = await dbService.getProjectById(document.projectId);
        projectName = project?.name;
      }

      final fileName = localPath.split('/').last;
      return await _supabaseStorage.uploadFile(
        localPath,
        fileName,
        userId: currentUserId,
        projectId: document?.projectId,
        projectName: projectName,
        category: document?.category,
        documentName: document?.name,
      );
    } catch (e) {
      print('Error uploading file to Supabase: $e');
      return null;
    }
  }

  // Download file from Supabase Storage
  Future<String?> downloadFileFromSupabase(String fileUrl, String fileName) async {
    try {
      return await _supabaseStorage.downloadFile(fileUrl, fileName);
    } catch (e) {
      print('Error downloading file from Supabase: $e');
      return null;
    }
  }

  // Get all projects for current user
  Stream<List<Project>> getUserProjects() {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    return _projectsCollection
        .where('user_id', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Project(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          createdAt: (data['created_at'] as Timestamp).toDate(),
          qrCodePath: data['qr_code_path'],
          documentCount: data['document_count'] ?? 0,
          location: data['location'],
          ownerUserId: data['owner_user_id'],
          isShared: data['is_shared'] ?? 0,
        );
      }).toList();
    });
  }

  // Get all projects accessible to current user (owned + shared)
  Stream<List<Project>> getAccessibleProjects() {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // First get user's own projects
    var query = _projectsCollection.where('user_id', isEqualTo: currentUserId);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Project(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          createdAt: (data['created_at'] as Timestamp).toDate(),
          qrCodePath: data['qr_code_path'],
          documentCount: data['document_count'] ?? 0,
          location: data['location'],
          ownerUserId: data['owner_user_id'],
          isShared: data['is_shared'] ?? 0,
        );
      }).toList();
    });
  }

  // Get all documents for a project
  Stream<List<Document>> getProjectDocuments(String projectId) {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    return _documentsCollection
        .where('project_id', isEqualTo: projectId)
        .where('user_id', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Document(
          id: data['id'] ?? '',
          projectId: data['project_id'] ?? '',
          name: data['name'] ?? '',
          path: data['path'] ?? '',
          category: data['category'] ?? '',
          createdAt: (data['created_at'] as Timestamp).toDate(),
          fileType: data['file_type'] ?? '',
          ownerUserId: data['owner_user_id'],
          isShared: data['is_shared'] ?? 0,
          qrCodePath: data['qr_code_path'],
        );
      }).toList();
    });
  }

  // Delete a project from Firebase
  Future<void> deleteProject(String projectId) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Delete all documents associated with the project first
    final documentsSnapshot = await _documentsCollection
        .where('project_id', isEqualTo: projectId)
        .where('user_id', isEqualTo: currentUserId)
        .get();

    for (final doc in documentsSnapshot.docs) {
      await _documentsCollection.doc(doc.id).delete();
    }

    // Then delete the project
    await _projectsCollection.doc(projectId).delete();
  }

  // Delete a document from Firebase
  Future<void> deleteDocument(String documentId) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // First get the document to retrieve its path for file deletion
    final docSnapshot = await _documentsCollection.doc(documentId).get();
    if (docSnapshot.exists) {
      final documentData = docSnapshot.data() as Map<String, dynamic>?;
      final path = documentData?['path'] as String?;

      // Delete the file from Supabase regardless of whether it's a URL or direct path
      if (path != null) {
        await _supabaseStorage.deleteFile(path);
      }
    }

    await _documentsCollection.doc(documentId).delete();
  }

  // Sync all local data to Firebase
  Future<void> syncAllData() async {
    // This would typically sync all local data to Firebase
    // Implementation would depend on how local data is stored
  }

  // Pull all data from Firebase
  Future<void> pullAllData() async {
    // This would typically pull all data from Firebase to local storage
    // Implementation would depend on how local data is stored
  }
}