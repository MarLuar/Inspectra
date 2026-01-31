import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import 'database_service.dart';
import 'qr_code_generator_service.dart';
import 'cloud_sync_service.dart';
import 'shared_access_service.dart';

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

    // Generate QR code for the project - but don't store it in Supabase yet
    // since the user might not be fully authenticated at this point
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
      ownerUserId: _cloudSyncService.firebaseService.currentUserId, // Set owner user ID
      isShared: 0, // Initially not shared
    );

    await _dbService.insertProject(project);

    // Sync to cloud if user is authenticated
    if (_cloudSyncService.isAuthenticated) {
      try {
        await _cloudSyncService.syncProjectToCloud(project);

        // Also upload the QR code as a file to Supabase storage with the requested naming convention
        if (qrCodePath != null && qrCodePath.isNotEmpty) {
          final supabaseStorage = _cloudSyncService.firebaseService.supabaseStorage;
          await supabaseStorage.uploadProjectQrCode(
            qrCodePath,
            projectName,
            projectId,
            _cloudSyncService.firebaseService.currentUserId,
          );
        }
      } catch (e) {
        // If cloud sync fails, log the error but continue
        print('Error syncing project to cloud: $e');
      }
    }

    return projectDir.path;
  }

  /// Gets a list of all projects from the database
  Future<List<Project>> getAllProjects() async {
    try {
      if (_cloudSyncService.isAuthenticated) {
        try {
          // If authenticated, get projects accessible to the current user
          final userId = _cloudSyncService.firebaseService.currentUserId!;
          final sharedAccessService = SharedAccessService();
          return await sharedAccessService.getAccessibleProjects();
        } catch (e) {
          // If there's an error with the authenticated query (likely schema issues), fall back to all projects
          print('Error getting accessible projects for user, falling back to all projects: $e');
          return await _dbService.getProjects();
        }
      } else {
        // If not authenticated, return all projects (for demo purposes)
        return await _dbService.getProjects();
      }
    } catch (e) {
      print('Error in getAllProjects: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow; // Re-throw the exception so it can be caught by the UI layer
    }
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
        ownerUserId: _cloudSyncService.firebaseService.currentUserId, // Set owner user ID
        isShared: 0, // Initially not shared
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
          location: project.location, // Preserve location
          ownerUserId: project.ownerUserId, // Preserve owner user ID
          isShared: project.isShared, // Preserve shared status
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

      // Sync document to cloud if authenticated
      if (_cloudSyncService.isAuthenticated) {
        try {
          // Add to Supabase documents table
          await _syncDocumentToSupabase(document, documentPath);
          await _cloudSyncService.syncDocumentToCloud(document);

          // Now that we know the user is authenticated and the document sync worked,
          // let's also store the QR code for this project if it hasn't been stored yet
          await _storeProjectQrCode(projectId, projectName);
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

  /// Helper method to store project QR code in Supabase
  Future<void> _storeProjectQrCode(String projectId, String projectName) async {
    try {
      // Generate the QR code data
      final qrCodeData = 'INSPROJECT:$projectId|$projectName';

      // Use the Supabase client directly from the public getter
      final supabaseClient = _cloudSyncService.firebaseService.supabaseStorage.client;

      // Check if there are any documents for this project in Supabase
      final existingDocs = await supabaseClient.from('documents')
          .select('id')
          .eq('project_id', projectId)
          .limit(1);

      if (existingDocs.isNotEmpty) {
        // If documents exist, update them with the QR code data
        await supabaseClient.from('documents')
            .update({'qr_code': qrCodeData})
            .eq('project_id', projectId);

        print('QR code stored in Supabase for project: $projectName (ID: $projectId)');
      } else {
        // If no documents exist yet, insert a placeholder record with QR code data
        final data = {
          'name': 'QR_Code_Placeholder_$projectName',
          'project_id': projectId,
          'category': 'QR_Codes',
          'storage_path': '',
          'qr_code': qrCodeData,
          'file_size': 0,
          'mime_type': 'text/plain',
        };

        // Only add owner_id if it's a valid UUID format
        final userId = _cloudSyncService.firebaseService.currentUserId;
        if (userId != null) {
          // Check if the user ID is a valid UUID format
          final uuidRegex = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            caseSensitive: false,
          );

          if (uuidRegex.hasMatch(userId)) {
            data['owner_id'] = userId;
          }
        }

        await supabaseClient.from('documents').insert(data);

        print('QR code stored in Supabase for project: $projectName (ID: $projectId) using placeholder record');
      }
    } on PostgrestException catch (e) {
      print('PostgrestException storing project QR code in Supabase: $e');
      print('Error details - Code: ${e.code}, Message: ${e.message}, Hint: ${e.hint}');

      // If the qr_code column doesn't exist or RLS policy prevents access, try to store in a separate table
      await _storeQrCodeInSeparateTable(projectId, projectName);
    } catch (e) {
      print('Error storing project QR code in Supabase: $e');
      print('Error type: ${e.runtimeType}');

      // If the qr_code column doesn't exist, try to store in a separate table
      await _storeQrCodeInSeparateTable(projectId, projectName);
    }
  }

  /// Helper method to store project QR code in a separate table if the main documents table doesn't have a qr_code column
  Future<void> _storeQrCodeInSeparateTable(String projectId, String projectName) async {
    print('Fallback QR code storage called for project: $projectName (ID: $projectId)');
    print('This indicates that the primary storage method failed');

    try {
      // Generate the QR code data again
      final qrCodeData = 'INSPROJECT:$projectId|$projectName';

      // Try to insert the QR code data into a dedicated qr_codes table
      final supabaseClient = _cloudSyncService.firebaseService.supabaseStorage.client;
      await supabaseClient.from('qr_codes').insert({
        'project_id': projectId,
        'project_name': projectName,
        'qr_code_data': qrCodeData,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('QR code stored in separate qr_codes table for project: $projectName (ID: $projectId)');
    } catch (e) {
      print('Error storing QR code in separate table: $e');

      // If the qr_codes table doesn't exist, log the QR code data so it's not lost
      print('QR Code Data for $projectName (ID: $projectId): INSPROJECT:$projectId|$projectName');
    }
  }

  /// Helper method to sync document to Supabase documents table
  Future<void> _syncDocumentToSupabase(Document document, String localPath) async {
    try {
      // Use the SupabaseStorageService from FirebaseSyncService
      final supabaseStorage = _cloudSyncService.firebaseService.supabaseStorage;

      // Get the project name to use in the storage path
      final project = await _dbService.getProjectById(document.projectId);
      final projectName = project?.name;

      // Upload file to Supabase storage using the existing service
      final fileName = localPath.split('/').last;

      // Use the uploadFile method which already handles both file upload and metadata insertion
      await supabaseStorage.uploadFile(
        localPath,
        fileName,
        userId: document.ownerUserId, // Use the document's ownerUserId instead of current user ID
        projectId: document.projectId,
        projectName: projectName,
        category: document.category,
        documentName: document.name,
        qrCodeData: document.qrCodePath != null && document.qrCodePath!.isNotEmpty
            ? 'INSDOC:${document.id}|${document.name}' // Create a document-specific QR code reference
            : null,
      );

      print('Document synced to Supabase: ${document.name}');
    } catch (e) {
      print('Error syncing document to Supabase: $e');
      // Don't rethrow here as this is just a sync operation that shouldn't break the main flow
    }
  }

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// Updates a document's QR code path in the database
  Future<void> updateDocumentQrCode(String documentId, String qrCodePath) async {
    final document = await _dbService.getDocumentById(documentId);
    if (document != null) {
      final updatedDocument = Document(
        id: document.id,
        projectId: document.projectId,
        name: document.name,
        path: document.path,
        category: document.category,
        createdAt: document.createdAt,
        fileType: document.fileType,
        qrCodePath: qrCodePath,
      );

      await _dbService.updateDocument(updatedDocument);

      // Sync to cloud if authenticated
      if (_cloudSyncService.isAuthenticated) {
        try {
          await _cloudSyncService.syncDocumentToCloud(updatedDocument);
        } catch (e) {
          print('Error syncing updated document to cloud: $e');
        }
      }
    }
  }

  /// Gets a document by ID
  Future<Document?> getDocumentById(String documentId) async {
    return await _dbService.getDocumentById(documentId);
  }

  /// Gets all documents in a specific project from the database
  Future<List<Document>> getDocumentsForProject(String projectId) async {
    print('Getting documents for project ID: $projectId');
    if (_cloudSyncService.isAuthenticated) {
      // If authenticated, get documents accessible to the current user
      final userId = _cloudSyncService.firebaseService.currentUserId!;
      final documents = await _dbService.getDocumentsForUserInProject(projectId, userId);
      print('Retrieved ${documents.length} documents accessible to user for project: $projectId');
      return documents;
    } else {
      // If not authenticated, return all documents in the project (for demo purposes)
      final documents = await _dbService.getDocumentsByProject(projectId);
      print('Retrieved ${documents.length} documents from database for project: $projectId');
      return documents;
    }
  }

  /// Deletes a document and updates the project's document count
  Future<bool> deleteDocument(String documentId) async {
    try {
      // Get the document first to find out which project it belongs to
      final document = await _dbService.getDocumentById(documentId);
      if (document == null) {
        return false;
      }

      // Delete the file from Supabase storage first (if it exists in cloud)
      if (_cloudSyncService.isAuthenticated) {
        try {
          // Try to delete from Supabase storage using the local path to determine the storage path
          final project = await _dbService.getProjectById(document.projectId);
          String? projectName = project?.name;

          // Recreate the storage path format used during upload
          String fileName = document.path.split('/').last;
          String uniqueFileName = fileName;

          if (document.projectId != null && document.category != null) {
            final fileExtension = fileName.split('.').last;
            final fileNameWithoutExt = (document.name != null && document.name.isNotEmpty)
                ? document.name
                : fileName.replaceAll(RegExp(r'\.[^.]*$'), '');

            String projectIdentifier = projectName ?? document.projectId!;
            uniqueFileName = '$projectIdentifier/${document.category}/$fileNameWithoutExt.$fileExtension';
          }

          // Attempt to delete from Supabase storage
          final supabaseStorage = _cloudSyncService.firebaseService.supabaseStorage;
          await supabaseStorage.deleteFile(uniqueFileName);
        } catch (e) {
          print('Error deleting file from Supabase storage: $e');
        }
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
          location: project.location, // Preserve location
          ownerUserId: project.ownerUserId, // Preserve owner user ID
          isShared: project.isShared, // Preserve shared status
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

    // First, delete all associated documents and their files from Supabase storage
    final documents = await _dbService.getDocumentsByProject(projectId);
    for (final document in documents) {
      // Delete the document from Supabase storage
      if (_cloudSyncService.isAuthenticated) {
        try {
          // Recreate the storage path format used during upload
          String fileName = document.path.split('/').last;
          final fileExtension = fileName.split('.').last;
          final fileNameWithoutExt = (document.name != null && document.name.isNotEmpty)
              ? document.name
              : fileName.replaceAll(RegExp(r'\.[^.]*$'), '');

          String projectIdentifier = projectName;
          String uniqueFileName = '$projectIdentifier/${document.category}/$fileNameWithoutExt.$fileExtension';

          // Attempt to delete from Supabase storage
          final supabaseStorage = _cloudSyncService.firebaseService.supabaseStorage;
          await supabaseStorage.deleteFile(uniqueFileName);
        } catch (e) {
          print('Error deleting file from Supabase storage for document ${document.id}: $e');
        }
      }
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

    // Delete project from cloud if authenticated
    if (_cloudSyncService.isAuthenticated) {
      try {
        await _cloudSyncService.firebaseService.deleteProject(projectId);
      } catch (e) {
        print('Error deleting project from cloud: $e');
      }
    }

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