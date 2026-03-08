import 'package:hive/hive.dart';

part 'user_profile_model.g.dart';

@HiveType(typeId: 2)
class UserProfileModel extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String bio;

  @HiveField(2)
  String? imagePath;

  UserProfileModel({
    this.name = '',
    this.bio = '',
    this.imagePath,
  });
}
