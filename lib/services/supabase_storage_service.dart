import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/supabase_config.dart';

class SupabaseStorageService {
  late SupabaseClient _client;
  static const String _bucketName = 'documents';

  // Initialize Supabase client with your project details
  SupabaseStorageService() {
    _client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  }

  // Public getter for the client
  SupabaseClient get client => _client;

  // Initialize the storage bucket - this should be done manually in the Supabase dashboard
  // Creating buckets programmatically requires service role key which shouldn't be in client code
  Future<void> initializeBucket() async {
    try {
      // Check if the bucket exists
      final buckets = await _client.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == _bucketName);

      if (!bucketExists) {
        print('Bucket $_bucketName does not exist. Please create it in the Supabase dashboard.');
      } else {
        print('Bucket $_bucketName exists and is ready for use.');
      }
    } catch (e) {
      print('Error checking bucket existence: $e');
    }
  }

  // Upload a file to Supabase storage with metadata
  Future<String?> uploadFile(String localFilePath, String fileName, {String? userId, String? projectId, String? projectName, String? category, String? documentName, String? qrCodeData}) async {
    try {
      if (!await File(localFilePath).exists()) {
        print('File does not exist: $localFilePath');
        return null;
      }

      // Create a file name with project name and category (fallback to project ID if name is not provided)
      String uniqueFileName = fileName;
      if (projectId != null && category != null) {
        final fileExtension = fileName.split('.').last;
        // Use document name if provided, otherwise use the original filename without extension
        final fileNameWithoutExt = (documentName != null && documentName.isNotEmpty)
            ? documentName
            : fileName.replaceAll(RegExp(r'\.[^.]*$'), '');

        // Use project name if available, otherwise fallback to project ID
        String projectIdentifier = projectName ?? projectId;
        uniqueFileName = '$projectIdentifier/$category/$fileNameWithoutExt.$fileExtension';
      } else if (userId != null) {
        final fileExtension = fileName.split('.').last;
        final fileNameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
        uniqueFileName = '$userId/$fileNameWithoutExt.$fileExtension';
      }

      await _client.storage.from(_bucketName).upload(
        uniqueFileName,
        File(localFilePath),
        fileOptions: const FileOptions(upsert: true),
      );

      // Insert metadata into documents table
      final file = File(localFilePath);

      // Prepare the data for insertion
      final data = {
        'name': documentName ?? fileName,
        'path': uniqueFileName,
        'project_id': projectId,
        'category': category ?? 'Documents',
        'storage_path': uniqueFileName,
        'file_size': await file.length(),
        'mime_type': _getMimeType(fileName),
      };

      // Only add owner_id if it's provided and appears to be a valid UUID format
      // Firebase user IDs are not UUIDs, so we need to handle this carefully
      if (userId != null && _isValidUuid(userId)) {
        data['owner_id'] = userId;
      } else if (_client.auth.currentUser?.id != null && _isValidUuid(_client.auth.currentUser!.id)) {
        data['owner_id'] = _client.auth.currentUser!.id;
      }

      // Add QR code data if provided
      if (qrCodeData != null) {
        data['qr_code'] = qrCodeData;
      }

      await _client.from('documents').insert(data);

      // Get the public URL for the uploaded file
      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(uniqueFileName);
      return publicUrl;
    } catch (e) {
      print('Error uploading file to Supabase: $e');
      // Check if it's an RLS policy error
      if (e.toString().contains('violates row-level security policy')) {
        print('This error is likely due to insufficient permissions. Make sure:');
        print('- The storage bucket exists in your Supabase dashboard');
        print('- The documents table exists in your database');
        print('- The RLS policies are properly configured for authenticated users');
        print('- You have the correct permissions set up in your Supabase project');
      }
      return null;
    }
  }

  // Upload QR code as a separate file for a project
  Future<String?> uploadProjectQrCode(String qrCodeFilePath, String projectName, String projectId, String? userId) async {
    try {
      if (!await File(qrCodeFilePath).exists()) {
        print('QR code file does not exist: $qrCodeFilePath');
        return null;
      }

      // Create a specific file name for the project QR code following the requested naming convention
      final fileName = 'qrcode($projectName).png';
      final uniqueFileName = '$projectName/qrcodes/$fileName';

      await _client.storage.from(_bucketName).upload(
        uniqueFileName,
        File(qrCodeFilePath),
        fileOptions: const FileOptions(upsert: true),
      );

      // Insert metadata into documents table for the QR code
      final file = File(qrCodeFilePath);
      final data = {
        'name': 'qrcode($projectName)',
        'path': uniqueFileName,
        'project_id': projectId,
        'category': 'QR Codes',
        'storage_path': uniqueFileName,
        'file_size': await file.length(),
        'mime_type': 'image/png',
        'qr_code': 'INSPROJECT:$projectId|$projectName', // Store the QR code data as well
      };

      // Only add owner_id if it's a valid UUID format
      if (userId != null) {
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );

        if (uuidRegex.hasMatch(userId)) {
          data['owner_id'] = userId;
        }
      }

      await _client.from('documents').insert(data);

      // Get the public URL for the uploaded QR code file
      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(uniqueFileName);
      print('QR code uploaded for project: $projectName with path: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Error uploading QR code to Supabase: $e');
      return null;
    }
  }

  // Download a file from Supabase storage
  Future<String?> downloadFile(String fileUrl, String fileName) async {
    try {
      // Extract file path from URL
      final RegExp exp = RegExp(r'/([^/]+)$'); // Match the last part after the last '/'
      final Match? match = exp.firstMatch(fileUrl);

      if (match == null) {
        print('Could not extract file name from URL: $fileUrl');
        return null;
      }

      final filePath = match.group(1)!;

      // Download the file content
      final response = await _client.storage.from(_bucketName).download(filePath);

      // Save to local device
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/$fileName');

      await localFile.writeAsBytes(response);
      return localFile.path;
    } catch (e) {
      print('Error downloading file from Supabase: $e');
      return null;
    }
  }

  // Delete a file from Supabase storage
  Future<bool> deleteFile(String filePath) async {
    try {
      // If the path looks like a URL, extract the actual file path
      String actualFilePath = filePath;
      if (filePath.startsWith('http')) {
        // Extract file path from URL
        final RegExp exp = RegExp(r'/([^/]+)$');
        final Match? match = exp.firstMatch(filePath);

        if (match == null) {
          print('Could not extract file name from URL: $filePath');
          return false;
        }

        actualFilePath = match.group(1)!;
      }

      await _client.storage.from(_bucketName).remove([actualFilePath]);
      return true;
    } catch (e) {
      print('Error deleting file from Supabase: $e');
      return false;
    }
  }

  // Get public URL for a file
  String getPublicUrl(String filePath) {
    return _client.storage.from(_bucketName).getPublicUrl(filePath);
  }

  // List files in a specific user's folder
  Future<List<String>> listFiles({String? userId}) async {
    try {
      String? path = userId;
      if (path != null) {
        path = '$path/';
      }

      final response = await _client.storage.from(_bucketName).list(path: path);
      return response.map((file) => getPublicUrl(file.name)).toList();
    } catch (e) {
      print('Error listing files from Supabase: $e');
      return [];
    }
  }

  // Helper method to check if a string is a valid UUID format
  bool _isValidUuid(String uuid) {
    // A valid UUID has the format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // where x is any hexadecimal digit and y is one of 8, 9, A, or B
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

}