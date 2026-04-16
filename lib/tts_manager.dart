import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class TtsManager {
  static final FlutterTts _localTts = FlutterTts();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static Completer<void>? _playCompleter;
  static bool isActive = false;

  // ⭐ 新增：記錄最後一次朗讀的時間
  static DateTime _lastSpeakTime = DateTime.now();

  static Future<void> init() async {
    try {
      await _localTts.setLanguage("es-ES");
      await _localTts.setSpeechRate(0.5);
      await _localTts.setVolume(1.0);
      _audioPlayer.onPlayerComplete.listen((_) => _clearCompleter());
      _audioPlayer.onLog.listen((msg) { if (msg.contains("error")) _clearCompleter(); });
      debugPrint("TTS 初始化完成");
    } catch (e) {
      debugPrint("TTS 初始化異常: $e");
    }
  }

  static void _clearCompleter() {
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      _playCompleter!.complete();
    }
    _playCompleter = null;
  }

  static Future<void> stop() async {
    isActive = false;
    await _audioPlayer.stop();
    await _localTts.stop();
    _clearCompleter();
  }

  static Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // ⭐ 關鍵防抖：如果距離上次呼叫不到 500 毫秒，直接無視
    final now = DateTime.now();
    if (now.difference(_lastSpeakTime).inMilliseconds < 500) return;
    _lastSpeakTime = now;

    await stop();
    await Future.delayed(const Duration(milliseconds: 50));
    isActive = true;

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool hasNetwork = !connectivityResult.contains(ConnectivityResult.none);

    if (hasNetwork) {
      try {
        _playCompleter = Completer<void>();
        final String url = "https://translate.google.com/translate_tts?ie=UTF-8&q=${Uri.encodeComponent(text)}&tl=es&client=tw-ob";

        await _audioPlayer.play(UrlSource(url));

        await _playCompleter!.future.timeout(
            const Duration(seconds: 8),
            onTimeout: () => _clearCompleter()
        );
        return; // ⭐ 成功播放 Google 語音後直接 return，不准跑下面本地 TTS
      } catch (e) {
        _clearCompleter();
      }
    }

    if (isActive) await _localTts.speak(text);
  }
}