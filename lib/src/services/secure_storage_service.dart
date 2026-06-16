import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _geminiApiKey = 'gemini_api_key';

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
}
