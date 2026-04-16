import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';
import 'flashcard_page.dart';
import 'story_page.dart';
import 'note_page.dart';
import 'favorite_manager.dart';
// import 'ai_chat_page.dart'; // 如果沒用到就先註解掉，解決 Unused import
import 'help_sheet.dart';
import 'tts_manager.dart';

void main() async {
  // 1. 確保框架初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ⭐ 強制等待語音服務初始化完成
  try {
    await TtsManager.init();
    debugPrint("TTS 初始化成功");
  } catch (e) {
    debugPrint("TTS 初始化失敗: $e");
  }

  // 3. 啟動 App
  runApp(const MyApp());
}

void _initVoiceServices() {
  TtsManager.init().catchError((e) {
    debugPrint("TTS 背景初始化提醒: $e");
  });
}

// 接下來就是 class MyApp ... (後面的程式碼保持不變)
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: const Color(0xFFF8F9FA)
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Database? _db;
  List<Map<String, dynamic>> _foundWords = [];
  final String _tableName = "dict";
  String _dbStatus = "同步中...";
  bool _isDetailPlaying = false; // 控制詳情視窗朗讀的開關
  @override
  void initState() {
    super.initState();
    _initDatabase();

    FavoriteManager().addListener(() { if (mounted) setState(() {}); });
  }

  Future<void> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = p.join(databasesPath, "ultimate_spanish_triple.db");
      await Directory(p.dirname(path)).create(recursive: true);
      ByteData data = await rootBundle.load(p.join("assets", "ultimate_spanish_triple.db"));
      await File(path).writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      _db = await openDatabase(path);
      final pathStory = p.join(databasesPath, "spanish_stories.db");
      ByteData dataStory = await rootBundle.load(p.join("assets", "spanish_stories.db"));
      await File(pathStory).writeAsBytes(dataStory.buffer.asUint8List(), flush: true);
      // 這裡你可以另外定義一個 Database? _storyDb; 來接它
      // _storyDb = await openDatabase(pathStory);
      setState(() => _dbStatus = "已連線");
    } catch (e) { setState(() => _dbStatus = "載入異常"); }
  }

  Widget _headerRoundBtn({required IconData icon, required Color bgColor, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  void _showWebTranslatePage(String query) {
    String url = "https://translate.google.com/?sl=es&tl=zh-TW&text=${Uri.encodeComponent(query)}&op=translate";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
            child: Row(children: [
              Expanded(child: Text(query, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.blueAccent))),
              IconButton(icon: const Icon(Icons.volume_up_rounded, size: 30), onPressed: () => TtsManager.speak(query)),
            ]),
          ),
          const Divider(),
          Expanded(child: WebViewWidget(controller: WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(url)))),
        ]),
      ),
    );
  }

  void _runFilter(String input) async {
    if (_db == null || input.trim().isEmpty) { setState(() => _foundWords = []); return; }
    final String q = input.trim().toLowerCase();
    final List<Map<String, dynamic>> results = await _db!.rawQuery('''
      SELECT *, (CASE WHEN es = ? THEN 1 WHEN es LIKE ? THEN 2 WHEN conjugation LIKE ? THEN 3 ELSE 4 END) as priority
      FROM $_tableName WHERE es LIKE ? OR zh LIKE ? OR en LIKE ? OR conjugation LIKE ?
      ORDER BY priority ASC, length(es) ASC LIMIT 50
    ''', [q, '$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%']);
    setState(() { _foundWords = results; });
  }

  void showDetail(Map<String, dynamic> item) {
    String title = item['es'] ?? "";
    String chinese = item['zh'] ?? "";
    String esDesc = item['es_desc'] ?? "";
    String zhDesc = item['zh_desc'] ?? "";
    String exampleStr = item['example'] ?? "";
    String conjStr = item['conjugation'] ?? "";
    String syn = item['syn_ant'] ?? "";

    List<String> conjList = conjStr.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    List<String> exampleList = exampleStr.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: DefaultTabController(
              length: 4,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
                  child: Row(children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),

                    // 1. 朗讀按鈕 (支援一句接一句，且可隨時停止)
                    // ... 前面代碼保持不變
                    IconButton(
                      icon: Icon(_isDetailPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded, size: 30),
                      onPressed: () async {
                        if (_isDetailPlaying) {
                          await TtsManager.stop();
                          setModalState(() => _isDetailPlaying = false);
                          return;
                        }

                        setModalState(() => _isDetailPlaying = true);

                        // ⭐ 修正點：原本這裡寫了兩次 speak(title)，現在只留一個！
                        await TtsManager.speak(title);

                        // 如果你只需要讀單字發音，後面的 for 迴圈讀例句建議刪掉或註解掉
                        /*
    for (String s in exampleList) {
      if (!_isDetailPlaying) break;
      await TtsManager.speak(s);
    }
    */

                        if (mounted) setModalState(() => _isDetailPlaying = false);
                      },
                    ),
// ... 後面代碼保持不變

                    // 2. 收藏星星按鈕
                    IconButton(
                      icon: Icon(
                          FavoriteManager().isFavorite(title) ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 35,
                          color: Colors.amber
                      ),
                      onPressed: () {
                        FavoriteManager().toggleFavorite(item);
                        setModalState(() {});
                        setState(() {});
                      },
                    ),
                  ]),
                ),
                const TabBar(
                  labelColor: Colors.black, unselectedLabelColor: Colors.black26,
                  indicatorColor: Colors.black, indicatorWeight: 4,
                  tabs: [Tab(text: "說明"), Tab(text: "變化"), Tab(text: "例句"), Tab(text: "相近")],
                ),
                Expanded(child: TabBarView(children: [
                  _contentPage([_infoCard("核心含義", chinese, isPrimary: true), _infoCard("詳細說明", "$zhDesc\n\n$esDesc")]),
                  _gridPage(conjList),
                  _listPage(exampleList),
                  _synonymGrid(syn, showDetail),
                ])),
              ]),
            ),
          );
        },
      ),
      // 在 main.dart 的 showDetail 函式結尾
    ).then((_) {
      _isDetailPlaying = false; // 這是你 HomePage 的變數
      TtsManager.stop();        // ⭐ 這裡會把 TtsManager.isActive 設為 false
      debugPrint("詳情小窗已關閉，停止朗讀");
    });
  }
  Widget _gridPage(List<String> list) {
    if (list.isEmpty) return const Center(child: Text("無變化資訊"));
    return GridView.builder(
      padding: const EdgeInsets.all(25),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 2.5, mainAxisSpacing: 10, crossAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
        child: Text(list[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
      ),
    );
  }

  Widget _listPage(List<String> list) {
    if (list.isEmpty) return const Center(child: Text("無例句資訊"));
    return ListView.builder(
      padding: const EdgeInsets.all(25),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
          child: _clickableText(list[i]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSearching = _searchController.text.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _headerUI(isSearching),
          _searchBoxUI(),
          Expanded(child: isSearching ? _searchListUI() : _mainMenuUI()),
        ]),
      ),
    );
  }

  Widget _headerUI(bool isSearching) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Row(children: [
      if (isSearching) IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); setState(() {}); }),
      Text(isSearching ? "Search" : "Triple Spanish", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      /*const Spacer(),
      _headerRoundBtn(
        icon: Icons.auto_awesome_rounded,
        bgColor: Colors.black,
        iconColor: Colors.white,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage())),
      ),*/
      const SizedBox(width: 12),
      _headerRoundBtn(
        icon: Icons.help_outline_rounded,
        bgColor: Colors.black.withValues(alpha: 0.05),
        iconColor: Colors.black54,
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const HelpSheet(),
        ),
      ),
    ]),
  );

  Widget _searchBoxUI() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
    child: TextField(
      controller: _searchController, onChanged: _runFilter,
      decoration: InputDecoration(
        filled: true, fillColor: Colors.white, hintText: "搜尋...",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() {}); }) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _mainMenuUI() => Column(
    children: [
      const SizedBox(height: 30),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Row(children: [
          _btnUI(Icons.style_rounded, "單字卡", const Color(0xFF2D2D2D), Colors.white),
          const SizedBox(width: 15),
          _btnUI(Icons.auto_stories_rounded, "小故事", Colors.white, Colors.black),
        ]),
      ),
      const SizedBox(height: 15),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 25), child: _btnUI(Icons.edit_note_rounded, "學習筆記", Colors.white, Colors.black, full: true)),
    ],
  );

  Widget _btnUI(IconData i, String l, Color bg, Color t, {bool full = false}) {
    var ink = GestureDetector(
      onTap: () {
        if (l == "單字卡") Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardPage()));
        if (l == "小故事") Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryPage()));
        if (l == "學習筆記") Navigator.push(context, MaterialPageRoute(builder: (_) => const NotePage()));
      },
      child: Container(
        height: 110, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28), border: bg == Colors.white ? Border.all(color: Colors.black12) : null, boxShadow: [if(bg != Colors.white) BoxShadow(color: bg.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: t, size: 28), const SizedBox(width: 12),
          Text(l, style: TextStyle(color: t, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
      ),
    );
    return full ? ink : Expanded(child: ink);
  }

  // 1. 修改搜尋列表 UI，加入語音按鈕與點擊發音
  Widget _searchListUI() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      itemCount: _foundWords.length + 1,
      itemBuilder: (ctx, i) {
        if (i == _foundWords.length) {
          return Container(
            margin: const EdgeInsets.only(top: 10, bottom: 30),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.blueAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              onPressed: () => _showWebTranslatePage(_searchController.text),
              icon: const Icon(Icons.g_translate_rounded),
              label: Text("使用 Google 翻譯 '${_searchController.text}'"),
            ),
          );
        }

        final item = _foundWords[i];
        final String es = item['es'] ?? "";
        final String searchKey = _searchController.text.trim().toLowerCase();
        bool isMatchInConj = false;
        String conjData = (item['conjugation'] ?? "").toLowerCase();

        if (searchKey != es.toLowerCase() && conjData.isNotEmpty) {
          List<String> conjList = conjData.split(RegExp(r'[|,\s/]+')).map((e) => e.trim()).toList();
          if (conjList.contains(searchKey)) isMatchInConj = true;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          // ⭐ 重點修正：捨棄 ListTile，改用 Row + GestureDetector 徹底分開點擊區域
          child: Row(
            children: [
              // 左側區域：點擊顯示詳情
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
                  onTap: () => showDetail(item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 10, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(es, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          if (isMatchInConj)
                            Container(
                                margin: const EdgeInsets.only(left: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text("動詞變位", style: const TextStyle(fontSize: 10, color: Colors.blueAccent))
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(item['zh'] ?? "", style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
              // 右側區域：點擊僅發音
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
                onTap: () {
                  TtsManager.isActive = true;
                  TtsManager.speak(es);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Icon(Icons.volume_up_rounded, color: Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(String label, String content, {bool isPrimary = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 13, color: isPrimary ? Colors.blueAccent : Colors.black38, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _clickableText(content),
      const Divider(height: 40),
    ],
  );

  Widget _contentPage(List<Widget> children) => SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)
  );

  Widget _synonymGrid(String s, Function(Map<String, dynamic>) onDetail) {
    if (s == "N/A" || s.isEmpty) return _contentPage([const Text("無相關詞資訊")]);
    final list = s.split(RegExp(r'[|,\s/]+')).where((e) => e.isNotEmpty).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(25),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF1F3F5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () => _jumpToWord(list[i]),
        child: Text(list[i], style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _clickableText(String content) {
    return Wrap(
      children: content.split(RegExp(r'(\s+)')).map((word) { // 👈 這裡用空白切分
        return GestureDetector(
          onTap: () => _jumpToWord(word),
          // 修改後的版本
          child: Text(
            "$word ", // 👈 在這裡加一個空格，保證顯示時單字間有距離
            style: const TextStyle(fontSize: 17, height: 1.5),
          ),
        );
      }).toList(),
    );
  }

  void _jumpToWord(String text) async {
    String clean = text.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').toLowerCase();
    if (clean.isEmpty) return;
    if (_db == null) return;

    final res = await _db!.rawQuery("SELECT * FROM $_tableName WHERE es = ? LIMIT 1", [clean]);
    if (res.isNotEmpty) {
      showDetail(res.first);
    } else {
      _showWebTranslatePage(clean);
    }
  }
}


// 建立一個獨立的異步函式來處理初始化
Future<void> _initServices() async {
  try {
    // 呼叫我們之前寫好的 REST API 版本 init
    // 加上 timeout 是為了防止在極端情況下（如大陸手機無 Google 架構）無限等待
    await TtsManager.init().timeout(const Duration(seconds: 5));
    debugPrint("TTS 服務已準備就緒");
  } catch (e) {
    debugPrint("TTS 初始化背景任務提醒: $e");
    // 初始化失敗也沒關係，speak() 函式內部會有保底機制
  }
}