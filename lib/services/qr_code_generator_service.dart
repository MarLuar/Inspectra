import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class QrCodeGeneratorService {
  late SupabaseClient _client;

  QrCodeGeneratorService() {
    _client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  }

  /// Stores QR code data in Supabase
  Future<void> storeQrCodeInSupabase({
    required String projectId,
    required String projectName,
    required String qrCodeData,
  }) async {
    print('=== STARTING QR CODE STORAGE PROCESS ===');
    print('Project ID: $projectId');
    print('Project Name: $projectName');
    print('QR Code Data: $qrCodeData');

    try {
      // First, check if there are any documents for this project
      print('Checking for existing documents for project: $projectId');
      final existingDocs = await _client.from('documents').select('id').eq('project_id', projectId).limit(1);
      print('Found ${existingDocs.length} existing documents for project: $projectId');

      if (existingDocs.isNotEmpty) {
        print('Documents exist, attempting to update QR code for project: $projectName');
        // If documents exist, update them with the QR code data
        final updateResult = await _client.from('documents').update({
          'qr_code': qrCodeData,
        }).eq('project_id', projectId);

        print('Update operation completed. Result: $updateResult');
        print('QR code stored in Supabase for project: $projectName (ID: $projectId)');
      } else {
        print('No existing documents found for project: $projectName. Attempting to insert placeholder...');

        // If no documents exist yet, insert a placeholder record with QR code data
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          print('No authenticated user found, cannot insert QR code');
          return;
        }

        final data = {
          'name': 'QR_Code_Placeholder_$projectName',
          'project_id': projectId,
          'category': 'QR_Codes',
          'storage_path': '',
          'qr_code': qrCodeData,
          'file_size': 0,
          'mime_type': 'text/plain',
        };

        // Only add owner_id if it's a valid UUID format
        if (userId != null) {
          // Check if the user ID is a valid UUID format
          final uuidRegex = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            caseSensitive: false,
          );

          if (uuidRegex.hasMatch(userId)) {
            data['owner_id'] = userId;
          }
        }

        final insertResult = await _client.from('documents').insert(data);

        print('Insert operation completed. Result: $insertResult');
        print('QR code stored in Supabase for project: $projectName (ID: $projectId) using placeholder record');
      }
    } on PostgrestException catch (e) {
      print('PostgrestException storing QR code in Supabase documents table: $e');
      print('Error details - Code: ${e.code}, Message: ${e.message}, Hint: ${e.hint}');
      // If the qr_code column doesn't exist or RLS policy prevents access, try to insert into a separate table
      await _storeQrCodeInSeparateTable(projectName, qrCodeData);
    } catch (e) {
      print('Error storing QR code in Supabase documents table: $e');
      print('Error type: ${e.runtimeType}');
      // If the qr_code column doesn't exist, try to insert into a separate table
      await _storeQrCodeInSeparateTable(projectName, qrCodeData);
    }
    print('=== ENDING QR CODE STORAGE PROCESS ===');
  }

  /// Stores QR code in a separate table if the main documents table doesn't have a qr_code column
  Future<void> _storeQrCodeInSeparateTable(String projectName, String qrCodeData) async {
    print('Fallback QR code storage called for project: $projectName');
    print('This indicates that the primary storage method failed');

    try {
      // Create a separate table for QR codes if it doesn't exist
      // First, try to insert the QR code data into a dedicated qr_codes table
      await _client.from('qr_codes').insert({
        'project_name': projectName,
        'qr_code_data': qrCodeData,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('QR code stored in separate qr_codes table for project: $projectName');
    } catch (e) {
      print('Error storing QR code in separate table: $e');

      // If the qr_codes table doesn't exist, we might need to create it manually in Supabase
      // For now, log the QR code data so it's not lost
      print('QR Code Data for $projectName: $qrCodeData');
    }
  }

  /// Generates a QR code for a project and saves it to a file
  Future<String> generateProjectQrCode({
    required String projectId,
    required String projectName,
    int size = 200,
  }) async {
    // Create the QR code data string in the format expected by the scanner
    // Format: INSPROJECT:project-id|project-name
    final qrData = 'INSPROJECT:$projectId|$projectName';

    // Generate QR code using the qr_flutter package directly
    final qrCodePath = await _generateQrCodeWithQrPackage(qrData, projectName, size);

    // Note: We no longer store the QR code in Supabase here because
    // the user authentication context might not be available yet.
    // The QR code will be stored when the first document is added to the project
    // in the ProjectOrganizationService._storeProjectQrCode method.

    return qrCodePath;
  }

  /// Alternative method to generate QR code using the qr package directly
  Future<String> _generateQrCodeWithQrPackage(String data, String projectName, int size) async {
    // Get the application documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final qrDir = Directory('${appDir.path}/QR_Codes');

    if (!await qrDir.exists()) {
      await qrDir.create(recursive: true);
    }

    // Create the file path
    final fileName = 'qr_${projectName}_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = '${qrDir.path}/$fileName';

    // Use QrPainter to paint the QR code to an image
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    // Convert to bytes
    final ByteData? byteData = await painter.toImageData(
      size.toDouble(),
    );

    if (byteData == null) {
      throw Exception('Failed to generate QR code image data');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final file = File(filePath);
    await file.writeAsBytes(pngBytes);

    return filePath;
  }

  /// Generates a QR code as a widget for display
  Widget buildQrCodeWidget({
    required String projectId,
    required String projectName,
    int size = 200,
  }) {
    final qrData = 'INSPROJECT:$projectId|$projectName';

    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size.toDouble(),
      gapless: false,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.blue,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }

  /// Validates if a QR code string is in the correct format
  /// Expected format: INSPROJECT:project-id|project-name
  bool isValidProjectQrCode(String qrCodeData) {
    if (!qrCodeData.startsWith('INSPROJECT:')) {
      return false;
    }

    final parts = qrCodeData.substring(11).split('|');
    if (parts.length < 2) {
      return false;
    }

    final projectId = parts[0];
    final projectName = parts[1];

    // Validate that both parts are not empty
    return projectId.isNotEmpty && projectName.isNotEmpty;
  }

  /// Extracts project ID and name from a QR code string
  /// Returns a map with 'id' and 'name' keys, or null if invalid
  Map<String, String>? extractProjectFromQrCode(String qrCodeData) {
    if (!isValidProjectQrCode(qrCodeData)) {
      return null;
    }

    final parts = qrCodeData.substring(11).split('|');
    return {
      'id': parts[0],
      'name': parts[1],
    };
  }
}