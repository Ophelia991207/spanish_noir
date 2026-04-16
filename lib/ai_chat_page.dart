import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // ⭐ 官方套件
import 'dart:math';
import 'tts_manager.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // 🔑 貼上你剛剛在 AI Studio 新專案拿到的 Key
  final String _apiKey = "AIzaSyC_WaH5sNMiKM11YOJ2TcMUTbg776DiEes";

  late GenerativeModel _model;
  late ChatSession _chatSession;

  final List<Map<String, dynamic>> _scenarios = [
    {"name": "☕ 咖啡廳點餐", "icon": Icons.coffee},
    {"name": "🚕 呼叫計程車", "icon": Icons.local_taxi},
    {"name": "🏨 飯店入住", "icon": Icons.hotel},
  ];
  late Map<String, dynamic> _currentScenario;

  @override
  void initState() {
    super.initState();
    _currentScenario = _scenarios[Random().nextInt(_scenarios.length)];

    // ⭐ 初始化官方 SDK 模型
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );

    // ⭐ 啟動對話 Session 並設定老師的身分
    _chatSession = _model.startChat(history: [
      Content.text("你是一個西班牙語老師。情境：${_currentScenario['name']}。規則：請用西班牙文跟我對話，並在括號內附上中文翻譯。")
    ]);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
      _controller.clear();
    });

    try {
      // ⭐ 使用 SDK 的發送方式，不再需要自己處理 URL 和 http post
      final response = await _chatSession.sendMessage(Content.text(text));
      final aiResponse = response.text ?? "老師暫時不在線...";

      setState(() {
        _messages.add({"role": "ai", "content": aiResponse});
      });

      // 🎙️ 自動播放高品質語音
      TtsManager.speak(aiResponse);

    } catch (e) {
      // 捕捉錯誤並顯示在畫面，方便 Debug
      setState(() {
        _messages.add({"role": "ai", "content": "❌ 連線錯誤：$e"});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI 老師 - ${_currentScenario['name']}"),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
          )),
          if (_isLoading) const LinearProgressIndicator(color: Colors.black),
          _inputArea(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, String> msg) {
    bool isAi = msg['role'] == 'ai';
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAi ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(msg['content']!, style: TextStyle(color: isAi ? Colors.black : Colors.white)),
      ),
    );
  }

  Widget _inputArea() => Container(
    padding: const EdgeInsets.all(15),
    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
    child: Row(children: [
      Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: "請輸入西文...", filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
      const SizedBox(width: 10),
      IconButton(icon: const Icon(Icons.send_rounded), onPressed: _sendMessage),
    ]),
  );
}