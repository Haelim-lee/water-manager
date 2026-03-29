import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaterEntry {
  final int amountMl;
  final DateTime timestamp;

  WaterEntry({required this.amountMl, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'amountMl': amountMl,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        amountMl: json['amountMl'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class WaterService extends ChangeNotifier {
  static const int defaultGoalMl = 2000;
  static const String _keyEntries = 'water_entries';
  static const String _keyLastDate = 'last_date';
  static const String _keyGoal = 'daily_goal_ml';

  List<WaterEntry> _entries = [];
  int _dailyGoalMl = defaultGoalMl;
  SharedPreferences? _prefs;
  bool _initialized = false;

  List<WaterEntry> get entries => List.unmodifiable(_entries);
  int get dailyGoalMl => _dailyGoalMl;

  int get totalIntakeMl => _entries.fold(0, (sum, e) => sum + e.amountMl);

  double get progressFraction =>
      (totalIntakeMl / _dailyGoalMl).clamp(0.0, 1.0);

  int get remainingMl => (_dailyGoalMl - totalIntakeMl).clamp(0, _dailyGoalMl);

  bool get goalReached => totalIntakeMl >= _dailyGoalMl;

  bool get initialized => _initialized;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _dailyGoalMl = _prefs!.getInt(_keyGoal) ?? defaultGoalMl;
    await _checkAndResetForNewDay();
    await _loadEntries();
    _initialized = true;
    notifyListeners();
  }

  Future<void> setGoal(int goalMl) async {
    if (goalMl < 100) return;
    _dailyGoalMl = goalMl;
    await _prefs!.setInt(_keyGoal, goalMl);
    notifyListeners();
  }

  Future<void> _checkAndResetForNewDay() async {
    final prefs = _prefs!;
    final today = _dateKey(DateTime.now());
    final lastDate = prefs.getString(_keyLastDate);
    if (lastDate != today) {
      await prefs.remove(_keyEntries);
      await prefs.setString(_keyLastDate, today);
    }
  }

  Future<void> _loadEntries() async {
    final prefs = _prefs!;
    final raw = prefs.getString(_keyEntries);
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _entries = decoded
          .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _entries = [];
    }
  }

  Future<void> _saveEntries() async {
    final prefs = _prefs!;
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_keyEntries, encoded);
  }

  Future<void> addWater(int amountMl) async {
    await _checkAndResetForNewDay();
    final entry = WaterEntry(
      amountMl: amountMl,
      timestamp: DateTime.now(),
    );
    _entries.add(entry);
    await _saveEntries();
    notifyListeners();
  }

  Future<void> removeEntry(int index) async {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    await _saveEntries();
    notifyListeners();
  }

  Future<void> resetToday() async {
    _entries.clear();
    await _saveEntries();
    notifyListeners();
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
