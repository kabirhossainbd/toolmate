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

  VideoModel({
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.savePath,
    required this.downloadDate,
  });
}
