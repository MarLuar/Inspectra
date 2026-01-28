import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import '../models/project_model.dart';

class DocumentQrCodeService {
  /// Generates a QR code for a document and saves it to a file
  Future<String> generateDocumentQrCode({
    required Document document,
    int size = 200,
  }) async {
    // Create the QR code data string in the format expected by the scanner
    // Format: INSDOC:document-id|document-name|project-id
    final qrData = 'INSDOC:${document.id}|${document.name}|${document.projectId}';

    // Generate QR code using the qr_flutter package directly
    final qrCodePath = await _generateQrCodeWithQrPackage(qrData, document.name, size);

    return qrCodePath;
  }

  /// Alternative method to generate QR code using the qr package directly
  Future<String> _generateQrCodeWithQrPackage(String data, String documentName, int size) async {
    // Get the application documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final qrDir = Directory('${appDir.path}/QR_Codes');

    if (!await qrDir.exists()) {
      await qrDir.create(recursive: true);
    }

    // Create the file path
    final fileName = 'qr_doc_${documentName.replaceAll(RegExp(r'[^\w\s]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
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
    required Document document,
    int size = 200,
  }) {
    final qrData = 'INSDOC:${document.id}|${document.name}|${document.projectId}';

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

  /// Validates if a QR code string is in the correct format for documents
  /// Expected format: INSDOC:document-id|document-name|project-id
  bool isValidDocumentQrCode(String qrCodeData) {
    if (!qrCodeData.startsWith('INSDOC:')) {
      return false;
    }

    final parts = qrCodeData.substring(7).split('|');
    if (parts.length < 3) {
      return false;
    }

    final documentId = parts[0];
    final documentName = parts[1];
    final projectId = parts[2];

    // Validate that all parts are not empty
    return documentId.isNotEmpty && documentName.isNotEmpty && projectId.isNotEmpty;
  }

  /// Extracts document ID, name, and project ID from a QR code string
  /// Returns a map with 'id', 'name', and 'project_id' keys, or null if invalid
  Map<String, String>? extractDocumentFromQrCode(String qrCodeData) {
    if (!isValidDocumentQrCode(qrCodeData)) {
      return null;
    }

    final parts = qrCodeData.substring(7).split('|');
    return {
      'id': parts[0],
      'name': parts[1],
      'project_id': parts[2],
    };
  }
}