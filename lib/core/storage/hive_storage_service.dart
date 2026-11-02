import 'package:hive_flutter/hive_flutter.dart';

class HiveStorageService {
  static const String _settingsBox = 'settingsBox';
  static const String _favoritesBox = 'favoritesBox';
  static const String _historyBox = 'historyBox';
  static const String _templatesBox = 'templatesBox';
  static const String _deletedMessagesBox = 'deletedMessagesBox';
  static const String _remindersBox = 'remindersBox';
  static const String _clipboardBox = 'clipboardBox';
  static const String _vaultBox = 'vaultBox';
  static const String _statusDownloadsBox = 'statusDownloadsBox';

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_historyBox);
    await Hive.openBox(_deletedMessagesBox);
    await Hive.openBox(_remindersBox);
    await Hive.openBox(_clipboardBox);
    await Hive.openBox(_vaultBox);
    await Hive.openBox(_statusDownloadsBox);
    final templates = await Hive.openBox(_templatesBox);

    // Seed default message templates if empty
    if (templates.isEmpty) {
      final defaultTemplates = [
        {
          'id': '1',
          'title': 'Order Confirmation',
          'message': 'Hello {name}, your order #{order_id} of ₹{amount} has been successfully received and is being processed!',
          'category': 'Business',
          'isFavorite': true,
          'useCount': 0,
        },
        {
          'id': '2',
          'title': 'Payment Request',
          'message': 'Hi {name}, friendly reminder to settle the invoice #{order_id} for ₹{amount}. Thank you!',
          'category': 'Business',
          'isFavorite': false,
          'useCount': 0,
        },
        {
          'id': '3',
          'title': 'Support Ticket Follow-up',
          'message': 'Hi {name}, our support team has resolved issue #{order_id}. Please reply if you require further assistance.',
          'category': 'Customer Support',
          'isFavorite': true,
          'useCount': 0,
        },
        {
          'id': '4',
          'title': 'Welcome Customer',
          'message': 'Welcome to our service, {name}! Let us know if you need any assistance getting started.',
          'category': 'Customer Support',
          'isFavorite': false,
          'useCount': 0,
        },
        {
          'id': '5',
          'title': 'Driving Mode',
          'message': "I am driving right now. I'll get back to you as soon as I arrive safely.",
          'category': 'Driving',
          'isFavorite': true,
          'useCount': 0,
        },
        {
          'id': '6',
          'title': 'In a Meeting',
          'message': "I'm currently in a meeting with a client. Will call you back shortly.",
          'category': 'Personal',
          'isFavorite': false,
          'useCount': 0,
        },
        {
          'id': '7',
          'title': 'Family Catch-up',
          'message': 'Hey {name}! Just checking in on you. Hope everything is going great.',
          'category': 'Personal',
          'isFavorite': false,
          'useCount': 0,
        },
        {
          'id': '8',
          'title': 'Quick Acknowledgement',
          'message': 'Received with thanks! Reviewing this and will update you shortly.',
          'category': 'Business',
          'isFavorite': false,
          'useCount': 0,
        },
      ];

      for (var t in defaultTemplates) {
        await templates.put(t['id'], t);
      }
    }
  }

  static Box get settings => Hive.box(_settingsBox);
  static Box get favorites => Hive.box(_favoritesBox);
  static Box get history => Hive.box(_historyBox);
  static Box get templates => Hive.box(_templatesBox);
  static Box get deletedMessages => Hive.box(_deletedMessagesBox);
  static Box get reminders => Hive.box(_remindersBox);
  static Box get clipboard => Hive.box(_clipboardBox);
  static Box get vault => Hive.box(_vaultBox);
  static Box get statusDownloads => Hive.box(_statusDownloadsBox);

  // Helper to add activity log for dashboard
  static Future<void> logDirectChat({
    required String phone,
    required String message,
    required bool isBusiness,
  }) async {
    await history.add({
      'phone': phone,
      'message': message,
      'isBusiness': isBusiness,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'direct_chat',
    });
  }

  // Favorite contacts
  static List<String> getFavoriteContacts() {
    final list = favorites.get('favorite_contacts', defaultValue: <dynamic>[]) as List;
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> toggleFavoriteContact(String phone) async {
    final current = getFavoriteContacts();
    if (current.contains(phone)) {
      current.remove(phone);
    } else {
      current.add(phone);
    }
    await favorites.put('favorite_contacts', current);
  }

  // Favorite statuses
  static List<String> getFavoriteStatuses() {
    final list = favorites.get('favorite_statuses', defaultValue: <dynamic>[]) as List;
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> toggleFavoriteStatus(String path) async {
    final current = getFavoriteStatuses();
    if (current.contains(path)) {
      current.remove(path);
    } else {
      current.add(path);
    }
    await favorites.put('favorite_statuses', current);
  }
}
