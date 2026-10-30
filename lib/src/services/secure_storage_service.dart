import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _geminiModel = 'gemini_model';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveGeminiApiKey(String value) async {
    await _storage.write(key: _geminiApiKey, value: value.trim());
  }

  Future<String?> getGeminiApiKey() async {
    return _storage.read(key: _geminiApiKey);
  }

  Future<void> deleteGeminiApiKey() async {
    await _storage.delete(key: _geminiApiKey);
  }

  Future<void> saveGeminiModel(String value) async {
    final model = value.trim().replaceFirst(RegExp(r'^models/'), '');
    if (!RegExp(r'^[A-Za-z0-9._-]{3,100}$').hasMatch(model)) {
      throw ArgumentError('Identificador de modelo inválido.');
    }
    await _storage.write(key: _geminiModel, value: model);
  }

  Future<String> getGeminiModel() async =>
      await _storage.read(key: _geminiModel) ?? 'gemini-2.5-flash';
}
