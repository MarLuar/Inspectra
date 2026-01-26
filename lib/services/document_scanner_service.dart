import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DocumentScannerService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<bool> _requestStoragePermission() async {
    // Request storage permissions
    if (await Permission.storage.request().isGranted) {
      return true;
    } else {
      // Handle denied permission
      final status = await Permission.storage.status;
      if (status.isPermanentlyDenied) {
        // Open app settings if permission is permanently denied
        await openAppSettings();
        return false;
      }
      return false;
    }
  }

  Future<String?> scanDocument() async {
    try {
      // Request storage permission before scanning
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint('Storage permission not granted');
        return null;
      }

      // Configure the scanner options
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg, // Output document format
        mode: ScannerMode.full,             // Full scanner with all features
        pageLimit: 1,                       // Limit number of pages scanned
        isGalleryImport: true,              // Enable importing from photo gallery
      );

      // Create document scanner instance
      final documentScanner = DocumentScanner(options: options);

      // Start the document scanning process
      final result = await documentScanner.scanDocument();

      if (result != null && result.images.isNotEmpty) {
        // The scanner returns a list of image paths
        // For now, we'll use the first one
        if (result.images.isNotEmpty && result.images.first.isNotEmpty) {
          // Save the scanned document to app directory
          final savedPath = await _saveScannedImage(result.images.first);

          // Release resources
          documentScanner.close();

          return savedPath;
        }
      }

      // Release resources even if no images were found
      documentScanner.close();

      return null;
    } catch (e) {
      debugPrint('Error scanning document with ML Kit: $e');
      // Fallback to camera if ML Kit fails
      return _captureWithCamera();
    }
  }

  /// Fallback method to capture image with camera
  Future<String?> _captureWithCamera() async {
    try {
      final XFile? capturedImage = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (capturedImage != null) {
        return _saveScannedImage(capturedImage.path);
      }

      return null;
    } catch (e) {
      debugPrint('Error capturing image with camera: $e');
      return null;
    }
  }

  Future<String> _saveScannedImage(String imagePath) async {
    // Get the application documents directory
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'scanned_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String newPath = '${appDir.path}/$fileName';

    // Copy the image to our app directory
    final sourceFile = File(imagePath);
    final newFile = await sourceFile.copy(newPath);

    return newFile.path;
  }

  Future<String?> pickFromGallery() async {
    try {
      // Request storage permission before picking from gallery
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint('Storage permission not granted');
        return null;
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        return _saveScannedImage(pickedFile.path);
      }

      return null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }
}