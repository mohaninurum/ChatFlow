import 'package:hive_flutter/hive_flutter.dart';

class HiveStorageService {
  static const String _settingsBox = 'settingsBox';
  static const String _favoritesBox = 'favoritesBox';
  static const String _historyBox = 'historyBox';
  static const String _templatesBox = 'templatesBox';
  static const String _deletedMessagesBox = 'deletedMessagesBox';

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_historyBox);
    await Hive.openBox(_deletedMessagesBox);
    final templates = await Hive.openBox(_templatesBox);
    
    // Seed default message templates if empty
    if (templates.isEmpty) {
      await templates.put('1', {
        'id': '1',
        'title': 'Quick Response',
        'message': "Hello! Thanks for reaching out. I'll get back to you shortly.",
        'category': 'Quick Replies',
      });
      await templates.put('2', {
        'id': '2',
        'title': 'Busy / In a Meeting',
        'message': "I'm currently in a meeting. Will call you as soon as I'm free.",
        'category': 'Personal',
      });
      await templates.put('3', {
        'id': '3',
        'title': 'Driving',
        'message': "I'm driving right now. Please leave a message, will reply later.",
        'category': 'Personal',
      });
      await templates.put('4', {
        'id': '4',
        'title': 'Address / Location Request',
        'message': "Please share your current location or full address.",
        'category': 'Business',
      });
      await templates.put('5', {
        'id': '5',
        'title': 'Payment Confirmation',
        'message': "Payment received with thanks! We have processed your request.",
        'category': 'Business',
      });
    }
  }

  static Box get settings => Hive.box(_settingsBox);
  static Box get favorites => Hive.box(_favoritesBox);
  static Box get history => Hive.box(_historyBox);
  static Box get templates => Hive.box(_templatesBox);
  static Box get deletedMessages => Hive.box(_deletedMessagesBox);
}
