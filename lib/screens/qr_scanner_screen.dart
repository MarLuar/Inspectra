import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/project_organization_service.dart';
import '../services/qr_code_generator_service.dart';
import '../models/project_model.dart';
import 'project_detail_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (!_isProcessing) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        _processScannedCode(barcode.rawValue);
                        break; // Process only the first barcode detected
                      }
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      color: Theme.of(context).colorScheme.primary,
                      icon: ValueListenableBuilder(
                        valueListenable: cameraController,
                        builder: (context, value, child) {
                          switch (value.torchState) {
                            case TorchState.off:
                              return const Icon(Icons.flash_off);
                            case TorchState.on:
                              return const Icon(Icons.flash_on);
                            case TorchState.auto:
                              return const Icon(Icons.flash_auto);
                            case TorchState.unavailable:
                              return const Icon(Icons.flash_off);
                          }
                        },
                      ),
                      onPressed: () => cameraController.toggleTorch(),
                    ),
                    IconButton(
                      color: Theme.of(context).colorScheme.primary,
                      icon: const Icon(Icons.cameraswitch),
                      onPressed: () => cameraController.switchCamera(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Opening project...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _processScannedCode(String? rawValue) async {
    if (rawValue == null) return;

    // Use the QR code generator service to validate the QR code format
    final qrService = QrCodeGeneratorService();

    // Check if the scanned code is in the expected format: INSPROJECT:project-id|project-name
    if (qrService.isValidProjectQrCode(rawValue)) {
      final projectData = qrService.extractProjectFromQrCode(rawValue);
      if (projectData != null) {
        final projectId = projectData['id'] ?? '';
        final projectName = projectData['name'] ?? '';

        await _openProject(projectId, projectName);
      } else {
        _showErrorDialog('Invalid QR code format. Could not extract project information.');
      }
    } else {
      _showErrorDialog('This QR code does not contain project information.\n\nLook for QR codes labeled "INSPROJECT:"');
    }
  }

  Future<void> _openProject(String projectId, String projectName) async {
    if (_isProcessing) return; // Prevent multiple simultaneous attempts

    setState(() {
      _isProcessing = true;
    });

    try {
      final projectService = ProjectOrganizationService();
      final allProjects = await projectService.getAllProjects();

      // Find the project with the matching ID
      Project? project;
      if (projectId.isNotEmpty) {
        project = allProjects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => Project(id: '', name: '', createdAt: DateTime.now()),
        );
      }

      // If project not found by ID or ID is empty, try to find by name
      if ((project?.id.isEmpty ?? true) && projectName.isNotEmpty) {
        project = allProjects.firstWhere(
          (p) => p.name == projectName,
          orElse: () => Project(id: '', name: '', createdAt: DateTime.now()),
        );
      }

      if (project != null && project.id.isNotEmpty) {
        // Stop the camera before navigating
        await cameraController.stop();

        // Navigate to the project detail screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(projectName: project!.name),
          ),
        );
      } else {
        setState(() {
          _isProcessing = false;
        });
        _showErrorDialog('Project "$projectName" not found in your list. Please make sure the project exists.');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Error opening project: $e');
    }
  }

  void _showErrorDialog(String message) {
    // Stop processing state if there's an error
    if (_isProcessing) {
      setState(() {
        _isProcessing = false;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        title: const Text('QR Scan Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Resume camera after error
              cameraController.start();
            },
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }
}