import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_cronia/src/models.dart';
import 'package:project_cronia/src/services/gemini_service.dart';
import 'package:project_cronia/src/services/secure_storage_service.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getGeminiApiKey() async => 'test-key';
  @override
  Future<String> getGeminiModel() async => 'gemini-2.5-flash';
}

Map<String, dynamic> _task(String title, String date, String time) => {
  'action': 'create', 'title': title, 'date': date, 'time': time,
  'durationMinutes': 30, 'priority': 'medium', 'existingTaskId': null,
};

http.Response _ok(List<Map<String, dynamic>> tasks, {String finish = 'STOP'}) => http.Response(jsonEncode({
  'candidates': [{'finishReason': finish, 'content': {'parts': [{'text': jsonEncode({'tasks': tasks, 'warnings': []})}]}}],
  'usageMetadata': {'promptTokenCount': 24, 'candidatesTokenCount': 30},
}), 200, headers: {'content-type': 'application/json'});

void main() {
  final settings = AppSettings.defaults();
  test('convierte una solicitud en tres tareas con una sola llamada', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['generationConfig']['responseSchema'], isNotNull);
      return _ok([_task('Matemáticas', '2026-11-02', '08:00'), _task('Inglés', '2026-11-03', '17:00'), _task('Ejercicio', '2026-11-04', '18:00')]);
    });
    final service = GeminiService(_Storage(), client: client);
    final result = await service.plan(userInput: 'Planifica tres actividades', existingTasks: [], mealBlocks: [], settings: settings);
    expect(calls, 1);
    expect(result.tasks, hasLength(3));
    expect(result.tasks.last.startAt?.hour, 18);
  });

  test('Gemini devuelve una regla compacta y Flutter materializa la serie', () async {
    final repeated = _task('Pagar factura', '2026-11-15', '09:00');
    repeated['recurrence'] = {'frequency': 'monthly', 'interval': 1, 'dayOfMonth': 15, 'end': 'afterCount', 'occurrenceCount': 6};
    final service = GeminiService(_Storage(), client: MockClient((_) async => _ok([repeated])));
    final result = await service.plan(userInput: 'Pagar factura el día 15 seis veces', existingTasks: [], mealBlocks: [], settings: settings);
    expect(result.tasks.single.recurrence?.frequency.name, 'monthly');
    expect(result.tasks.single.recurrence?.occurrenceCount, 6);
  });

  test('rechaza JSON truncado como respuesta inválida', () async {
    final client = MockClient((_) async => http.Response('{"candidates": [{"content":{"parts":[{"text":"{\"tasks\":"}]}}]}', 200));
    final service = GeminiService(_Storage(), client: client);
    expect(() => service.plan(userInput: 'tarea', existingTasks: [], mealBlocks: [], settings: settings), throwsA(isA<GeminiPlanningException>()));
  });

  test('distingue finishReason MAX_TOKENS', () async {
    final client = MockClient((_) async => _ok([_task('Tarea', '2026-11-02', '08:00')], finish: 'MAX_TOKENS'));
    final service = GeminiService(_Storage(), client: client);
    expect(() => service.plan(userInput: 'tarea', existingTasks: [], mealBlocks: [], settings: settings), throwsA(predicate((e) => e is GeminiPlanningException && e.diagnostic.contains('MAX_TOKENS'))));
  });

  test('suprime solicitudes duplicadas mientras espera la respuesta', () async {
    final gate = Completer<http.Response>();
    var calls = 0;
    final service = GeminiService(_Storage(), client: MockClient((_) { calls++; return gate.future; }));
    final first = service.plan(userInput: 'tarea', existingTasks: [], mealBlocks: [], settings: settings);
    await Future<void>.delayed(Duration.zero);
    await expectLater(service.plan(userInput: 'tarea', existingTasks: [], mealBlocks: [], settings: settings), throwsA(isA<GeminiPlanningException>()));
    gate.complete(_ok([_task('Tarea', '2026-11-02', '08:00')]));
    await first;
    expect(calls, 1);
  });

  test('no reintenta cuota diaria agotada', () async {
    var calls = 0;
    final service = GeminiService(_Storage(), client: MockClient((_) async { calls++; return http.Response('{"error":{"message":"daily quota exceeded"}}', 429); }));
    await expectLater(service.plan(userInput: 'tarea', existingTasks: [], mealBlocks: [], settings: settings), throwsA(isA<GeminiPlanningException>()));
    expect(calls, 1);
  });

  for (final status in [400, 401, 403, 404, 429, 503]) {
    test('clasifica HTTP $status', () async {
      var calls = 0;
      final client = MockClient((_) async { calls++; return http.Response('{"error":{"status":"FAILED_PRECONDITION","message":"private"}}', status); });
      final service = GeminiService(_Storage(), client: client);
      try { await service.plan(userInput: 'tarea', existingTasks: [], mealBlocks: [], settings: settings); fail('Debió lanzar error'); }
      on GeminiPlanningException catch (e) {
        expect(e.userMessage, isNot(contains('private')));
        expect(e.diagnostic, contains('HTTP $status'));
        if (status == 401 || status == 403) expect(e.userMessage, contains('API key'));
      }
      expect(calls, status == 429 || status == 503 ? 3 : 1);
    });
  }
}
