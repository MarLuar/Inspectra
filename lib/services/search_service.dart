import 'package:path_provider/path_provider.dart';
import '../models/project_model.dart';
import 'database_service.dart';

class SearchService {
  final DatabaseService _dbService = DatabaseService();

  /// Searches for projects by name
  Future<List<Project>> searchProjects(String query) async {
    if (query.isEmpty) return [];

    return await _dbService.searchProjects(query);
  }

  /// Searches for documents by name within a specific project
  Future<List<Document>> searchDocumentsInProject({
    required String projectId,
    required String query,
  }) async {
    if (query.isEmpty) return [];

    final allDocs = await _dbService.getDocumentsByProject(projectId);
    return allDocs.where((doc) =>
        doc.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  /// Searches for documents by name across all projects
  Future<List<Document>> searchDocumentsGlobally(String query) async {
    if (query.isEmpty) return [];

    return await _dbService.searchDocuments(query);
  }
}