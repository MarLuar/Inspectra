import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/viewer_tracking_model.dart';

class ViewerTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _viewersCollection => _firestore.collection('project_viewers');

  // Track when a user views a project
  Future<void> trackProjectView({
    required String projectId,
    required String viewerUserId,
    required String viewerName,
    String? deviceInfo,
  }) async {
    try {
      final viewerTracking = ViewerTracking(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Using timestamp as ID
        projectId: projectId,
        viewerUserId: viewerUserId,
        viewerName: viewerName,
        viewTime: DateTime.now(),
        deviceInfo: deviceInfo,
      );

      await _viewersCollection.add(viewerTracking.toFirebaseJson());

      print('Tracked project view for user: $viewerName, project: $projectId');
    } catch (e) {
      print('Error tracking project view: $e');
      rethrow;
    }
  }

  // Get recent viewers for a project
  Stream<List<ViewerTracking>> getRecentViewersForProject(String projectId) {
    return _viewersCollection
        .where('project_id', isEqualTo: projectId)
        .orderBy('view_time', descending: true)
        .limit(10) // Limit to last 10 viewers
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ViewerTracking.fromFirebaseSnapshot(data);
      }).toList();
    });
  }

  // Get recent viewers for a project (non-stream version)
  Future<List<ViewerTracking>> getRecentViewersForProjectOnce(String projectId) async {
    try {
      final snapshot = await _viewersCollection
          .where('project_id', isEqualTo: projectId)
          .orderBy('view_time', descending: true)
          .limit(10) // Limit to last 10 viewers
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ViewerTracking.fromFirebaseSnapshot(data);
      }).toList();
    } catch (e) {
      print('Error getting recent viewers: $e');
      return [];
    }
  }

  // Clean old records (older than 30 days)
  Future<void> cleanOldRecords(String projectId) async {
    try {
      final cutoffDate = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      final querySnapshot = await _viewersCollection
          .where('project_id', isEqualTo: projectId)
          .where('view_time', isLessThan: cutoffDate)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('Cleaned ${querySnapshot.size} old viewer records for project: $projectId');
    } catch (e) {
      print('Error cleaning old viewer records: $e');
    }
  }
}