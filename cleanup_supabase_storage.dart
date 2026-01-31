import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'config/supabase_config.dart';

class SupabaseCleanupService {
  late SupabaseClient _client;
  static const String _bucketName = 'documents';

  SupabaseCleanupService() {
    _client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  }

  // List all files in the Supabase storage bucket
  Future<List<String>> listAllFiles() async {
    try {
      final response = await _client.storage.from(_bucketName).list();
      return response.map((file) => file.name).toList();
    } catch (e) {
      print('Error listing files from Supabase: $e');
      return [];
    }
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
  Future<void> deleteMultipleFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      print('No files to delete');
      return;
    }

    print('Attempting to delete ${filePaths.length} files from Supabase storage...');
    
    int successCount = 0;
    for (String filePath in filePaths) {
      bool success = await deleteFile(filePath);
      if (success) {
        successCount++;
      }
    }
    
    print('Successfully deleted $successCount out of ${filePaths.length} files from Supabase storage.');
  }

  // Clean up all files in Supabase storage (DANGER ZONE!)
  Future<void> deleteAllFiles() async {
    print('WARNING: This will delete ALL files in the Supabase storage bucket!');
    print('Are you sure you want to proceed? Type "YES" to confirm:');
    
    String? confirmation = stdin.readLineSync();
    
    if (confirmation == 'YES') {
      final allFiles = await listAllFiles();
      await deleteMultipleFiles(allFiles);
    } else {
      print('Operation cancelled.');
    }
  }
}

void main() async {
  final cleanupService = SupabaseCleanupService();
  
  print('Supabase Storage Cleanup Tool');
  print('=============================');
  print('1. List all files in Supabase storage');
  print('2. Delete all files in Supabase storage (DANGER ZONE!)');
  print('3. Exit');
  print('');
  print('Enter your choice (1-3): ');
  
  String? choice = stdin.readLineSync();
  
  switch (choice) {
    case '1':
      final files = await cleanupService.listAllFiles();
      print('\nFiles in Supabase storage (${files.length} total):');
      for (int i = 0; i < files.length; i++) {
        print('${i + 1}. ${files[i]}');
      }
      break;
      
    case '2':
      await cleanupService.deleteAllFiles();
      break;
      
    case '3':
      print('Exiting...');
      break;
      
    default:
      print('Invalid choice. Exiting...');
  }
}