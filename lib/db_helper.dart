import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class DBHelper {
  static Database? _database;
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'ultimate_spanish_triple.db');
    bool exists = await databaseExists(path);
    if (!exists) {
      ByteData data = await rootBundle.load(join("assets", "ultimate_spanish_triple.db"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return await openDatabase(path);
  }

  // ⭐ 智慧分詞搜尋：支援多關鍵字搜尋
  static Future<List<Map<String, dynamic>>> search(String query) async {
    final db = await database;
    if (query.isEmpty) return [];

    // 將搜尋詞拆開 (例如: "comer helado" -> ["comer", "helado"])
    List<String> words = query.trim().split(RegExp(r'\s+'));
    String whereClause = '';
    List<String> whereArgs = [];

    for (int i = 0; i < words.length; i++) {
      if (i > 0) whereClause += ' AND ';
      whereClause += '(es LIKE ? OR conjugation LIKE ? OR zh LIKE ? OR en LIKE ? OR example LIKE ?)';
      String q = "%${words[i]}%";
      whereArgs.addAll([q, q, q, q, q]);
    }

    return await db.query('dict', where: whereClause, whereArgs: whereArgs);
  }
}