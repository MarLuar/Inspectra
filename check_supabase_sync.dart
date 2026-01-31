import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'config/supabase_config.dart';

class SupabaseStorageSyncChecker {
  late SupabaseClient _client;
  static const String _bucketName = 'documents';

  SupabaseStorageSyncChecker() {
    _client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  }

  // Get all files from Supabase storage
  Future<List<String>> getAllSupabaseFiles() async {
    try {
      final response = await _client.storage.from(_bucketName).list();
      return response.map((file) => file.name).toList();
    } catch (e) {
      print('Error listing files from Supabase: $e');
      return [];
    }
  }

  // Get all document paths from local database
  Future<List<String>> getAllLocalDocumentPaths() async {
    try {
      // Get the database path
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'inspectra.db');

      // Open the database
      final db = await openDatabase(path);

      // Query all document paths
      final List<Map<String, dynamic>> maps = await db.query('documents', columns: ['path']);

      // Close the database
      await db.close();

      // Extract paths and filter for Supabase URLs
      List<String> localPaths = [];
      for (var map in maps) {
        String path = map['path'] as String;
        // If the path is a Supabase URL, extract the file path portion
        if (path.contains('supabase.co/storage/v1/object/public/documents/')) {
          // Extract the file path from the URL
          String fileName = path.split('/').last;
          localPaths.add(fileName); // Add just the filename for comparison
        } else if (!path.startsWith('http')) {
          // If it's a local path, add it as is
          localPaths.add(path);
        }
      }

      return localPaths;
    } catch (e) {
      print('Error getting local document paths: $e');
      return [];
    }
  }

  // Find files in Supabase that are not referenced in the local database
  Future<List<String>> findOrphanedFiles() async {
    final supabaseFiles = await getAllSupabaseFiles();
    final localDocumentPaths = await getAllLocalDocumentPaths();

    // Create a set of filenames from local document paths for faster lookup
    Set<String> localFileNames = {};
    for (String path in localDocumentPaths) {
      String fileName = path.split('/').last; // Extract filename
      localFileNames.add(fileName);
    }

    // Find files in Supabase that are not referenced locally
    List<String> orphanedFiles = [];
    for (String supabaseFile in supabaseFiles) {
      String fileName = supabaseFile.split('/').last; // Extract filename
      if (!localFileNames.contains(fileName)) {
        orphanedFiles.add(supabaseFile);
      }
    }

    return orphanedFiles;
  }

  // Delete a file from Supabase storage by its path
  Future<bool> deleteFile(String filePath) async {
    try {
      await _client.storage.from(_bucketName).remove([filePath]);
      print('Successfully deleted file from Supabase: $filePath');
      return true;
    } catch (e) {
      print('Error deleting file from Supabase: $e');
      return false;
    }
  }

  // Delete multiple files from Supabase storage
  Future<void> deleteOrphanedFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      print('No orphaned files to delete');
      return;
    }

    print('Found ${filePaths.length} orphaned files in Supabase storage:');
    for (int i = 0; i < filePaths.length; i++) {
      print('${i + 1}. ${filePaths[i]}');
    }

    print('\nDo you want to delete these files? Type "YES" to confirm:');
    String? confirmation = stdin.readLineSync();

    if (confirmation == 'YES') {
      print('\nDeleting orphaned files...');
      int successCount = 0;
      for (String filePath in filePaths) {
        bool success = await deleteFile(filePath);
        if (success) {
          successCount++;
        }
        // Add a small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('\nSuccessfully deleted $successCount out of ${filePaths.length} orphaned files from Supabase storage.');
    } else {
      print('Operation cancelled.');
    }
  }
}

void main() async {
  final checker = SupabaseStorageSyncChecker();

  print('Supabase Storage Sync Checker');
  print('=============================');
  print('This tool will identify files in Supabase storage that are no longer');
  print('referenced in your local database and offer to delete them.');
  print('');

  // Find orphaned files
  final orphanedFiles = await checker.findOrphanedFiles();

  if (orphanedFiles.isEmpty) {
    print('No orphaned files found in Supabase storage. Your storage is clean!');
  } else {
    print('Found ${orphanedFiles.length} orphaned files in Supabase storage.');
    await checker.deleteOrphanedFiles(orphanedFiles);
  }
}