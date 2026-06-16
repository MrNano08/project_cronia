import 'dart:convert';

class JsonUtils {
  static String encode(Object? object) {
    return jsonEncode(object);
  }

  static dynamic decode(String json) {
    return jsonDecode(json);
  }
}
