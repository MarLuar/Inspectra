import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'inspectra.db');
    print('Database path: $path'); // Debug logging
    return await openDatabase(
      path,
      version: 4, // Incremented version to force schema update
      onCreate: _createTables,
      onUpgrade: _onUpgrade, // Add upgrade handler
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades
    if (oldVersion < 2) {
      // If upgrading from version 1 to 2, recreate tables to ensure proper schema
      await db.execute('DROP TABLE IF EXISTS documents');
      await db.execute('DROP TABLE IF EXISTS projects');
      await _createTables(db, 2);
    }

    if (oldVersion < 3) {
      // If upgrading from version 2 to 3, add location column to projects table
      try {
        await db.execute('ALTER TABLE projects ADD COLUMN location TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding location column: $e');
      }
    }

    if (oldVersion < 4) {
      // If upgrading from version 3 to 4, add qr_code_path column to documents table
      try {
        await db.execute('ALTER TABLE documents ADD COLUMN qr_code_path TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding qr_code_path column: $e');
      }
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // Create projects table
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        qr_code_path TEXT,
        document_count INTEGER DEFAULT 0,
        location TEXT
      )
    ''');

    // Create documents table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        qr_code_path TEXT,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');
  }

  // PROJECT METHODS
  Future<int> insertProject(Project project) async {
    final db = await database;
    return await db.insert(
      'projects',
      project.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Project>> getProjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('projects');

    return List.generate(maps.length, (i) {
      return Project.fromJson(maps[i]);
    });
  }

  Future<Project?> getProjectById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Project.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateProject(Project project) async {
    final db = await database;
    return await db.update(
      'projects',
      project.toJson(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<int> deleteProject(String id) async {
    final db = await database;
    return await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DOCUMENT METHODS
  Future<int> insertDocument(Document document) async {
    final db = await database;
    print('Inserting document into database: ${document.toJson()}');
    final result = await db.insert(
      'documents',
      document.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Document inserted with result: $result');
    return result;
  }

  Future<List<Document>> getDocumentsByProject(String projectId) async {
    final db = await database;
    print('Querying documents for project ID: $projectId');
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'project_id = ?',
      whereArgs: [projectId], // Add whereArgs to properly bind the parameter
      orderBy: 'created_at DESC',
    );
    print('Found ${maps.length} documents in database for project: $projectId');

    return List.generate(maps.length, (i) {
      final document = Document.fromJson(maps[i]);
      print('Loaded document: ${document.name} at ${document.path}');
      return document;
    });
  }

  Future<Document?> getDocumentById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Document.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateDocument(Document document) async {
    final db = await database;
    return await db.update(
      'documents',
      document.toJson(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<int> deleteDocument(String id) async {
    final db = await database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Document>> searchDocuments(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );

    return List.generate(maps.length, (i) {
      return Document.fromJson(maps[i]);
    });
  }

  Future<List<Project>> searchProjects(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );

    return List.generate(maps.length, (i) {
      return Project.fromJson(maps[i]);
    });
  }

  Future close() async => _database?.close();
}