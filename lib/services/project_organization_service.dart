import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/project_model.dart';
import 'database_service.dart';
import 'qr_code_generator_service.dart';
import 'cloud_sync_service.dart';

class ProjectOrganizationService {
  static const String _projectsDirName = 'Projects';
  final DatabaseService _dbService = DatabaseService();
  final CloudSyncService _cloudSyncService = CloudSyncService();

  /// Requests storage permissions
  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    } else {
      final status = await Permission.storage.status;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return false;
    }
  }

  /// Gets the main projects directory
  Future<Directory> getProjectsDirectory() async {
    // Request storage permission before creating directories
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission not granted');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory('${appDir.path}/$_projectsDirName');

    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }

    return projectsDir;
  }

  /// Creates the main projects directory
  Future<Directory> _getProjectsDirectory() async {
    return await getProjectsDirectory(); // Delegate to public method
  }

  /// Creates a new project with the specified name
  Future<String> createProject(String projectName, {String? location}) async {
    // Request storage permission before creating project
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission not granted');
    }

    final projectsDir = await _getProjectsDirectory();
    final projectDir = Directory('${projectsDir.path}/$projectName');

    if (await projectDir.exists()) {
      throw Exception('Project with this name already exists');
    }

    await projectDir.create(recursive: true);

    // Create subdirectories for organizing documents
    await Directory('${projectDir.path}/Blueprints').create(recursive: true);
    await Directory('${projectDir.path}/Site_Inspections').create(recursive: true);
    await Directory('${projectDir.path}/Reports').create(recursive: true);
    await Directory('${projectDir.path}/Photos').create(recursive: true);
    await Directory('${projectDir.path}/Safety_Documents').create(recursive: true);
    await Directory('${projectDir.path}/Progress_Reports').create(recursive: true);

    // Generate a unique ID for the project
    final projectId = generateProjectId();

    // Generate QR code for the project
    final qrCodeGenerator = QrCodeGeneratorService();
    final qrCodePath = await qrCodeGenerator.generateProjectQrCode(
      projectId: projectId,
      projectName: projectName,
    );

    // Create project in database
    final project = Project(
      id: projectId,
      name: projectName,
      createdAt: DateTime.now(),
      qrCodePath: qrCodePath,
      location: location, // Added location
    );

    await _dbService.insertProject(project);

    // Sync to cloud if user is authenticated
    if (_cloudSyncService.isAuthenticated) {
      try {
        await _cloudSyncService.syncProjectToCloud(project);
      } catch (e) {
        // If cloud sync fails, log the error but continue
        print('Error syncing project to cloud: $e');
      }
    }

    return projectDir.path;
  }

  /// Gets a list of all projects from the database
  Future<List<Project>> getAllProjects() async {
    return await _dbService.getProjects();
  }

  /// Gets the path for a specific project
  Future<String?> getProjectPath(String projectName) async {
    final projectsDir = await _getProjectsDirectory();
    final projectDir = Directory('${projectsDir.path}/$projectName');

    if (await projectDir.exists()) {
      return projectDir.path;
    }

    return null;
  }

  /// Adds a document to a specific project and category
  Future<String> addDocumentToProject({
    required String projectId,
    required String projectName,
    required String documentPath,
    required String category, // e.g., 'Blueprints', 'Site_Inspections'
    required String documentName,
    required String fileType,
  }) async {
    try {
      print('Attempting to add document to project: $projectId, name: $projectName');

      // Request storage permission before adding document
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission not granted');
      }

      final projectPath = await getProjectPath(projectName);

      if (projectPath == null) {
        throw Exception('Project does not exist: $projectName');
      }

      print('Project path found: $projectPath');

      // Determine destination directory based on category
      final destinationDir = Directory('$projectPath/$category');

      if (!await destinationDir.exists()) {
        // Create the category directory if it doesn't exist
        print('Creating category directory: $destinationDir');
        await destinationDir.create(recursive: true);
      }

      // Copy the document to the project directory
      final fileName = documentPath.split('/').last;
      final destinationPath = '${destinationDir.path}/$fileName';

      print('Copying document from $documentPath to $destinationPath');

      final sourceFile = File(documentPath);

      // Check if source file exists before copying
      if (!await sourceFile.exists()) {
        throw Exception('Source document does not exist: $documentPath');
      }

      final destinationFile = await sourceFile.copy(destinationPath);

      // Verify the file was copied successfully
      if (!await destinationFile.exists()) {
        throw Exception('Failed to copy document to: $destinationPath');
      }

      print('File copied successfully to: $destinationPath');

      // Create document record in database
      final document = Document(
        id: generateProjectId(),
        projectId: projectId,
        name: documentName,
        path: destinationPath,
        category: category,
        createdAt: DateTime.now(),
        fileType: fileType,
      );

      print('Attempting to insert document into database: ${document.toJson()}');
      await _dbService.insertDocument(document);
      print('Document inserted into database successfully');

      // Update the project's document count
      final project = await _dbService.getProjectById(projectId);
      if (project != null) {
        print('Updating project document count. Old count: ${project.documentCount}');
        final updatedProject = Project(
          id: project.id,
          name: project.name,
          createdAt: project.createdAt,
          qrCodePath: project.qrCodePath,
          documentCount: project.documentCount + 1,
        );
        await _dbService.updateProject(updatedProject);
        print('Project document count updated successfully');

        // Sync updated project to cloud if authenticated
        if (_cloudSyncService.isAuthenticated) {
          try {
            await _cloudSyncService.syncProjectToCloud(updatedProject);
          } catch (e) {
            print('Error syncing updated project to cloud: $e');
          }
        }
      }

      // Create document record in database
      final newDocument = Document(
        id: generateProjectId(),
        projectId: projectId,
        name: documentName,
        path: destinationPath,
        category: category,
        createdAt: DateTime.now(),
        fileType: fileType,
      );

      print('Attempting to insert document into database: ${newDocument.toJson()}');
      await _dbService.insertDocument(newDocument);
      print('Document inserted into database successfully');

      // Sync document to cloud if authenticated
      if (_cloudSyncService.isAuthenticated) {
        try {
          await _cloudSyncService.syncDocumentToCloud(newDocument);
        } catch (e) {
          print('Error syncing document to cloud: $e');
        }
      }

      return destinationFile.path;
    } catch (e) {
      print('Error adding document to project: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Gets all documents in a specific project from the database
  Future<List<Document>> getDocumentsForProject(String projectId) async {
    print('Getting documents for project ID: $projectId');
    final documents = await _dbService.getDocumentsByProject(projectId);
    print('Retrieved ${documents.length} documents from database for project: $projectId');
    return documents;
  }

  /// Deletes a document and updates the project's document count
  Future<bool> deleteDocument(String documentId) async {
    try {
      // Get the document first to find out which project it belongs to
      final document = await _dbService.getDocumentById(documentId);
      if (document == null) {
        return false;
      }

      // Delete the document from the database
      await _dbService.deleteDocument(documentId);

      // Delete the file from the file system
      final file = File(document.path);
      if (await file.exists()) {
        await file.delete();
      }

      // Update the project's document count
      final project = await _dbService.getProjectById(document.projectId);
      if (project != null) {
        final updatedProject = Project(
          id: project.id,
          name: project.name,
          createdAt: project.createdAt,
          qrCodePath: project.qrCodePath,
          documentCount: project.documentCount > 0 ? project.documentCount - 1 : 0,
        );
        await _dbService.updateProject(updatedProject);

        // Sync updated project to cloud if authenticated
        if (_cloudSyncService.isAuthenticated) {
          try {
            await _cloudSyncService.syncProjectToCloud(updatedProject);
          } catch (e) {
            print('Error syncing updated project to cloud: $e');
          }
        }
      }

      // Delete document from cloud if authenticated
      if (_cloudSyncService.isAuthenticated) {
        try {
          await _cloudSyncService.firebaseService.deleteDocument(documentId);
        } catch (e) {
          print('Error deleting document from cloud: $e');
        }
      }

      return true;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  /// Deletes a project and all its contents
  Future<bool> deleteProject(String projectId, String projectName) async {
    // Request storage permission before deleting project
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission not granted');
    }

    // Delete from database first
    await _dbService.deleteProject(projectId);

    // Then delete from file system
    final projectPath = await getProjectPath(projectName);

    if (projectPath == null) {
      return false;
    }

    final projectDir = Directory(projectPath);
    await projectDir.delete(recursive: true);

    return true;
  }

  /// Updates an existing project
  Future<void> updateProject(Project project) async {
    await _dbService.updateProject(project);
  }

  /// Generates a unique ID for a project
  String generateProjectId() {
    return const Uuid().v4();
  }
}