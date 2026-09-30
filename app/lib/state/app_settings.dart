import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';
import 'project_controller.dart' show defaultWireColors;

/// إعدادات التطبيق العامة + نظام التقدّم التعليمي (XP / المستوى / الأوسمة)
/// محفوظة محلياً عبر SharedPreferences.
class AppSettings extends ChangeNotifier {
  bool safetyDialogShown = false;
  int xp = 0;
  int level = 1;
  final Set<String> badges = {};
  final Set<String> completedMissions = {};

  static const int xpPerLevel = 100;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    safetyDialogShown = prefs.getBool('safetyDialogShown') ?? false;
    xp = prefs.getInt('xp') ?? 0;
    level = prefs.getInt('level') ?? 1;
    badges.addAll(prefs.getStringList('badges') ?? []);
    completedMissions.addAll(prefs.getStringList('completedMissions') ?? []);
    for (final kind in TerminalKind.values) {
      final saved = prefs.getInt('wireColor_${kind.index}');
      if (saved != null) {
        defaultWireColors[kind] = Color(saved);
      }
    }
    notifyListeners();
  }

  /// يسمح للمستخدم بتخصيص لون كل نوع سلك (Phase/Neutral/Ground/DC+/DC-...) من شاشة الإعدادات
  Future<void> setWireColor(TerminalKind kind, Color color) async {
    defaultWireColors[kind] = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wireColor_${kind.index}', color.toARGB32());
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safetyDialogShown', safetyDialogShown);
    await prefs.setInt('xp', xp);
    await prefs.setInt('level', level);
    await prefs.setStringList('badges', badges.toList());
    await prefs.setStringList('completedMissions', completedMissions.toList());
  }

  Future<void> markSafetyDialogShown() async {
    safetyDialogShown = true;
    notifyListeners();
    await _persist();
  }

  Future<void> completeMission(String missionId, {int xpReward = 20, String? badge}) async {
    if (completedMissions.contains(missionId)) return;
    completedMissions.add(missionId);
    xp += xpReward;
    while (xp >= level * xpPerLevel) {
      xp -= level * xpPerLevel;
      level++;
    }
    if (badge != null) badges.add(badge);
    notifyListeners();
    await _persist();
  }

  double get progressToNextLevel => xp / (level * xpPerLevel);

  /// يمسح كل تقدّم المستخدم التعليمي (XP/المستوى/الشارات/التحديات المُنجزة)
  Future<void> resetProgress() async {
    xp = 0;
    level = 1;
    badges.clear();
    completedMissions.clear();
    notifyListeners();
    await _persist();
  }
}
