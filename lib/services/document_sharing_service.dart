import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import 'sharing_permissions_service.dart';
import '../models/shared_document_model.dart';
import '../models/project_model.dart'; // Need this for document access

class DocumentSharingService {
  final SharingPermissionsService _permissionsService = SharingPermissionsService();

  /// Shares a document using the device's native sharing functionality
  Future<void> shareDocument(String documentPath, {String? subject, String? text}) async {
    if (!await File(documentPath).exists()) {
      throw Exception('Document does not exist at path: $documentPath');
    }

    final file = File(documentPath);
    final fileName = path.basename(documentPath);

    await Share.shareXFiles(
      [XFile(documentPath)],
      subject: subject ?? 'Shared document: $fileName',
      text: text ?? 'Check out this document I shared with you',
    );
  }

  /// Shares a document with specific user and permissions
  Future<String> shareDocumentWithPermissions({
    required String documentId,
    required String sharedByUserId,
    required String sharedWithUserId,
    String accessLevel = 'view',
    DateTime? expirationDate,
  }) async {
    // Create a shared document record
    final sharedDocument = SharedDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID generation
      documentId: documentId,
      sharedByUserId: sharedByUserId,
      sharedWithUserId: sharedWithUserId,
      createdAt: DateTime.now(),
      accessLevel: accessLevel,
      expirationDate: expirationDate,
      isActive: true,
    );

    // Save to database
    await _permissionsService.insertSharedDocument(sharedDocument);

    // Generate a shareable link
    return 'https://inspectra.app/shared/${sharedDocument.id}';
  }

  /// Checks if a user has permission to access a document
  Future<bool> checkAccess(String documentId, String userId, String requiredAccessLevel) async {
    return await _permissionsService.hasAccess(documentId, userId, requiredAccessLevel);
  }

  /// Revokes a share
  Future<void> revokeShare(String shareId) async {
    await _permissionsService.revokeShare(shareId);
  }

  /// Gets all shares for a specific document
  Future<List<SharedDocument>> getDocumentShares(String documentId) async {
    return await _permissionsService.getSharesForDocument(documentId);
  }

  /// Generates a shareable link for a document (simulated)
  /// In a real implementation, this would upload to cloud storage and return a URL
  Future<String> generateShareableLink(String documentPath) async {
    if (!await File(documentPath).exists()) {
      throw Exception('Document does not exist at path: $documentPath');
    }

    // Simulate uploading to cloud and getting a shareable link
    // In a real implementation, this would involve actual cloud storage
    final fileName = path.basename(documentPath);
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // This is a simulated link - in reality, you'd upload to cloud storage
    return 'https://inspectra.app/shared/$fileId/${Uri.encodeComponent(fileName)}';
  }

  /// Copies a document to a temporary location for sharing (if needed)
  Future<String> prepareDocumentForSharing(String originalPath) async {
    final originalFile = File(originalPath);
    if (!await originalFile.exists()) {
      throw Exception('Document does not exist at path: $originalPath');
    }

    // Get temporary directory
    final tempDir = Directory.systemTemp;
    final fileName = path.basename(originalPath);
    final tempPath = '${tempDir.path}/$fileName';

    // Copy file to temporary location
    await originalFile.copy(tempPath);

    return tempPath;
  }

  /// Shares a document via email
  Future<void> shareViaEmail(String documentPath, {String? recipient, String? subject, String? body}) async {
    // This would require mailer package and email setup
    // For now, we'll simulate this functionality
    final link = await generateShareableLink(documentPath);
    final fileName = path.basename(documentPath);
    
    final emailBody = body ?? 'Please find the document "$fileName" attached or accessible via this link: $link';
    final emailSubject = subject ?? 'Shared Document: $fileName';
    
    // In a real implementation, this would open email client with attachment
    await Share.share(
      emailBody,
      subject: emailSubject,
    );
  }

  /// Uploads document to cloud storage (simulated)
  Future<String> uploadToCloud(String documentPath, {String? folderId}) async {
    if (!await File(documentPath).exists()) {
      throw Exception('Document does not exist at path: $documentPath');
    }

    // Simulate upload process
    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(documentPath, filename: path.basename(documentPath)),
      if (folderId != null) 'folderId': folderId,
    });

    // In a real implementation, this would upload to actual cloud service
    // For simulation, we'll just return a success message
    return await generateShareableLink(documentPath);
  }
}