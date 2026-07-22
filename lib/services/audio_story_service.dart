import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Envuelve [FlutterTts] para la lectura en voz alta de un capítulo.
/// Todas las llamadas a la plataforma están protegidas: un dispositivo sin
/// motor TTS instalado (o sin voz para el idioma pedido) no debe tirar una
/// excepción no capturada, solo reportarlo vía [onError].
class AudioStoryService {
  final FlutterTts _tts = FlutterTts();
  bool _handlersReady = false;

  void Function()? onStart;
  void Function()? onComplete;
  void Function(int wordOffset, int wordLength, String text)? onProgress;
  void Function(String message)? onError;

  static const Map<String, String> _localeByLang = {
    'es': 'es-ES',
    'it': 'it-IT',
    'en': 'en-US',
  };

  void _ensureHandlers() {
    if (_handlersReady) return;
    _handlersReady = true;
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setCancelHandler(() => onComplete?.call());
    _tts.setErrorHandler((msg) => onError?.call(msg.toString()));
    _tts.setProgressHandler(
      (text, start, end, word) => onProgress?.call(start, end - start, text),
    );
  }

  Future<bool> speak(String text, String langCode) async {
    _ensureHandlers();
    try {
      await _tts.setLanguage(_localeByLang[langCode] ?? 'es-ES');
      await _tts.awaitSpeakCompletion(true);
      final result = await _tts.speak(text);
      return result == 1;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  Future<void> setSpeechRate(double rate) async {
    try {
      // flutter_tts usa 0.0–1.0 en Android; se mapea desde el multiplicador
      // "humano" (1.0x, 1.25x, 1.5x, 2.0x) a un rango razonable.
      await _tts.setSpeechRate((rate * 0.5).clamp(0.1, 1.0));
    } catch (e) {
      if (kDebugMode) debugPrint('AudioStoryService.setSpeechRate: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('AudioStoryService.stop: $e');
    }
  }
}
