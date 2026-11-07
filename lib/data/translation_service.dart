
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  final OnDeviceTranslatorModelManager _manager =
      OnDeviceTranslatorModelManager();

  OnDeviceTranslator? _translator;

  Future<bool> isModelDownloaded(String languageCode) {
    final language = _getLanguage(languageCode);
    return _manager.isModelDownloaded(language.bcpCode);
  }

  Future<void> downloadModel(String languageCode) async {
    final language = _getLanguage(languageCode);
    await _manager.downloadModel(
      language.bcpCode,
      isWifiRequired: true,
    );
  }

  Future<String> translate({
    required String text,
    required String source,
    required String target,
  }) async {
    final sourceLanguage = _getLanguage(source);
    final targetLanguage = _getLanguage(target);

    _translator?.close();

    _translator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    return await _translator!.translateText(text);
  }

  TranslateLanguage _getLanguage(String code) {
    switch (code) {
      case 'en':
        return TranslateLanguage.english;
      case 'fil':
      case 'tl':
        return TranslateLanguage.tagalog;
      default:
        throw UnsupportedError(
          'Language $code is not supported by ML Kit.',
        );
    }
  }

  void dispose() {
    _translator?.close();
    _translator = null;
  }
}
