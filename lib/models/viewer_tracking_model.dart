class ViewerTracking {
  final String id;
  final String projectId;
  final String viewerUserId;
  final String viewerName;
  final DateTime viewTime;
  final String? deviceInfo;

  ViewerTracking({
    required this.id,
    required this.projectId,
    required this.viewerUserId,
    required this.viewerName,
    required this.viewTime,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'viewer_user_id': viewerUserId,
      'viewer_name': viewerName,
      'view_time': viewTime.millisecondsSinceEpoch,
      'device_info': deviceInfo,
    };
  }

  factory ViewerTracking.fromJson(Map<String, dynamic> json) {
    return ViewerTracking(
      id: json['id'],
      projectId: json['project_id'],
      viewerUserId: json['viewer_user_id'],
      viewerName: json['viewer_name'],
      viewTime: DateTime.fromMillisecondsSinceEpoch(json['view_time']),
      deviceInfo: json['device_info'],
    );
  }

  // Convert to Firebase-compatible map
  Map<String, dynamic> toFirebaseJson() {
    return {
      'id': id,
      'project_id': projectId,
      'viewer_user_id': viewerUserId,
      'viewer_name': viewerName,
      'view_time': viewTime.millisecondsSinceEpoch,
      'device_info': deviceInfo,
    };
  }

  // Create from Firebase document snapshot
  factory ViewerTracking.fromFirebaseSnapshot(Map<String, dynamic> data) {
    return ViewerTracking(
      id: data['id'] ?? '',
      projectId: data['project_id'] ?? '',
      viewerUserId: data['viewer_user_id'] ?? '',
      viewerName: data['viewer_name'] ?? 'Unknown User',
      viewTime: DateTime.fromMillisecondsSinceEpoch(data['view_time'] ?? DateTime.now().millisecondsSinceEpoch),
      deviceInfo: data['device_info'],
    );
  }
}