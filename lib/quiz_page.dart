import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'tts_manager.dart'; // ⭐ 引入語音管理員
import 'favorite_manager.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late List<Map<String, dynamic>> _quizItems;
  int _currentIndex = 0;
  int _score = 0;
  List<Map<String, dynamic>> _options = [];
  Map<String, dynamic>? _selectedItem;
  bool _isAnswered = false;
  bool _isLoading = true;
  Database? _db;
  bool _modeEsToZh = true;

  @override
  void initState() {
    super.initState();
    // 這裡不需要設定語言了，TtsManager 已經處理好
    _initQuiz();
  }

  Future<void> _initQuiz() async {
    if (FavoriteManager().favorites.isEmpty) {
      Future.microtask(() {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("請先在單字卡收藏一些單字再來測驗喔！"))
        );
        Navigator.pop(context);
      });
      return; // 結束函式，不執行後面的資料庫操作
    }
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, "ultimate_spanish_triple.db");
    _db = await openDatabase(path);

    final now = DateTime.now();

    List<Map<String, dynamic>> dueItems = FavoriteManager().favorites.where((item) {
      if (item['nextReview'] == null) return true;
      return DateTime.parse(item['nextReview']).isBefore(now);
    }).toList();

    if (dueItems.length < 5) {
      dueItems = List.from(FavoriteManager().favorites);
    }

    _quizItems = dueItems;
    _quizItems.shuffle();

    await _generateOptions();
    setState(() => _isLoading = false);
  }

  Future<void> _generateOptions() async {
    final correctItem = _quizItems[_currentIndex];
    List<Map<String, dynamic>> options = [correctItem];
    List<Map<String, dynamic>> otherNotes = FavoriteManager().favorites.where((e) => e['es'] != correctItem['es']).toList();
    otherNotes.shuffle();
    // 在 _generateOptions 結尾加上
    setState(() {
      _selectedItem = null;
      _isAnswered = false;
      _options = options;
    });

// ⭐ 自動發音新題目
    if (_modeEsToZh) {
      TtsManager.speak(correctItem['es']);
    }

    if (otherNotes.length >= 3) {
      options.addAll(otherNotes.take(2));
      final List<Map<String, dynamic>> randomWords = await _db!.rawQuery(
          "SELECT * FROM dict WHERE es NOT IN (${_getAllNoteEs()}) ORDER BY RANDOM() LIMIT 1"
      );
      options.addAll(randomWords);
    } else {
      int needed = 4 - options.length;
      final List<Map<String, dynamic>> randomWords = await _db!.rawQuery(
          "SELECT * FROM dict WHERE es NOT IN (${_getAllNoteEs()}) ORDER BY RANDOM() LIMIT $needed"
      );
      options.addAll(randomWords);
    }
    options.shuffle();
    setState(() { _selectedItem = null; _isAnswered = false; _options = options; });
  }

  String _getAllNoteEs() => FavoriteManager().favorites.map((e) => "'${e['es']}'").join(',');

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    final current = _quizItems[_currentIndex];
    String questionText = _modeEsToZh ? (current['es'] ?? "") : (current['zh'] ?? "");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Score: $_score", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.swap_horiz_rounded), onPressed: () { setState(() { _modeEsToZh = !_modeEsToZh; }); _generateOptions(); }),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentIndex + 1) / _quizItems.length, backgroundColor: const Color(0xFFF0F0F0), color: Colors.black, minHeight: 2),
          const Spacer(flex: 2),

          // 題目區
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(questionText, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              // ⭐ 西文題目時，點擊喇叭發音
              if (_modeEsToZh) IconButton(icon: const Icon(Icons.volume_up_rounded, size: 30), onPressed: () => TtsManager.speak(questionText)),
            ],
          ),

          const Spacer(flex: 2),

          // 選項區
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: _options.map((opt) {
                bool isCorrect = opt['es'] == current['es'];
                bool isSelected = _selectedItem != null && opt['es'] == _selectedItem!['es'];

                Color bgColor = const Color(0xFFF5F5F5);
                Color textColor = Colors.black87;

                if (_isAnswered) {
                  if (isCorrect) { bgColor = Colors.green.shade600; textColor = Colors.white; }
                  else if (isSelected) { bgColor = Colors.red.shade600; textColor = Colors.white; }
                }

                return GestureDetector(
                  onTap: () {
                    if (_isAnswered) return;

                    // ⭐ 西文選項發音
                    if (!_modeEsToZh) TtsManager.speak(opt['es'] ?? "");

                    final bool isCorrect = opt['es'] == current['es'];

                    setState(() {
                      _selectedItem = opt;
                      _isAnswered = true;
                      if (isCorrect) _score++;
                    });

                    // ⭐ 關鍵：將測驗結果寫回 SRS 系統
                    // 這會根據答對/答錯更新 level 和下次複習時間
                    FavoriteManager().updateSRS(current['es'], isCorrect);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (MediaQuery.of(context).size.width - 110) / 2,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _modeEsToZh ? (opt['zh'] ?? "") : (opt['es'] ?? ""),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Spacer(flex: 3),

          if (_isAnswered) Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: TextButton(
              onPressed: () async {
                if (_currentIndex < _quizItems.length - 1) {
                  setState(() => _isLoading = true);
                  _currentIndex++;
                  await _generateOptions().then((_) => setState(() => _isLoading = false));
                } else { _showResult(); }
              },
              child: const Text("NEXT →", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("測驗結束", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("你的分數: $_score / ${_quizItems.length}", textAlign: TextAlign.center),
        actions: [Center(child: TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("返回", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))],
      ),
    );
  }
}