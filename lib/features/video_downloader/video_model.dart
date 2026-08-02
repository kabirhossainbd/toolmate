import 'package:hive/hive.dart';

part 'video_model.g.dart';

@HiveType(typeId: 0)
class VideoModel extends HiveObject {
  @HiveField(0)
  final String url;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String thumbnailUrl;

  @HiveField(3)
  final String savePath;

  @HiveField(4)
  final DateTime downloadDate;

  /// `video`, `image`, or `gif`
  @HiveField(5, defaultValue: 'video')
  final String mediaType;

  @HiveField(6, defaultValue: '')
  final String platform;

  VideoModel({
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.savePath,
    required this.downloadDate,
    this.mediaType = 'video',
    this.platform = '',
  });

  bool get isImage => mediaType == 'image' || mediaType == 'gif';
}
