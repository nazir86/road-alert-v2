/// Signalement conservé sur le téléphone avant toute synchronisation.
class RoadReport {
  final String id;
  final String? userId;
  final double latitude, longitude, gpsAccuracy;
  final String type, severity, comment, photoPath, localStatus, createdAt;
  final int retryCount, durationSeconds;
  final String? lastError, syncedAt;

  const RoadReport(
      {required this.id,
      this.userId,
      required this.latitude,
      required this.longitude,
      required this.gpsAccuracy,
      required this.type,
      required this.severity,
      required this.comment,
      required this.photoPath,
      required this.localStatus,
      required this.createdAt,
      required this.durationSeconds,
      this.retryCount = 0,
      this.lastError,
      this.syncedAt});

  factory RoadReport.fromMap(Map<String, dynamic> m) => RoadReport(
        id: m['id'] as String,
        userId: m['user_id'] as String?,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        gpsAccuracy: (m['gps_accuracy'] as num).toDouble(),
        type: m['type'] as String,
        severity: m['severity'] as String,
        comment: m['comment'] as String? ?? '',
        photoPath: m['photo_path'] as String,
        localStatus: m['status_local'] as String,
        createdAt: m['created_at'] as String,
        durationSeconds: (m['duration_seconds'] as num).toInt(),
        retryCount: (m['retry_count'] as num?)?.toInt() ?? 0,
        lastError: m['last_error'] as String?,
        syncedAt: m['synced_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy': gpsAccuracy,
        'type': type,
        'severity': severity,
        'comment': comment,
        'photo_path': photoPath,
        'status_local': localStatus,
        'created_at': createdAt,
        'duration_seconds': durationSeconds,
        'retry_count': retryCount,
        'last_error': lastError,
        'synced_at': syncedAt,
      };

  RoadReport withStatus(String status,
          {String? error, int? attempts, String? remoteTime, String? owner}) =>
      RoadReport(
          id: id,
          userId: owner ?? userId,
          latitude: latitude,
          longitude: longitude,
          gpsAccuracy: gpsAccuracy,
          type: type,
          severity: severity,
          comment: comment,
          photoPath: photoPath,
          localStatus: status,
          createdAt: createdAt,
          durationSeconds: durationSeconds,
          retryCount: attempts ?? retryCount,
          lastError: error,
          syncedAt: remoteTime ?? syncedAt);
}
