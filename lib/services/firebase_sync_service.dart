import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/project_model.dart'; // Contains both Project and Document models

class FirebaseSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    });
  }

  // Sync a document to Firebase
  Future<void> syncDocument(Document document) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Upload file to Firebase Storage first
    String? downloadUrl;
    if (document.path.isNotEmpty) {
      downloadUrl = await _uploadFileToStorage(document.path, document.id);
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
    });
  }

  // Upload file to Firebase Storage
  Future<String?> _uploadFileToStorage(String localPath, String documentId) async {
    try {
      if (!await File(localPath).exists()) {
        return null;
      }

      final file = File(localPath);
      final ref = _storage.ref().child('documents/$currentUserId/$documentId');
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading file to Firebase Storage: $e');
      return null;
    }
  }

  // Download file from Firebase Storage
  Future<String?> downloadFileFromStorage(String downloadUrl, String fileName) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      
      await ref.writeToFile(File(filePath));
      return filePath;
    } catch (e) {
      print('Error downloading file from Firebase Storage: $e');
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