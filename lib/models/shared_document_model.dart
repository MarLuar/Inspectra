class SharedDocument {
  final String id;
  final String documentId;
  final String sharedByUserId;
  final String sharedWithUserId; // Could be email or user ID
  final DateTime createdAt;
  final String accessLevel; // 'view', 'edit', 'download'
  final DateTime? expirationDate;
  final bool isActive;

  SharedDocument({
    required this.id,
    required this.documentId,
    required this.sharedByUserId,
    required this.sharedWithUserId,
    required this.createdAt,
    this.accessLevel = 'view',
    this.expirationDate,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'shared_by_user_id': sharedByUserId,
      'shared_with_user_id': sharedWithUserId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'access_level': accessLevel,
      'expiration_date': expirationDate?.millisecondsSinceEpoch,
      'is_active': isActive,
    };
  }

  factory SharedDocument.fromJson(Map<String, dynamic> json) {
    return SharedDocument(
      id: json['id'],
      documentId: json['document_id'],
      sharedByUserId: json['shared_by_user_id'],
      sharedWithUserId: json['shared_with_user_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      accessLevel: json['access_level'] ?? 'view',
      expirationDate: json['expiration_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['expiration_date']) 
          : null,
      isActive: json['is_active'] ?? true,
    );
  }
}