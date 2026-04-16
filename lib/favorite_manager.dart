import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteManager extends ChangeNotifier {
  static final FavoriteManager _instance = FavoriteManager._internal();
  factory FavoriteManager() => _instance;
  FavoriteManager._internal() { _loadFavorites(); }

  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> get favorites => _favorites;

  // 載入收藏
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('fav_list_v2'); // 使用新 Key 避免衝突
    if (data != null) {
      _favorites = List<Map<String, dynamic>>.from(json.decode(data));
      notifyListeners();
    }
  }

  // 儲存收藏
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fav_list_v2', json.encode(_favorites));
    notifyListeners();
  }

  // 切換收藏狀態（新增時給予初始 SRS 數據）
  void toggleFavorite(Map<String, dynamic> item) {
    final String es = item['es'];
    int index = _favorites.indexWhere((element) => element['es'] == es);

    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      // ⭐ 新增單字時，初始化 SRS 數據
      Map<String, dynamic> newItem = Map<String, dynamic>.from(item);
      newItem['level'] = 0; // 熟練度：0~5
      newItem['nextReview'] = DateTime.now().toIso8601String(); // 立即可以複習
      _favorites.add(newItem);
    }
    _saveFavorites();
  }

  bool isFavorite(String es) => _favorites.any((element) => element['es'] == es);

  // ⭐ SRS 核心算法：更新單字的複習時間
  // 當測驗「答對」時，isCorrect = true；「答錯」時，isCorrect = false
  void updateSRS(String es, bool isCorrect) {
    int index = _favorites.indexWhere((element) => element['es'] == es);
    if (index == -1) return;

    var item = _favorites[index];
    int level = item['level'] ?? 0;

    if (isCorrect) {
      level = (level + 1).clamp(0, 5); // 答對了，熟練度上升
    } else {
      level = (level - 2).clamp(0, 5); // 答錯了，熟練度大幅下降
    }

    // 根據 level 決定下次複習時間 (分鐘為單位，方便測試)
    // 實際使用可以改為天數：[0, 1, 2, 4, 7, 15] 天
    List<int> intervals = [0, 1, 5, 30, 1440, 4320]; // 0分, 1分, 5分, 30分, 1天, 3天
    DateTime nextDate = DateTime.now().add(Duration(minutes: intervals[level]));

    _favorites[index]['level'] = level;
    _favorites[index]['nextReview'] = nextDate.toIso8601String();
    _saveFavorites();
  }
}