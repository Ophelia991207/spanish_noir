import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'tts_manager.dart';
import 'favorite_manager.dart';

class FlashcardPage extends StatefulWidget {
  const FlashcardPage({super.key});
  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  List<Map<String, dynamic>> _cards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, "ultimate_spanish_triple.db");
    final db = await openDatabase(path);

    final favorites = FavoriteManager().favorites;
    String excludeIds = favorites.isNotEmpty
        ? "WHERE es NOT IN (${favorites.map((e) => "'${e['es']}'").join(',')})"
        : "";

    final List<Map<String, dynamic>> randomWords = await db.rawQuery('''
      SELECT * FROM dict $excludeIds ORDER BY RANDOM() LIMIT 20
    ''');

    setState(() {
      _cards = randomWords.map((e) => Map<String, dynamic>.from(e)).toList();
      _isLoading = false;
    });

    // ⭐ 自動讀出第一個單字
    if (_cards.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        TtsManager.isActive = true;
        TtsManager.speak(_cards[_currentIndex]['es']);
      });
    }
  } // 👈 剛才漏掉的這個括號補回來了

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_cards.isEmpty) return const Scaffold(body: Center(child: Text("所有單字都已經在你的筆記裡了！")));

    final currentCard = _cards[_currentIndex];
    final String title = currentCard['es'] ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 加上底色讓高級黑白灰更明顯
      appBar: AppBar(
        title: const Text("探索新單字", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("${_currentIndex + 1} / ${_cards.length}", style: const TextStyle(color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 450,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05), // ✅ 修正為最新語法
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
              ),
              child: Stack(children: [
                Positioned(
                    top: 20,
                    left: 20,
                    child: IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 30),
                        onPressed: () {
                          TtsManager.isActive = true;
                          TtsManager.speak(title);
                        }
                    )
                ),
                Positioned(
                    top: 20,
                    right: 20,
                    child: StatefulBuilder(builder: (ctx, setCardState) {
                      return IconButton(
                        icon: Icon(
                            FavoriteManager().isFavorite(title) ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 35
                        ),
                        onPressed: () {
                          FavoriteManager().toggleFavorite(currentCard);
                          setCardState(() {});
                        },
                      );
                    })
                ),
                Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(title, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    if (_showAnswer) ...[
                      const Divider(height: 60, indent: 40, endIndent: 40),
                      Text(currentCard['zh'] ?? "", style: const TextStyle(fontSize: 26, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ] else ...[
                      const SizedBox(height: 50),
                      const Text("點擊卡片看答案", style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold)),
                    ]
                  ]),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () async {
              await TtsManager.stop(); // 切換時先停止
              setState(() {
                _currentIndex = (_currentIndex + 1) % _cards.length;
                _showAnswer = false;
              });
              TtsManager.isActive = true;
              TtsManager.speak(_cards[_currentIndex]['es']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 5,
            ),
            child: const Text("下一個", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}