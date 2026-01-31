class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? qrCodePath;
  final int documentCount;
  final String? location; // Added location field
  final String? ownerUserId; // Added owner user ID
  final int isShared; // Added shared flag

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    this.qrCodePath,
    this.documentCount = 0,
    this.location, // Added location parameter
    this.ownerUserId, // Added owner user ID parameter
    this.isShared = 0, // Added shared flag parameter with default value
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'qr_code_path': qrCodePath,
      'document_count': documentCount,
      'location': location, // Added location to JSON
      'owner_user_id': ownerUserId, // Added owner user ID to JSON
      'is_shared': isShared, // Added shared flag to JSON
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      qrCodePath: json['qr_code_path'],
      documentCount: json['document_count'] ?? 0,
      location: json['location'], // Added location from JSON
      ownerUserId: json['owner_user_id'], // Added owner user ID from JSON
      isShared: json['is_shared'] ?? 0, // Added shared flag from JSON
    );
  }

  // Convert to Firebase-compatible map
  Map<String, dynamic> toFirebaseJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'qr_code_path': qrCodePath,
      'document_count': documentCount,
      'location': location,
      'owner_user_id': ownerUserId,
      'is_shared': isShared,
    };
  }

  // Create from Firebase document snapshot
  factory Project.fromFirebaseSnapshot(Map<String, dynamic> data) {
    return Project(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] ?? DateTime.now().millisecondsSinceEpoch),
      qrCodePath: data['qr_code_path'],
      documentCount: data['document_count'] ?? 0,
      location: data['location'],
      ownerUserId: data['owner_user_id'],
      isShared: data['is_shared'] ?? 0,
    );
  }
}

class Document {
  final String id;
  final String projectId;
  final String name;
  final String path;
  final String category; // e.g., 'Blueprints', 'Site_Inspections', 'Reports'
  final DateTime createdAt;
  final String fileType; // 'image' or 'pdf'
  final String? qrCodePath; // Path to the QR code image file
  final String? ownerUserId; // Added owner user ID
  final int isShared; // Added shared flag

  Document({
    required this.id,
    required this.projectId,
    required this.name,
    required this.path,
    required this.category,
    required this.createdAt,
    required this.fileType,
    this.qrCodePath,
    this.ownerUserId, // Added owner user ID parameter
    this.isShared = 0, // Added shared flag parameter with default value
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'path': path,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
      'file_type': fileType,
      'qr_code_path': qrCodePath,
      'owner_user_id': ownerUserId, // Added owner user ID to JSON
      'is_shared': isShared, // Added shared flag to JSON
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      projectId: json['project_id'],
      name: json['name'],
      path: json['path'],
      category: json['category'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      fileType: json['file_type'],
      qrCodePath: json['qr_code_path'],
      ownerUserId: json['owner_user_id'], // Added owner user ID from JSON
      isShared: json['is_shared'] ?? 0, // Added shared flag from JSON
    );
  }

  // Convert to Firebase-compatible map
  Map<String, dynamic> toFirebaseJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'path': path,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
      'file_type': fileType,
      'qr_code_path': qrCodePath,
      'owner_user_id': ownerUserId, // Added owner user ID to JSON
      'is_shared': isShared, // Added shared flag to JSON
    };
  }

  // Create from Firebase document snapshot
  factory Document.fromFirebaseSnapshot(Map<String, dynamic> data) {
    return Document(
      id: data['id'] ?? '',
      projectId: data['project_id'] ?? '',
      name: data['name'] ?? '',
      path: data['path'] ?? '',
      category: data['category'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] ?? DateTime.now().millisecondsSinceEpoch),
      fileType: data['file_type'] ?? '',
      qrCodePath: data['qr_code_path'],
      ownerUserId: data['owner_user_id'], // Added owner user ID from JSON
      isShared: data['is_shared'] ?? 0, // Added shared flag from JSON
    );
  }
}