import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/historia_article.dart';
import '../services/audio_story_service.dart';

enum AudioPlaybackState { idle, playing, paused, stopped }

/// Estado de reproducción de la "audio-historia" (texto a voz) del capítulo
/// abierto en el lector. Vive en un solo lugar (root de la app, como los
/// demás providers) pero por diseño solo se usa desde
/// `HistoriaArticleDetailScreen`: no es un reproductor global, se detiene al
/// salir del lector (ver [stop] llamado desde `dispose()` de esa pantalla).
class AudioPlayerProvider extends ChangeNotifier {
  static const _kSpeechRate = 'ap_speech_rate';
  static const List<double> _rateSteps = [1.0, 1.25, 1.5, 2.0];

  final AudioStoryService _service;
  SharedPreferences? _prefs;

  AudioPlayerProvider({AudioStoryService? service})
      : _service = service ?? AudioStoryService() {
    _service.onStart = _handleStart;
    _service.onComplete = _handleComplete;
    _service.onProgress = _handleProgress;
    _service.onError = _handleError;
  }

  AudioPlaybackState _state = AudioPlaybackState.idle;
  String? _currentArticleId;
  String _fullText = '';
  int _lastWordOffset = 0;
  double _speechRate = 1.0;
  String? _errorMessage;

  AudioPlaybackState get state => _state;
  String? get currentArticleId => _currentArticleId;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  bool get isPaused => _state == AudioPlaybackState.paused;
  double get speechRate => _speechRate;
  String? get errorMessage => _errorMessage;

  /// La UI llama a esto tras mostrar [errorMessage], para no repetirlo en
  /// cada rebuild (mismo patrón que `PremiumProvider.consumeMessage`).
  void consumeError() => _errorMessage = null;

  double get progress {
    if (_fullText.isEmpty) return 0;
    return (_lastWordOffset / _fullText.length).clamp(0.0, 1.0);
  }

  bool isActiveFor(String articleId) =>
      _currentArticleId == articleId && _state != AudioPlaybackState.idle;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _speechRate = _prefs?.getDouble(_kSpeechRate) ?? 1.0;
  }

  Future<void> playArticle(HistoriaArticle article, String lang) async {
    if (_currentArticleId != article.id) {
      await _service.stop();
      _lastWordOffset = 0;
    }
    _currentArticleId = article.id;
    _fullText = article.bodyParagraphsFor(lang).join('\n\n');
    _errorMessage = null;
    await _service.setSpeechRate(_speechRate);

    final text = _lastWordOffset > 0 && _lastWordOffset < _fullText.length
        ? _fullText.substring(_lastWordOffset)
        : _fullText;
    await _service.speak(text, lang);
  }

  Future<void> pause() async {
    if (_state != AudioPlaybackState.playing) return;
    await _service.pause();
    _state = AudioPlaybackState.paused;
    notifyListeners();
  }

  Future<void> resume(String lang) async {
    if (_state != AudioPlaybackState.paused || _currentArticleId == null) {
      return;
    }
    final remaining = _fullText.substring(_lastWordOffset.clamp(0, _fullText.length));
    if (remaining.trim().isEmpty) {
      _handleComplete();
      return;
    }
    await _service.speak(remaining, lang);
  }

  Future<void> stop() async {
    await _service.stop();
    _state = AudioPlaybackState.stopped;
    _currentArticleId = null;
    _fullText = '';
    _lastWordOffset = 0;
    notifyListeners();
  }

  Future<void> cycleSpeed(String lang) async {
    final idx = _rateSteps.indexOf(_speechRate);
    _speechRate = _rateSteps[(idx + 1) % _rateSteps.length];
    notifyListeners();
    await _prefs?.setDouble(_kSpeechRate, _speechRate);
    await _service.setSpeechRate(_speechRate);
    // Re-lanza desde el punto actual con la nueva velocidad si está sonando.
    if (_state == AudioPlaybackState.playing && _currentArticleId != null) {
      final remaining =
          _fullText.substring(_lastWordOffset.clamp(0, _fullText.length));
      await _service.speak(remaining, lang);
    }
  }

  void _handleStart() {
    _state = AudioPlaybackState.playing;
    notifyListeners();
  }

  void _handleComplete() {
    _state = AudioPlaybackState.stopped;
    _currentArticleId = null;
    _fullText = '';
    _lastWordOffset = 0;
    notifyListeners();
  }

  void _handleProgress(int wordOffset, int wordLength, String text) {
    // El offset llega relativo al texto que se le pasó a `speak` (que ya
    // puede ser un sub-string tras una pausa/cambio de velocidad), así que
    // se acumula sobre lo ya narrado en vez de sobreescribir.
    final base = _fullText.length - text.length;
    _lastWordOffset = (base + wordOffset + wordLength).clamp(0, _fullText.length);
    notifyListeners();
  }

  void _handleError(String message) {
    _errorMessage = message;
    _state = AudioPlaybackState.idle;
    _currentArticleId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }
}
