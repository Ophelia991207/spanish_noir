import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter/services.dart';
import 'tts_manager.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key});
  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  int _currentIndex = 0;
  bool _isSpeaking = false;
  List<Map<String, dynamic>> _stories = [];
  Database? _db; // 將資料庫提升為類別變數，方便更新時使用

  @override
  void initState() {
    super.initState();
    _initStoriesDatabase();
  }

  Future<void> _initStoriesDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = p.join(databasesPath, "spanish_stories.db");

      ByteData data = await rootBundle.load(p.join("assets", "spanish_stories.db"));
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);

      _db = await openDatabase(path);
      _loadStories();
    } catch (e) {
      debugPrint("故事資料庫讀取失敗: $e");
    }
  }

  // 讀取故事
  Future<void> _loadStories() async {
    if (_db == null) return;
    final List<Map<String, dynamic>> results = await _db!.query('stories');
    setState(() {
      _stories = results;
    });
  }

  // ⭐ 新增：切換故事收藏狀態的方法
  Future<void> _toggleStoryFavorite(Map<String, dynamic> story) async {
    if (_db == null) return;

    // 取得目前狀態並翻轉 (0 變 1, 1 變 0)
    int currentStatus = story['is_favorite'] ?? 0;
    int newStatus = (currentStatus == 1) ? 0 : 1;

    // 1. 更新資料庫
    await _db!.update(
      'stories',
      {'is_favorite': newStatus},
      where: 'id = ?',
      whereArgs: [story['id']],
    );

    // 2. 重新讀取資料，更新 UI
    await _loadStories();

    // 3. 顯示小提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 1 ? "已加入筆記本" : "已從筆記本移除"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _nextStory() {
    TtsManager.stop();
    setState(() {
      _isSpeaking = false;
      if (_currentIndex < _stories.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
    });
  }

  @override
  void dispose() {
    TtsManager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    final story = _stories[_currentIndex];
    final String displayTitle = story['title_es'] ?? "";
    final String displayContent = story['content_es'] ?? "";
    final String displayTranslation = story['content_zh'] ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("${_currentIndex + 1} / ${_stories.length}",
            style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(height: 1, color: const Color(0xFFEEEEEE)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(displayTitle,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                        // 🌟 星星按鈕
                        IconButton(
                          icon: Icon(
                            story['is_favorite'] == 1 ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () => _toggleStoryFavorite(story),
                        ),
                        // 🔊 朗讀按鈕
                        // 🔊 朗讀按鈕
                        IconButton(
                          icon: Icon(
                            _isSpeaking ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            size: 36,
                            color: Colors.black,
                          ),
                          // 在 StoryPage 的朗讀按鈕 onPressed 中
                          onPressed: () async {
                            if (_isSpeaking) {
                              await TtsManager.stop(); // 這會把 TtsManager.isActive 設為 false
                              setState(() => _isSpeaking = false);
                            } else {
                              TtsManager.isActive = true; // ⭐ 啟動總電源
                              setState(() => _isSpeaking = true);

                              // 讀標題前檢查
                              if (TtsManager.isActive) await TtsManager.speak(displayTitle);

                              // 句子間的延遲也要檢查電力
                              if (TtsManager.isActive) await Future.delayed(const Duration(milliseconds: 300));

                              List<String> sentences = displayContent.split(RegExp(r'(?<=[.!?])\s+'));
                              for (String sentence in sentences) {
                                // ⭐ 核心：每一句讀之前都檢查總電源！
                                if (!TtsManager.isActive) {
                                  setState(() => _isSpeaking = false);
                                  break;
                                }
                                await TtsManager.speak(sentence);
                              }

                              if (mounted) setState(() => _isSpeaking = false);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayContent,
                                style: const TextStyle(fontSize: 18, height: 1.7, color: Colors.black87)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(color: Color(0xFFEEEEEE)),
                            ),
                            Text(displayTranslation,
                                style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 30, bottom: 50),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _nextStory,
                icon: const Icon(Icons.navigate_next_rounded, color: Colors.white),
                label: const Text("NEXT STORY",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}