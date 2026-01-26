import 'package:flutter/material.dart';
import '../services/project_organization_service.dart';
import '../models/project_model.dart';
import '../services/document_scanner_service.dart';
import 'document_detail_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String projectName;
  final String category;

  const CategoryDetailScreen({
    Key? key,
    required this.projectName,
    required this.category,
  }) : super(key: key);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final ProjectOrganizationService _projectService = ProjectOrganizationService();
  final DocumentScannerService _scannerService = DocumentScannerService();
  List<Document> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryDocuments();
  }

  Future<void> _loadCategoryDocuments() async {
    try {
      // Get the project ID first
      final allProjects = await _projectService.getAllProjects();
      final project = allProjects.firstWhere((p) => p.name == widget.projectName);

      // Get all documents for the project
      final allDocuments = await _projectService.getDocumentsForProject(project.id);

      // Filter documents by category
      final categoryDocuments = allDocuments.where(
        (doc) => doc.category.toLowerCase().replaceAll(' ', '_') == widget.category.toLowerCase().replaceAll(' ', '_')
      ).toList();

      setState(() {
        _documents = categoryDocuments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading category documents: $e')),
      );
    }
  }

  Future<void> _scanDocument() async {
    final String? scannedPath = await _scannerService.scanDocument();
    if (scannedPath != null) {
      await _saveDocument(scannedPath);
    }
  }

  Future<void> _pickFromGallery() async {
    final String? pickedPath = await _scannerService.pickFromGallery();
    if (pickedPath != null) {
      await _saveDocument(pickedPath);
    }
  }

  Future<void> _saveDocument(String documentPath) async {
    try {
      // Get the project ID first
      final allProjects = await _projectService.getAllProjects();
      final project = allProjects.firstWhere((p) => p.name == widget.projectName);

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
        // Add the document to the project in the current category
        await _projectService.addDocumentToProject(
          projectId: project.id,
          projectName: widget.projectName,
          documentPath: documentPath,
          category: widget.category,
          documentName: documentName,
          fileType: 'image',
        );

        // Refresh the document list
        _loadCategoryDocuments();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document saved to ${widget.category}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} - ${widget.projectName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showUploadOptionsDialog();
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(
                  child: Text(
                    'No documents in this category yet.\nTap the + button to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCategoryDocuments,
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final document = _documents[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: ListTile(
                          leading: _getFileIcon(document.fileType),
                          title: Text(document.name),
                          subtitle: Text('Added: ${document.createdAt.toString().split(' ')[0]}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to document detail screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DocumentDetailScreen(document: document),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _getFileIcon(String fileType) {
    if (fileType.toLowerCase().contains('image') || fileType.toLowerCase().contains('jpg') || fileType.toLowerCase().contains('jpeg') || fileType.toLowerCase().contains('png')) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (fileType.toLowerCase().contains('pdf')) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  void _showUploadOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Scan Document'),
                onTap: () {
                  Navigator.of(context).pop();
                  _scanDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Upload from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromGallery();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}