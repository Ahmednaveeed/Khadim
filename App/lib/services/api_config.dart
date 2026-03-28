import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';      // Chrome on same PC
    } else {
      return 'http://192.168.100.30:8000'; // Physical mobile device
    }
  }
}