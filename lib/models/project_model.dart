class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? qrCodePath;
  final int documentCount;
  final String? location; // Added location field

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    this.qrCodePath,
    this.documentCount = 0,
    this.location, // Added location parameter
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'qr_code_path': qrCodePath,
      'document_count': documentCount,
      'location': location, // Added location to JSON
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

  Document({
    required this.id,
    required this.projectId,
    required this.name,
    required this.path,
    required this.category,
    required this.createdAt,
    required this.fileType,
    this.qrCodePath,
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
    );
  }
}