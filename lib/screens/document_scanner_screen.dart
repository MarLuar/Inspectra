import 'dart:io';
import 'package:flutter/material.dart';
import '../services/document_scanner_service.dart';
import '../services/project_organization_service.dart';

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({Key? key}) : super(key: key);

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  String? _scannedImagePath;

  Future<void> _scanDocument() async {
    final String? scannedPath = await _scannerService.scanDocument();
    if (scannedPath != null) {
      setState(() {
        _scannedImagePath = scannedPath;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final String? pickedPath = await _scannerService.pickFromGallery();
    if (pickedPath != null) {
      setState(() {
        _scannedImagePath = pickedPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_scannedImagePath != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareScannedImage(),
              tooltip: 'Share Scanned Image',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _scannedImagePath != null
                ? InteractiveViewer(
                    child: Image.file(
                      File(_scannedImagePath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        'Scan or select a document',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _scanDocument,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                if (_scannedImagePath != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _saveScannedImageToProject(),
                        icon: const Icon(Icons.save),
                        label: const Text('Save to Project'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _resetScan(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareScannedImage() {
    // Placeholder for sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing functionality would be implemented here')),
    );
  }

  Future<void> _saveScannedImageToProject() async {
    if (_scannedImagePath == null) return;

    try {
      // Get all projects to let user select one
      final projectService = ProjectOrganizationService();
      final projects = await projectService.getAllProjects();

      if (projects.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No projects available. Please create a project first.')),
          );
        }
        return;
      }

      // Show dialog to select a project
      final selectedProject = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Project'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ListTile(
                    title: Text(project.name),
                    subtitle: Text('Created: ${project.createdAt}'),
                    onTap: () {
                      Navigator.of(context).pop(project.id);
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      if (selectedProject != null) {
        // Ask for document name
        final TextEditingController controller = TextEditingController();
        final documentName = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Document Name'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "Enter document name"),
                autofocus: true,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(controller.text.trim());
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );

        if (documentName != null && documentName.isNotEmpty) {
          // Show category selection dialog
          String? selectedCategory;
          await showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, setState) {
                  return AlertDialog(
                    title: const Text('Select Category'),
                    content: SizedBox(
                      width: double.maxFinite, // Max width for the dialog
                      child: SingleChildScrollView(  // Make the content scrollable
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<String>(
                              title: const Text('Blueprints'),
                              value: 'Blueprints',
                              groupValue: selectedCategory,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Site Inspections'),
                              value: 'Site Inspections',
                              groupValue: selectedCategory,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Reports'),
                              value: 'Reports',
                              groupValue: selectedCategory,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Photos'),
                              value: 'Photos',
                              groupValue: selectedCategory,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Safety Documents'),
                              value: 'Safety Documents',
                              groupValue: selectedCategory,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Progress Reports'),
                              value: 'Progress Reports',
                              groupValue: selectedCategory,
                              onChanged: (String? value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Cancel
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: selectedCategory != null
                            ? () {
                                Navigator.of(context).pop(); // Confirm selection
                              }
                            : null,
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
            },
          );

          if (selectedCategory != null) {
            // Find the selected project name
            final projectName = projects.firstWhere((p) => p.id == selectedProject).name;

            // Add the document to the project
            await projectService.addDocumentToProject(
              projectId: selectedProject,
              projectName: projectName,
              documentPath: _scannedImagePath!,
              category: selectedCategory!, // Safe to use ! since we checked for null above
              documentName: documentName,
              fileType: 'image',
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved to project: $projectName')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving to project: $e')),
        );
      }
    }
  }

  void _resetScan() {
    setState(() {
      _scannedImagePath = null;
    });
  }
}