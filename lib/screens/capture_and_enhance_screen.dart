import 'dart:io';
import 'package:flutter/material.dart';
import 'document_scanner_screen.dart';
import 'image_enhancement_screen.dart';
import 'pdf_generation_screen.dart';
import '../services/document_scanner_service.dart';

class CaptureAndEnhanceScreen extends StatefulWidget {
  const CaptureAndEnhanceScreen({Key? key}) : super(key: key);

  @override
  State<CaptureAndEnhanceScreen> createState() => _CaptureAndEnhanceScreenState();
}

class _CaptureAndEnhanceScreenState extends State<CaptureAndEnhanceScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  String? _capturedImagePath;

  Future<void> _captureImage() async {
    final String? capturedPath = await _scannerService.scanDocument();
    if (capturedPath != null) {
      setState(() {
        _capturedImagePath = capturedPath;
      });
    }
  }

  Future<void> _selectFromGallery() async {
    final String? selectedPath = await _scannerService.pickFromGallery();
    if (selectedPath != null) {
      setState(() {
        _capturedImagePath = selectedPath;
      });
    }
  }

  Future<void> _enhanceImage() async {
    if (_capturedImagePath != null) {
      final String? enhancedPath = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEnhancementScreen(imagePath: _capturedImagePath!),
        ),
      );
      
      if (enhancedPath != null) {
        setState(() {
          _capturedImagePath = enhancedPath;
        });
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_capturedImagePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfGenerationScreen(imagePath: _capturedImagePath!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture & Enhance'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _capturedImagePath != null
                ? InteractiveViewer(
                    child: Image.file(
                      File(_capturedImagePath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.document_scanner,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Capture or select an image to begin',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_capturedImagePath != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _enhanceImage,
                        icon: const Icon(Icons.tune),
                        label: const Text('Enhance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _generatePdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('To PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _capturedImagePath = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _capturedImagePath == null
          ? FloatingActionButton.extended(
              onPressed: _captureImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Document'),
              backgroundColor: Colors.blue,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _capturedImagePath == null
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _captureImage,
                    icon: const Icon(Icons.camera_alt, color: Colors.blue),
                    label: const Text('Scan', style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton.icon(
                    onPressed: _selectFromGallery,
                    icon: const Icon(Icons.photo_library, color: Colors.blue),
                    label: const Text('Gallery', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}