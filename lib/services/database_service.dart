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
    try {
      String path = join(await getDatabasesPath(), 'inspectra.db');
      print('Database path: $path'); // Debug logging
      return await openDatabase(
        path,
        version: 5, // Incremented version to force schema update
        onCreate: _createTables,
        onUpgrade: _onUpgrade, // Add upgrade handler
      );
    } catch (e) {
      print('Error initializing database: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
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

    if (oldVersion < 5) {
      // If upgrading from version 4 to 5, add owner_user_id and is_shared columns to projects and documents tables
      // Check if columns already exist before adding them
      var columns = await db.rawQuery('PRAGMA table_info(projects)');
      bool hasOwnerUserId = columns.any((column) => column['name'] == 'owner_user_id');
      bool hasIsShared = columns.any((column) => column['name'] == 'is_shared');

      if (!hasOwnerUserId) {
        try {
          await db.execute('ALTER TABLE projects ADD COLUMN owner_user_id TEXT');
        } catch (e) {
          print('Error adding owner_user_id column to projects: $e');
        }
      }

      if (!hasIsShared) {
        try {
          await db.execute('ALTER TABLE projects ADD COLUMN is_shared INTEGER DEFAULT 0');
        } catch (e) {
          print('Error adding is_shared column to projects: $e');
        }
      }

      // Check documents table for the same columns
      columns = await db.rawQuery('PRAGMA table_info(documents)');
      hasOwnerUserId = columns.any((column) => column['name'] == 'owner_user_id');
      hasIsShared = columns.any((column) => column['name'] == 'is_shared');

      if (!hasOwnerUserId) {
        try {
          await db.execute('ALTER TABLE documents ADD COLUMN owner_user_id TEXT');
        } catch (e) {
          print('Error adding owner_user_id column to documents: $e');
        }
      }

      if (!hasIsShared) {
        try {
          await db.execute('ALTER TABLE documents ADD COLUMN is_shared INTEGER DEFAULT 0');
        } catch (e) {
          print('Error adding is_shared column to documents: $e');
        }
      }

      // Check if shared_access table exists
      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='shared_access'");
      if (tables.isEmpty) {
        // Create the shared_access table
        try {
          await db.execute('''
            CREATE TABLE shared_access (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              resource_id TEXT NOT NULL,
              resource_type TEXT NOT NULL, -- 'project' or 'document'
              grantor_user_id TEXT NOT NULL, -- user who granted access
              grantee_user_id TEXT NOT NULL, -- user who received access
              access_level TEXT DEFAULT 'view',
              created_at INTEGER NOT NULL,
              expires_at INTEGER,
              is_active INTEGER DEFAULT 1
            )
          ''');
        } catch (e) {
          // Table might already exist, ignore error
          print('Error creating shared_access table: $e');
        }
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
        location TEXT,
        owner_user_id TEXT,
        is_shared INTEGER DEFAULT 0
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
        owner_user_id TEXT,
        is_shared INTEGER DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');

    // Create a table for tracking shared access
    await db.execute('''
      CREATE TABLE shared_access (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        resource_id TEXT NOT NULL,
        resource_type TEXT NOT NULL, -- 'project' or 'document'
        grantor_user_id TEXT NOT NULL, -- user who granted access
        grantee_user_id TEXT NOT NULL, -- user who received access
        access_level TEXT DEFAULT 'view',
        created_at INTEGER NOT NULL,
        expires_at INTEGER,
        is_active INTEGER DEFAULT 1
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
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('projects');

      return List.generate(maps.length, (i) {
        return Project.fromJson(maps[i]);
      });
    } catch (e) {
      print('Error in getProjects: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Get projects accessible to a specific user (owned + shared)
  Future<List<Project>> getProjectsForUser(String userId) async {
    final db = await database;

    try {
      // Query for projects owned by the user OR shared with the user
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT p.* FROM projects p
        WHERE p.owner_user_id = ? OR p.is_shared = 1
        UNION
        SELECT DISTINCT p.* FROM projects p
        JOIN shared_access sa ON p.id = sa.resource_id
        WHERE sa.resource_type = 'project'
        AND sa.grantee_user_id = ?
        AND sa.is_active = 1
      ''', [userId, userId]);

      return List.generate(maps.length, (i) {
        return Project.fromJson(maps[i]);
      });
    } catch (e) {
      print('Error in getProjectsForUser: $e');
      // Fallback: return all projects if the query fails due to schema issues
      return await getProjects();
    }
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

  // Get documents accessible to a specific user for a specific project
  Future<List<Document>> getDocumentsForUserInProject(String projectId, String userId) async {
    final db = await database;
    print('Querying documents for project ID: $projectId and user ID: $userId');

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT d.* FROM documents d
      WHERE d.project_id = ? AND (d.owner_user_id = ? OR d.is_shared = 1)
      UNION
      SELECT DISTINCT d.* FROM documents d
      JOIN shared_access sa ON d.id = sa.resource_id
      WHERE sa.resource_type = 'document'
      AND sa.grantee_user_id = ?
      AND sa.is_active = 1
      AND d.project_id = ?
    ''', [projectId, userId, userId, projectId]);

    print('Found ${maps.length} documents accessible to user in project: $projectId');

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

  // Add a shared access record
  Future<int> addSharedAccess({
    required String resourceId,
    required String resourceType, // 'project' or 'document'
    required String grantorUserId,
    required String granteeUserId,
    String accessLevel = 'view',
    int? expiresAt,
  }) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return await db.insert(
      'shared_access',
      {
        'resource_id': resourceId,
        'resource_type': resourceType,
        'grantor_user_id': grantorUserId,
        'grantee_user_id': granteeUserId,
        'access_level': accessLevel,
        'created_at': timestamp,
        'expires_at': expiresAt,
        'is_active': 1,
      },
    );
  }

  // Get all resources shared with a specific user
  Future<List<Map<String, dynamic>>> getResourcesSharedWithUser(String userId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'shared_access',
      where: 'grantee_user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
    );

    return maps;
  }

  // Check if a user has access to a specific resource
  Future<bool> hasResourceAccess({
    required String resourceId,
    required String userId,
    required String resourceType, // 'project' or 'document'
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'shared_access',
      where: 'resource_id = ? AND grantee_user_id = ? AND resource_type = ? AND is_active = ?',
      whereArgs: [resourceId, userId, resourceType, 1],
    );

    return maps.isNotEmpty;
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