import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

class QrCodeGeneratorService {
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