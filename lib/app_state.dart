// lib/app_state.dart
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String _userType = 'doctor'; // Default value

  String get userType => _userType;

  set userType(String value) {
    if (_userType != value) {
      _userType = value;
      notifyListeners(); // This is crucial for updating the UI
    }
  }
}
