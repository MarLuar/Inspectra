import 'package:flutter/material.dart';
import 'dart:io';
import '../services/project_organization_service.dart';
import '../services/qr_code_generator_service.dart';
import '../services/document_sharing_service.dart';
import '../models/project_model.dart';
import 'category_detail_screen.dart';
import 'document_detail_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String? projectName;

  const ProjectDetailScreen({Key? key, this.projectName}) : super(key: key);

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectOrganizationService _projectService = ProjectOrganizationService();
  final QrCodeGeneratorService _qrService = QrCodeGeneratorService();
  
  // Removed _documents list since we're now using FutureBuilder to load documents
  bool _isLoading = true;
  String? _qrCodePath;

  Project? _currentProject;

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
  }

  Future<void> _loadProjectDetails() async {
    try {
      final projectName = widget.projectName;
      if (projectName == null) {
        throw Exception('Project name is required');
      }

      print('Loading project details for: $projectName');

      // First get the project to retrieve its ID
      final allProjects = await _projectService.getAllProjects();
      print('Total projects found: ${allProjects.length}');
      for (var proj in allProjects) {
        print('Project: ${proj.name}, ID: ${proj.id}');
      }

      final project = allProjects.firstWhere((p) => p.name == projectName);
      _currentProject = project;

      print('Found project: ${project.name}, ID: ${project.id}');

      setState(() {
        _isLoading = false;
      });

      print('Project loaded successfully');
    } catch (e) {
      print('Error loading project details: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading project details: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing operations when the widget is disposed
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    // Format to show only HH:MM
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName ?? 'Folder Detail', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('View QR Code', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Rename Folder', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_location',
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Add Location', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Folder', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteProject();
              } else if (value == 'view_qr') {
                _viewQrCode();
              } else if (value == 'rename') {
                _renameFolder();
              } else if (value == 'add_location') {
                _addLocation();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProjectDetails, // Allow pull-to-refresh
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project header with QR code
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    // QR Code - Load and display the actual QR code if available
                    FutureBuilder<Project?>(
                      future: _getProject(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.qrCodePath != null) {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(snapshot.data!.qrCodePath!),
                                fit: BoxFit.contain, // Changed from cover to contain to show full image
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.qr_code,
                              size: 80, // Increased size
                              color: Colors.blue,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.projectName ?? 'Project',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<Project?>(
                            future: _getProject(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Text(
                                  'Created: ${_formatDateTime(snapshot.data!.createdAt)}',
                                  style: const TextStyle(color: Colors.grey),
                                );
                              } else {
                                return const Text(
                                  'Created: Loading...',
                                  style: TextStyle(color: Colors.grey),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<Project?>(
                            future: _getProject(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.location != null && snapshot.data!.location!.isNotEmpty) {
                                return Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Location: ${snapshot.data!.location}',
                                        style: const TextStyle(color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return const Text(
                                  'Location: Not set',
                                  style: TextStyle(color: Colors.grey),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<Document>>(
                            future: _projectService.getDocumentsForProject(_currentProject!.id),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.length ?? 0;
                              return Text(
                                'Documents: $count',
                                style: const TextStyle(color: Colors.grey),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Categories section
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Category cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildCategoryCard('Blueprints', Icons.description, Colors.blue),
                    _buildCategoryCard('Site Inspections', Icons.location_on, Colors.green),
                    _buildCategoryCard('Reports', Icons.article, Colors.orange),
                    _buildCategoryCard('Photos', Icons.photo_camera, Colors.purple),
                    _buildCategoryCard('Safety Documents', Icons.security, Colors.red),
                    _buildCategoryCard('Progress Reports', Icons.bar_chart, Colors.teal),
                  ],
                ),
              ),

              // Documents section
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Recent Documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : FutureBuilder<List<Document>>(
                      future: _projectService.getDocumentsForProject(_currentProject!.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final documents = snapshot.data ?? [];

                        if (documents.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No documents in this project yet.'),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: documents.length,
                          itemBuilder: (context, index) {
                            final document = documents[index];
                            final fileName = document.path.split('/').last;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: ListTile(
                                leading: _getFileIcon(document.path), // Show appropriate icon based on file type
                                title: Text(document.name), // Use document name instead of filename
                                subtitle: Text('Added: ${_formatDateTime(document.createdAt)}'),
                                trailing: PopupMenuButton(
                                  icon: const Icon(Icons.more_vert),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'share',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.share, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Share'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'share_link',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.link, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('Share Link'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'share_with_permissions',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.privacy_tip, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Share with Permissions'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    if (value == 'share') {
                                      _shareDocument(document);
                                    } else if (value == 'share_link') {
                                      _shareDocumentLink(document);
                                    } else if (value == 'share_with_permissions') {
                                      _shareDocumentWithPermissions(document);
                                    }
                                  },
                                ),
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
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getFileIcon(String filePath) {
    final fileName = filePath.toLowerCase();
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif')) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (fileName.endsWith('.pdf')) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        _navigateToCategory(title);
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Project?> _getProject() async {
    if (_currentProject != null) {
      return _currentProject;
    }

    try {
      final allProjects = await _projectService.getAllProjects();
      return allProjects.firstWhere((p) => p.name == widget.projectName);
    } catch (e) {
      return null;
    }
  }

  void _navigateToCategory(String category) {
    // Navigate to a category screen showing documents in that category
    final projectName = widget.projectName;
    if (projectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project name is missing')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(
          projectName: projectName,
          category: category,
        ),
      ),
    );
  }

  void _viewQrCode() async {
    try {
      final project = await _getProject();
      if (project != null && project.qrCodePath != null) {
        // Show the QR code in a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Project QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Image.file(
                      File(project.qrCodePath!),
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Project: ${project.name}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Close', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code not available for this project')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error displaying QR code: $e')),
      );
    }
  }

  void _renameFolder() async {
    final TextEditingController controller = TextEditingController();
    controller.text = widget.projectName ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rename Folder', style: TextStyle(fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new folder name"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: Text('Rename', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Get the project ID first
        final allProjects = await _projectService.getAllProjects();
        final project = allProjects.firstWhere((p) => p.name == widget.projectName);

        // Rename the project in the database
        final updatedProject = Project(
          id: project.id,
          name: result,
          createdAt: project.createdAt,
          qrCodePath: project.qrCodePath,
          documentCount: project.documentCount,
        );

        await _projectService.updateProject(updatedProject);

        // Also rename the actual folder on the file system
        await _renameProjectFolderOnFileSystem(widget.projectName!, result);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder renamed to "$result"')),
        );

        // Navigate back to the folder list to refresh the UI
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming folder: $e')),
        );
      }
    }
  }

  /// Renames the actual project folder on the file system
  Future<void> _renameProjectFolderOnFileSystem(String oldName, String newName) async {
    try {
      // Get the projects directory
      final projectsDir = await _projectService.getProjectsDirectory();
      final oldPath = '${projectsDir.path}/$oldName';
      final newPath = '${projectsDir.path}/$newName';

      // Check if old folder exists
      final oldDir = Directory(oldPath);
      if (await oldDir.exists()) {
        // Rename the directory
        await oldDir.rename(newPath);
      }
    } catch (e) {
      print('Error renaming folder on file system: $e');
      rethrow;
    }
  }

  void _addLocation() async {
    // Get the current project
    final allProjects = await _projectService.getAllProjects();
    final project = allProjects.firstWhere((p) => p.name == widget.projectName);

    // Show dialog to enter location
    final TextEditingController controller = TextEditingController();
    controller.text = project.location ?? ''; // Pre-fill with existing location if any

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Location', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "Enter location (e.g., address, coordinates)",
                  labelText: "Location",
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "You can enter an address, landmark, or GPS coordinates",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: Text('Save', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        // Update the project with the new location
        final updatedProject = Project(
          id: project.id,
          name: project.name,
          createdAt: project.createdAt,
          qrCodePath: project.qrCodePath,
          documentCount: project.documentCount,
          location: result.isEmpty ? null : result, // Store null if empty
        );

        await _projectService.updateProject(updatedProject);

        // Refresh the UI
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location updated: $result')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e')),
        );
      }
    }
  }

  void _shareDocument(Document document) async {
    try {
      final sharingService = DocumentSharingService();
      await sharingService.shareDocument(
        document.path,
        subject: 'Shared document: ${document.name}',
        text: 'Check out this document from the InSpectra app',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing document: $e')),
      );
    }
  }

  void _shareDocumentLink(Document document) async {
    try {
      final sharingService = DocumentSharingService();
      final link = await sharingService.generateShareableLink(document.path);

      // Show dialog with the link
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Shareable Link', style: TextStyle(fontWeight: FontWeight.w600)),
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
                child: Text('Close', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              TextButton(
                onPressed: () async {
                  // Copy to clipboard functionality would go here
                  // For now, just close the dialog
                  Navigator.of(context).pop();
                },
                child: Text('Copy', style: TextStyle(fontWeight: FontWeight.w500)),
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

  void _shareDocumentWithPermissions(Document document) async {
    // Show dialog to select sharing options
    final TextEditingController emailController = TextEditingController();
    String accessLevel = 'view'; // Default access level

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Share with Permissions', style: TextStyle(fontWeight: FontWeight.w600)),
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
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
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
              child: Text('Share', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        final sharingService = DocumentSharingService();

        // In a real implementation, we would use the actual document ID
        final shareLink = await sharingService.shareDocumentWithPermissions(
          documentId: document.id, // Use the document's actual ID
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

  void _confirmDeleteProject() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Folder', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete "${widget.projectName}"?\n\nThis will permanently delete all documents in this folder.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel
              },
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final projectName = widget.projectName;
                  if (projectName == null) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Folder name is missing')),
                    );
                    return;
                  }

                  // Get the project ID first
                  final allProjects = await _projectService.getAllProjects();
                  final project = allProjects.firstWhere((p) => p.name == projectName);

                  // Delete the project
                  await _projectService.deleteProject(project.id, projectName);

                  // Show success message and navigate back
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Folder deleted successfully')),
                  );

                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to projects list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting folder: $e')),
                  );
                  Navigator.of(context).pop(); // Close dialog
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );
  }
}