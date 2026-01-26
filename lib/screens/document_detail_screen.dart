import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/project_model.dart';
import '../services/document_conversion_service.dart';
import '../services/project_organization_service.dart';
import '../services/document_sharing_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import 'image_enhancement_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final Document document;

  const DocumentDetailScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share functionality
            },
          ),
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'delete') {
                _confirmDelete(context);
              } else if (result == 'convert_to_pdf') {
                _convertToPdf();
              } else if (result == 'convert_to_doc') {
                _convertToDoc();
              } else if (result == 'share') {
                _shareDocument();
              } else if (result == 'share_link') {
                _shareDocumentLink();
              } else if (result == 'share_with_permissions') {
                _shareWithPermissions();
              } else if (result == 'move') {
                _moveToCategory();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'rename',
                child: Text('Rename'),
              ),
              const PopupMenuItem<String>(
                value: 'move',
                child: Text('Move to Category'),
              ),
              const PopupMenuItem<String>(
                value: 'duplicate',
                child: Text('Duplicate'),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: Text('Share Document'),
              ),
              const PopupMenuItem<String>(
                value: 'share_link',
                child: Text('Share Link'),
              ),
              const PopupMenuItem<String>(
                value: 'share_with_permissions',
                child: Text('Share with Permissions'),
              ),
              if (widget.document.fileType.contains('image'))
                ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'convert_to_pdf',
                    child: Text('Convert to PDF'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'convert_to_doc',
                    child: Text('Convert to Text'),
                  ),
                ],
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document preview
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: _buildDocumentPreview(),
            ),
          ),
          
          // Document info
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project: ${widget.document.projectId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Category: ${widget.document.category}'),
                  const SizedBox(height: 8),
                  Text('Date: ${widget.document.createdAt}'),
                  const SizedBox(height: 8),
                  Text('File: ${widget.document.path.split('/').last}'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.document.fileType.contains('image')
          ? FloatingActionButton(
              onPressed: () {
                // Open image in enhancement screen if it's an image
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageEnhancementScreen(imagePath: widget.document.path),
                  ),
                );
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.tune), // Changed to tune icon for image enhancement
            )
          : null, // Hide FAB for non-image files
    );
  }

  Widget _buildDocumentPreview() {
    final fileName = widget.document.path.toLowerCase();

    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif')) {
      // Image file
      return InteractiveViewer(
        child: Image.file(
          File(widget.document.path),
          fit: BoxFit.contain,
        ),
      );
    } else if (fileName.endsWith('.pdf')) {
      // PDF file
      return PdfPreview(
        build: (context) => _loadPdf(),
        canChangeOrientation: false,
      );
    } else if (fileName.endsWith('.txt') || fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
      // Text-based files (including converted documents)
      return FutureBuilder<String>(
        future: _loadTextFile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading document'));
          } else if (snapshot.hasData) {
            return Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  snapshot.data!,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          } else {
            return const Center(child: Text('Unable to load document'));
          }
        },
      );
    } else {
      // Unsupported file type
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Unsupported file type',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  Future<Uint8List> _loadPdf() async {
    // Load the PDF from the document path
    final file = File(widget.document.path);
    if (await file.exists()) {
      return await file.readAsBytes();
    } else {
      // Return an empty PDF if file doesn't exist
      return Uint8List.fromList([]);
    }
  }

  Future<String> _loadTextFile() async {
    try {
      final file = File(widget.document.path);
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return 'File does not exist';
      }
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  void _convertToPdf() async {
    try {
      final conversionService = DocumentConversionService();
      final fileName = widget.document.path.split('/').last.split('.')[0]; // Get filename without extension

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text("Converting to PDF..."),
              ],
            ),
          );
        },
      );

      // Perform conversion
      final convertedFilePath = await conversionService.convertJpgToPdf(
        widget.document.path,
        fileName,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully converted to PDF: ${convertedFilePath.split('/').last}'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // For now, just show a message - in a real app, you might navigate to the new document
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      // Add the converted document to the project
      final projectService = ProjectOrganizationService();
      final allProjects = await projectService.getAllProjects();
      final project = allProjects.firstWhere((p) => p.id == widget.document.projectId);

      await projectService.addDocumentToProject(
        projectId: project.id,
        projectName: project.name,
        documentPath: convertedFilePath,
        category: widget.document.category,
        documentName: '${fileName}_converted.pdf',
        fileType: 'pdf',
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting to PDF: $e')),
      );
    }
  }

  void _convertToDoc() async {
    try {
      final conversionService = DocumentConversionService();
      final fileName = widget.document.path.split('/').last.split('.')[0]; // Get filename without extension

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Text("Converting to DOC..."),
              ],
            ),
          );
        },
      );

      // Perform conversion - use the new text conversion method
      final convertedFilePath = await conversionService.convertJpgToText(
        widget.document.path,
        fileName,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully converted to text: ${convertedFilePath.split('/').last}'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // For now, just show a message - in a real app, you might navigate to the new document
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      // Add the converted document to the project
      final projectService = ProjectOrganizationService();
      final allProjects = await projectService.getAllProjects();
      final project = allProjects.firstWhere((p) => p.id == widget.document.projectId);

      await projectService.addDocumentToProject(
        projectId: project.id,
        projectName: project.name,
        documentPath: convertedFilePath,
        category: widget.document.category,
        documentName: '${fileName}_converted.txt',
        fileType: 'text',
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting to text: $e')),
      );
    }
  }

  void _shareDocument() async {
    try {
      final sharingService = DocumentSharingService();
      await sharingService.shareDocument(
        widget.document.path,
        subject: 'Shared document: ${widget.document.name}',
        text: 'Check out this document from the InSpectra app',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing document: $e')),
      );
    }
  }

  void _shareDocumentLink() async {
    try {
      final sharingService = DocumentSharingService();
      final link = await sharingService.generateShareableLink(widget.document.path);

      // Show dialog with the link
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Shareable Link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Copy and share this link:'),
                const SizedBox(height: 8),
                SelectableText(
                  link,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  // Copy to clipboard functionality would go here
                  // For now, just close the dialog
                  Navigator.of(context).pop();
                },
                child: const Text('Copy'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating shareable link: $e')),
      );
    }
  }

  void _shareWithPermissions() async {
    // Show dialog to select sharing options
    final TextEditingController emailController = TextEditingController();
    String accessLevel = 'view'; // Default access level

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Share with Permissions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email or Username',
                  hintText: 'Enter recipient email or username',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: accessLevel,
                decoration: const InputDecoration(
                  labelText: 'Access Level',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 16),
                        const SizedBox(width: 8),
                        const Text('View only'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        const SizedBox(width: 8),
                        const Text('View and edit'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 16),
                        const SizedBox(width: 8),
                        const Text('Download'),
                      ],
                    ),
                  ),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    accessLevel = newValue;
                  }
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (emailController.text.isNotEmpty) {
                  Navigator.of(context).pop({
                    'recipient': emailController.text,
                    'accessLevel': accessLevel,
                  });
                }
              },
              child: const Text('Share'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final sharingService = DocumentSharingService();

        // In a real implementation, we would use the actual document ID
        // For now, we'll use the document path as an identifier
        final shareLink = await sharingService.shareDocumentWithPermissions(
          documentId: widget.document.id, // Use the document's actual ID
          sharedByUserId: 'current_user_id', // Would come from auth system
          sharedWithUserId: result['recipient'],
          accessLevel: result['accessLevel'],
        );

        // Show success message with the share link
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Document shared successfully!'),
            action: SnackBarAction(
              label: 'Copy Link',
              onPressed: () {
                // Copy link to clipboard
              },
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing document: $e')),
        );
      }
    }
  }

  Future<void> _moveToCategory() async {
    String? selectedCategory;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: const Text('Move to Category'),
              content: SizedBox(
                width: double.maxFinite, // Allows the dialog to be scrollable if needed
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
                          Navigator.of(context).pop(selectedCategory); // Confirm selection
                        }
                      : null,
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedCategory != null) {
      try {
        // Update the document's category in the database
        final updatedDocument = Document(
          id: widget.document.id,
          projectId: widget.document.projectId,
          name: widget.document.name,
          path: widget.document.path,
          category: selectedCategory!,
          createdAt: widget.document.createdAt,
          fileType: widget.document.fileType,
        );

        // Update in local database
        final dbService = DatabaseService();
        await dbService.updateDocument(updatedDocument);

        // Update in Firebase if authenticated
        final cloudSyncService = CloudSyncService();
        if (cloudSyncService.isAuthenticated) {
          await cloudSyncService.firebaseService.syncDocument(updatedDocument);
        }

        // Update the widget's document
        setState(() {
          // Refresh the UI to reflect the new category
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document moved to $selectedCategory')),
        );

        // Pop the screen and push again to refresh the category view
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(document: updatedDocument),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving document: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Document'),
          content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Perform deletion
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}