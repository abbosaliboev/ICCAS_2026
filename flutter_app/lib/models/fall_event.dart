class FallEvent {
  final String id;
  final String? deviceId;
  final String? userId;
  final String timestamp;
  final String category;
  final String? videoPath;
  final String? thumbnailPath;
  final bool isAcknowledged;
  final String? monitoredUserName;

  const FallEvent({
    required this.id,
    this.deviceId,
    this.userId,
    required this.timestamp,
    required this.category,
    this.videoPath,
    this.thumbnailPath,
    required this.isAcknowledged,
    this.monitoredUserName,
  });

  factory FallEvent.fromJson(Map<String, dynamic> j) => FallEvent(
        id: j['id'] ?? '',
        deviceId: j['device_id'],
        userId: j['user_id'],
        timestamp: j['timestamp'] ?? '',
        category: j['category'] ?? 'severe',
        videoPath: j['video_path'],
        thumbnailPath: j['thumbnail_path'],
        isAcknowledged: (j['is_acknowledged'] ?? 0) == 1,
        monitoredUserName: j['monitored_user_name'],
      );

  bool get isSevere => category == 'severe';
  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;
}
