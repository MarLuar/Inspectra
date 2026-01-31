import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/project_model.dart';

class Esp32CommunicationService {
  static const String _defaultEsp32Ip = '192.168.50.245'; // Default ESP32 IP with static configuration
  late String _esp32Ip;
  final Dio _dio = Dio();

  Esp32CommunicationService({String? esp32Ip}) {
    _esp32Ip = esp32Ip ?? _defaultEsp32Ip;
    // Configure Dio with timeout
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Updates the ESP32 IP address
  void updateEsp32Ip(String newIp) {
    _esp32Ip = newIp;
  }

  /// Tests connection to ESP32
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('http://$_esp32Ip/status');
      return response.statusCode == 200;
    } catch (e) {
      print('ESP32 connection test failed: $e');
      return false;
    }
  }

  /// Sends a project with all its files to ESP32
  Future<bool> sendProjectToEsp32(Project project, List<Document> documents) async {
    try {
      // Create project directory on ESP32
      final projectDirResponse = await _dio.post(
        'http://$_esp32Ip/create_project_dir',
        data: {'project_name': project.name},
      );
      
      if (projectDirResponse.statusCode != 200) {
        throw Exception('Failed to create project directory on ESP32');
      }

      // Send each document to ESP32
      for (final document in documents) {
        await _sendDocumentToEsp32(project.name, document);
      }

      return true;
    } catch (e) {
      print('Error sending project to ESP32: $e');
      return false;
    }
  }

  /// Sends a single document to ESP32
  Future<bool> _sendDocumentToEsp32(String projectName, Document document) async {
    try {
      // Prepare multipart form data
      final formData = FormData.fromMap({
        'project_name': projectName,
        'category': document.category,
        'file': await MultipartFile.fromFile(
          document.path,
          filename: document.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        'http://$_esp32Ip/upload_file',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).round();
          print('Upload progress for ${document.name}: $progress%');
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending document to ESP32: $e');
      return false;
    }
  }

  /// Gets list of projects stored on ESP32
  Future<List<Map<String, dynamic>>> getEsp32Projects() async {
    try {
      final response = await _dio.get('http://$_esp32Ip/list_projects');
      
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get projects from ESP32');
      }
    } catch (e) {
      print('Error getting projects from ESP32: $e');
      return [];
    }
  }

  /// Gets list of files in a specific project on ESP32
  Future<List<Map<String, dynamic>>> getProjectFiles(String projectName) async {
    try {
      final response = await _dio.get(
        'http://$_esp32Ip/list_files',
        queryParameters: {'project_name': projectName},
      );
      
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get files from ESP32 for project: $projectName');
      }
    } catch (e) {
      print('Error getting files from ESP32: $e');
      return [];
    }
  }

  /// Gets ESP32 status information
  Future<Map<String, dynamic>?> getEsp32Status() async {
    try {
      final response = await _dio.get('http://$_esp32Ip/status');
      
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting ESP32 status: $e');
      return null;
    }
  }

  /// Formats file size in human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}