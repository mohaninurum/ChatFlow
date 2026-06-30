import 'package:hive_flutter/hive_flutter.dart';

class HiveStorageService {
  static const String _settingsBox = 'settingsBox';
  static const String _favoritesBox = 'favoritesBox';

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_favoritesBox);
  }

  static Box get settings => Hive.box(_settingsBox);
  static Box get favorites => Hive.box(_favoritesBox);
}
