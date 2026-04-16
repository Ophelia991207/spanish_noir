import 'package:flutter/material.dart';
import 'favorite_manager.dart';
import 'quiz_page.dart';
import 'tts_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _favoriteStories = [];

  // ✅ 1. 補上漏掉的變數定義
  bool _isStoryPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    FavoriteManager().addListener(() {
      if (mounted) setState(() {});
    });

    _loadFavoriteStories();
  }

  Future<void> _loadFavoriteStories() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, "spanish_stories.db");
    Database db = await openDatabase(path);
    final List<Map<String, dynamic>> results = await db.query(
        'stories',
        where: 'is_favorite = ?',
        whereArgs: [1]
    );
    setState(() {
      _favoriteStories = results;
    });
  }

  // ✅ 2. 修正後的故事彈窗邏輯（結構已對齊）
  void _showStoryPopup(Map<String, dynamic> story) {
    _isStoryPlaying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 15),
                Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 25, 30, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(story['title_es'] ?? "",
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                      ),
                      IconButton(
                        icon: Icon(
                            _isStoryPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            size: 45,
                            color: Colors.black
                        ),
                        onPressed: () async {
                          if (_isStoryPlaying) {
                            await TtsManager.stop();
                            setModalState(() => _isStoryPlaying = false);
                            return;
                          }

                          TtsManager.isActive = true; // ⭐ 啟動總開關
                          setModalState(() => _isStoryPlaying = true);

                          // 1. 讀標題
                          await TtsManager.speak(story['title_es'] ?? "");

                          if (!TtsManager.isActive) return;
                          await Future.delayed(const Duration(milliseconds: 300));

                          // 2. 逐句讀內文
                          List<String> sentences = (story['content_es'] ?? "").split(RegExp(r'(?<=[.!?])\s+'));

                          for (String s in sentences) {
                            if (!TtsManager.isActive) break; // ⭐ 每一句前檢查總開關
                            await TtsManager.speak(s);
                          }

                          if (mounted) {
                            setModalState(() => _isStoryPlaying = false);
                            TtsManager.isActive = false;
                          }
                        },
                      ), // 👈 剛才就是這裡漏掉了一個右括號！
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(story['content_es'] ?? "", style: const TextStyle(fontSize: 18, height: 1.7, color: Colors.black87)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 25), child: Divider(color: Color(0xFFEEEEEE))),
                        Text(story['content_zh'] ?? "", style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5)),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      _isStoryPlaying = false;
      TtsManager.stop();
    });
  }

  void _showWordDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item['es'] ?? "", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
                  IconButton(icon: const Icon(Icons.volume_up_rounded, color: Colors.black54, size: 35), onPressed: () => TtsManager.speak(item['es'] ?? "")),
                ],
              ),
              Text(item['zh'] ?? "", style: const TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              const Divider(height: 50),
              _buildDetailSection("詳細描述", item['zh_desc']),
              _buildDetailSection("例句範例", item['example']),
            ],
          ),
        ),
      ),
    ).then((_) => TtsManager.stop());
  }

  Widget _buildDetailSection(String title, String? content) {
    if (content == null || content.isEmpty || content == "N/A") return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black38)),
        const SizedBox(height: 10),
        Text(content, style: const TextStyle(fontSize: 17, height: 1.5)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordFavorites = FavoriteManager().favorites;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("學習筆記", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black26,
          indicatorColor: Colors.amber,
          indicatorWeight: 4,
          tabs: const [
            Tab(text: "單字庫"),
            Tab(text: "精選故事"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(wordFavorites, isWord: true),
          _buildList(_favoriteStories, isWord: false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizPage())),
        label: const Text("開始測驗", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        icon: const Icon(Icons.psychology_alt_rounded, color: Colors.black),
        backgroundColor: Colors.amber,
        elevation: 8,
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isWord}) {
    if (items.isEmpty) {
      return Center(child: Text(isWord ? "還沒有收藏單字喔" : "還沒有收藏的故事喔", style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(25),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(item[isWord ? 'es' : 'title_es'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(item[isWord ? 'zh' : 'title_zh'] ?? "", style: const TextStyle(color: Colors.grey)),
            trailing: Icon(isWord ? Icons.star_rounded : Icons.auto_stories_rounded, color: isWord ? Colors.amber : Colors.blueGrey[200]),
            onTap: () => isWord ? _showWordDetail(item) : _showStoryPopup(item),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    TtsManager.stop();
    super.dispose();
  }
}