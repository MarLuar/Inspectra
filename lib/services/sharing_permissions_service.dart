import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shared_document_model.dart';

class SharingPermissionsService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sharing_permissions.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create shared_documents table
    await db.execute('''
      CREATE TABLE shared_documents (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        shared_by_user_id TEXT NOT NULL,
        shared_with_user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        access_level TEXT DEFAULT 'view',
        expiration_date INTEGER,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  // Insert a new shared document record
  Future<int> insertSharedDocument(SharedDocument sharedDocument) async {
    final db = await database;
    return await db.insert(
      'shared_documents',
      sharedDocument.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all shares for a specific document
  Future<List<SharedDocument>> getSharesForDocument(String documentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shared_documents',
      where: 'document_id = ? AND is_active = ?',
      whereArgs: [documentId, 1],
    );

    return List.generate(maps.length, (i) {
      return SharedDocument.fromJson(maps[i]);
    });
  }

  // Get all shares initiated by a specific user
  Future<List<SharedDocument>> getSharesByUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shared_documents',
      where: 'shared_by_user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return SharedDocument.fromJson(maps[i]);
    });
  }

  // Get all shares for a specific recipient
  Future<List<SharedDocument>> getSharesForUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shared_documents',
      where: 'shared_with_user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return SharedDocument.fromJson(maps[i]);
    });
  }

  // Update a shared document record
  Future<int> updateSharedDocument(SharedDocument sharedDocument) async {
    final db = await database;
    return await db.update(
      'shared_documents',
      sharedDocument.toJson(),
      where: 'id = ?',
      whereArgs: [sharedDocument.id],
    );
  }

  // Revoke a share (set isActive to false)
  Future<int> revokeShare(String shareId) async {
    final db = await database;
    return await db.update(
      'shared_documents',
      {'is_active': 0}, // Set to inactive
      where: 'id = ?',
      whereArgs: [shareId],
    );
  }

  // Check if a user has access to a specific document
  Future<bool> hasAccess(String documentId, String userId, String requiredAccessLevel) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shared_documents',
      where: 'document_id = ? AND shared_with_user_id = ? AND is_active = ?',
      whereArgs: [documentId, userId, 1],
    );

    if (maps.isEmpty) {
      return false; // No share record found
    }

    final share = SharedDocument.fromJson(maps.first);
    
    // Check access level - 'download' includes 'edit' and 'view', 'edit' includes 'view'
    if (requiredAccessLevel == 'view') {
      return true; // All access levels include view
    } else if (requiredAccessLevel == 'edit') {
      return share.accessLevel == 'edit' || share.accessLevel == 'download';
    } else if (requiredAccessLevel == 'download') {
      return share.accessLevel == 'download';
    }
    
    return false;
  }

  // Clean up expired shares
  Future<void> cleanupExpiredShares() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.update(
      'shared_documents',
      {'is_active': 0}, // Set to inactive
      where: 'expiration_date IS NOT NULL AND expiration_date < ?',
      whereArgs: [now],
    );
  }

  Future close() async => _database?.close();
}