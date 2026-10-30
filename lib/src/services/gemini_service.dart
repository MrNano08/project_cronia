import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'secure_storage_service.dart';

class GeminiPlanningException implements Exception {
  final String userMessage;
  final String diagnostic;
  const GeminiPlanningException(this.userMessage, this.diagnostic);
  @override
  String toString() => userMessage;
}

class GeminiService {
  final SecureStorageService secureStorage;
  final http.Client _client;
  final Random _random;
  bool _requestInProgress = false;

  GeminiService(this.secureStorage, {http.Client? client, Random? random})
      : _client = client ?? http.Client(), _random = random ?? Random();

  Future<List<String>> listModels() async {
    final key = await secureStorage.getGeminiApiKey();
    if (key == null || key.trim().isEmpty) throw const GeminiPlanningException('Configura la API key de Gemini en Ajustes.', 'Missing API key');
    final response = await _client.get(Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {'pageSize': '100'}), headers: {'x-goog-api-key': key});
    if (response.statusCode < 200 || response.statusCode >= 300) throw _httpError(response.statusCode, response.body, response.headers);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['models'] as List? ?? []).whereType<Map>().where((m) => (m['supportedGenerationMethods'] as List? ?? []).contains('generateContent')).map((m) => (m['name'] as String).replaceFirst('models/', '')).toList();
  }

  Future<PlanningResult> plan({required String userInput, required List<CroniaTask> existingTasks, required List<MealBlock> mealBlocks, required AppSettings settings}) async {
    if (userInput.trim().isEmpty || userInput.length > 8000) throw const GeminiPlanningException('La instrucción debe tener texto y no superar 8 000 caracteres.', 'Invalid input length');
    if (_requestInProgress) throw const GeminiPlanningException('La solicitud ya se está procesando.', 'Duplicate request suppressed');
    _requestInProgress = true;
    try {
      final key = await secureStorage.getGeminiApiKey();
      if (key == null || key.trim().isEmpty) throw const GeminiPlanningException('Configura la API key de Gemini en Ajustes.', 'Missing API key');
      final now = settings.userNow();
      final configuredModel = await secureStorage.getGeminiModel();
      final relevant = existingTasks.where((t) => t.date.difference(now).inDays >= -1 && t.date.difference(now).inDays <= 14).map((t) => {'id': t.id, 'date': dateTimeForGemini(t.date), 'start': t.startAt == null ? null : dateTimeForGemini(t.startAt!), 'end': t.endAt == null ? null : dateTimeForGemini(t.endAt!), 'minutes': t.durationMinutes, 'priority': t.priority.name, 'status': t.status.name, 'movable': t.canBeMoved, 'deadline': t.deadline == null ? null : dateTimeForGemini(t.deadline!)}).toList();
      final meals = mealBlocks.where((m) => m.enabled).map((m) => {'time': m.time, 'minutes': m.durationMinutes, 'cooking': m.needsCooking ? m.cookingDurationMinutes : 0}).toList();
      final prompt = 'Convierte la petición en tareas. Devuelve solo JSON con tasks y warnings. Por cada tarea usa action (create/update/move/postpone/cancel/delete_request), existingTaskId o null, title, date (YYYY-MM-DD), time (HH:mm o null), durationMinutes, priority (low/medium/high/urgent), deadline (ISO local o null), reason y recurrence solo si se pide repetir: frequency (daily, weekdays, weekly, monthly, yearly), interval, weekdays (1=lunes a 7=domingo), monthlyPattern, dayOfMonth, weekdayPosition (-1 para último), monthlyWeekday, end (never, onDate, afterCount), endDate y occurrenceCount. No generes fechas repetidas: entrega una sola regla. No inventes IDs. Si falta hora, usa 09:00. No incluyas descripción salvo que sea necesaria. Zona IANA: ${settings.timeZoneId}; ahora local: ${dateTimeForGemini(now)}; despierta ${settings.wakeUpTime}, duerme ${settings.sleepTime}. Tareas ocupadas: ${jsonEncode(relevant)}. Comidas: ${jsonEncode(meals)}. Petición: ${userInput}';
      final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$configuredModel:generateContent');
      http.Response response;
      var attempt = 0;
      while (true) {
        response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode(_requestBody(prompt)),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final error = _httpError(response.statusCode, response.body, response.headers);
          if (attempt >= 2 || !{408, 429, 500, 502, 503, 504}.contains(response.statusCode) || _dailyQuota(response.body)) throw error;
          final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
          final delay = retryAfter != null ? Duration(seconds: retryAfter.clamp(1, 30).toInt()) : Duration(milliseconds: (500 * (1 << attempt)) + _random.nextInt(300));
          await Future<void>.delayed(delay);
          attempt++;
          continue;
        }
        break;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List? ?? [];
      final candidate = candidates.isEmpty ? null : Map<String, dynamic>.from(candidates.first as Map);
      final finish = candidate?['finishReason']?.toString();
      final usage = decoded['usageMetadata'];
      final parts = (candidate?['content']?['parts'] as List?) ?? [];
      final text = parts.whereType<Map>().map((p) => p['text']).whereType<String>().join();
      if (finish == 'MAX_TOKENS' || finish == 'MALFORMED_FUNCTION_CALL' || text.isEmpty) throw GeminiPlanningException('Gemini entregó una respuesta incompleta. Tu texto sigue disponible; intenta dividir la solicitud en menos actividades.', 'finishReason=$finish usage=$usage');
      Map<String, dynamic> json;
      try { json = jsonDecode(text) as Map<String, dynamic>; } catch (e) { throw GeminiPlanningException('La respuesta de Gemini no tiene un formato válido. Intenta de nuevo.', 'JSON validation failed: $e; finishReason=$finish usage=$usage'); }
      final rawTasks = json['tasks'];
      if (rawTasks is! List || rawTasks.isEmpty || rawTasks.length > 30) throw const GeminiPlanningException('La propuesta no contiene tareas válidas (máximo 30 por solicitud).', 'Invalid task list');
      if (json['warnings'] != null && json['warnings'] is! List) throw const GeminiPlanningException('Gemini devolvió advertencias con formato inválido.', 'Invalid warnings');
      final tasks = <Map<String, dynamic>>[];
      for (final item in rawTasks) {
        if (item is! Map) throw const GeminiPlanningException('Una tarea de la propuesta tiene datos inválidos.', 'Task is not an object');
        final date = item['date']?.toString();
        final time = item['time']?.toString();
        if (date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) throw const GeminiPlanningException('Una tarea tiene una fecha inválida.', 'Invalid date');
        late final DateTime start;
        try {
          start = DateTime.parse('$date ${time == null || time == 'null' ? '09:00' : time}:00');
        } catch (_) {
          throw const GeminiPlanningException('Una tarea incluye una hora o fecha inválida. La propuesta no se aplicó.', 'Invalid local date/time');
        }
        final duration = item['durationMinutes'] is int ? item['durationMinutes'] as int : 30;
        if (duration < 5 || duration > 1440) throw const GeminiPlanningException('Una tarea tiene una duración inválida.', 'Invalid duration');
        final action = item['action']?.toString() ?? 'create';
        if (!{'create','update','move','postpone','cancel','delete_request'}.contains(action)) throw const GeminiPlanningException('La propuesta contiene una acción desconocida.', 'Invalid action');
        final existingId = item['existingTaskId'] as String?;
        if (action != 'create' && existingId == null) throw const GeminiPlanningException('La propuesta intenta cambiar una tarea sin identificarla.', 'Missing existing task id');
        if (action == 'create' && existingId != null) throw const GeminiPlanningException('La propuesta de creación contiene un identificador existente inesperado.', 'Create action with id');
        if (existingId != null && !existingTasks.any((t) => t.id == existingId)) throw const GeminiPlanningException('La propuesta hace referencia a una tarea que ya no existe. No se aplicó ningún cambio.', 'Unknown task id');
        final original = existingId == null ? null : existingTasks.firstWhere((t) => t.id == existingId);
        final parsedDeadline = item['deadline'] == null ? null : DateTime.tryParse(item['deadline'].toString());
        if (item['deadline'] != null && parsedDeadline == null) throw const GeminiPlanningException('Una tarea tiene una fecha límite inválida.', 'Invalid deadline');
        final deadline = parsedDeadline ?? original?.deadline;
        tasks.add({'action': action, 'existingTaskId': existingId, 'title': (item['title']?.toString().trim().isNotEmpty ?? false) ? item['title'] : 'Actividad sin título', 'date': date, 'startAt': dateTimeForGemini(start), 'endAt': dateTimeForGemini(start.add(Duration(minutes: duration))), 'durationMinutes': duration, 'priority': original?.priority.name ?? ({'low','medium','high','urgent'}.contains(item['priority']) ? item['priority'] : 'medium'), 'status': action == 'cancel' ? 'cancelled' : action == 'postpone' ? 'postponed' : 'pending', 'isFlexible': original?.isFlexible ?? true, 'canBeMoved': original?.canBeMoved ?? true, 'deadline': original?.deadline == null ? (deadline == null ? null : dateTimeForGemini(deadline)) : dateTimeForGemini(original!.deadline!), 'reason': item['reason'], 'recurrence': _normalizeRecurrence(item['recurrence'], date)});
      }
      developer.log('Gemini response finishReason=$finish usage=$usage', name: 'ProjectCronia.Gemini');
      final output = {'version': '1.0', 'summary': 'Propuesta con ${tasks.length} actividad${tasks.length == 1 ? '' : 'es'}. Revisa fechas y horarios antes de guardar.', 'requiresUserConfirmation': true, 'tasks': tasks, 'warnings': (json['warnings'] as List? ?? []).map((e) => e.toString()).toList(), 'diagnostics': {'finishReason': finish, 'usageMetadata': usage}};
      return PlanningResult.fromJson(output);
    } finally { _requestInProgress = false; }
  }

  bool _dailyQuota(String body) => RegExp(r'quota|daily|per day|limit.*day', caseSensitive: false).hasMatch(body);

  Map<String, dynamic> _requestBody(String prompt) => {
    'contents': [
      {'parts': [{'text': prompt}]},
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'OBJECT',
        'properties': {
          'tasks': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'action': {'type': 'STRING'},
                'existingTaskId': {'type': 'STRING', 'nullable': true},
                'title': {'type': 'STRING'},
                'date': {'type': 'STRING'},
                'time': {'type': 'STRING', 'nullable': true},
                'durationMinutes': {'type': 'INTEGER'},
                'priority': {'type': 'STRING'},
                'deadline': {'type': 'STRING', 'nullable': true},
                'reason': {'type': 'STRING', 'nullable': true},
                'recurrence': {
                  'type': 'OBJECT',
                  'properties': {
                    'frequency': {'type': 'STRING'},
                    'interval': {'type': 'INTEGER'},
                    'weekdays': {
                      'type': 'ARRAY',
                      'items': {'type': 'INTEGER'},
                    },
                    'monthlyPattern': {'type': 'STRING'},
                    'dayOfMonth': {'type': 'INTEGER'},
                    'weekdayPosition': {'type': 'INTEGER'},
                    'monthlyWeekday': {'type': 'INTEGER'},
                    'end': {'type': 'STRING'},
                    'endDate': {'type': 'STRING', 'nullable': true},
                    'occurrenceCount': {'type': 'INTEGER'},
                  },
                },
              },
              'required': [
                'action', 'title', 'date', 'durationMinutes', 'priority',
              ],
            },
          },
          'warnings': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
        },
        'required': ['tasks'],
      },
      'temperature': 0.2,
      'maxOutputTokens': 4096,
    },
  };

  Map<String, dynamic>? _normalizeRecurrence(dynamic raw, String startDate) {
    if (raw == null) return null;
    if (raw is! Map) throw const GeminiPlanningException('La regla de repetición propuesta tiene datos inválidos.', 'recurrence is not an object');
    const frequencies = {'daily', 'weekdays', 'weekly', 'monthly', 'yearly'};
    const endings = {'never', 'onDate', 'afterCount'};
    final frequency = raw['frequency']?.toString();
    final interval = raw['interval'] is int ? raw['interval'] as int : 1;
    final ending = raw['end']?.toString() ?? 'never';
    final weekdays = (raw['weekdays'] as List? ?? []).whereType<int>().toList();
    if (!frequencies.contains(frequency) || interval < 1 || interval > 365 || !endings.contains(ending) || weekdays.any((d) => d < 1 || d > 7)) {
      throw const GeminiPlanningException('La regla de repetición contiene frecuencia, intervalo o días inválidos.', 'invalid recurrence fields');
    }
    final endDate = raw['endDate']?.toString();
    if (ending == 'onDate' && endDate == null) throw const GeminiPlanningException('La repetición requiere una fecha final.', 'missing recurrence endDate');
    if (endDate != null && DateTime.tryParse(endDate) == null) throw const GeminiPlanningException('La regla de repetición tiene una fecha final inválida.', 'invalid recurrence endDate');
    final count = raw['occurrenceCount'] is int ? raw['occurrenceCount'] as int : null;
    if (ending == 'afterCount' && (count == null || count < 1 || count > 10000)) throw const GeminiPlanningException('La repetición requiere una cantidad válida de ocurrencias.', 'invalid recurrence count');
    return {'frequency': frequency, 'interval': interval, 'weekdays': weekdays, 'monthlyPattern': raw['monthlyPattern'] == 'weekdayPosition' ? 'weekdayPosition' : 'dayOfMonth', 'dayOfMonth': (raw['dayOfMonth'] is int ? raw['dayOfMonth'] as int : DateTime.parse(startDate).day).clamp(1, 31).toInt(), 'weekdayPosition': raw['weekdayPosition'] is int ? raw['weekdayPosition'] as int : 1, 'monthlyWeekday': raw['monthlyWeekday'] is int ? (raw['monthlyWeekday'] as int).clamp(1, 7).toInt() : DateTime.parse(startDate).weekday, 'startDate': '${startDate}T00:00:00', 'end': ending, 'endDate': endDate == null ? null : '${endDate}T00:00:00', 'occurrenceCount': count, 'exceptions': <String>[], 'completedDates': <String>[], 'cancelledDates': <String>[]};
  }
  GeminiPlanningException _httpError(int code, String body, Map<String, String> headers) {
    final retry = headers['retry-after'];
    final diagnostic = 'HTTP $code; retry-after=$retry; ${_safeProviderMessage(body)}';
    developer.log('Gemini HTTP response: $diagnostic', name: 'ProjectCronia.Gemini', level: 900);
    if (code == 429) return GeminiPlanningException(_dailyQuota(body) ? 'Se agotó la cuota diaria de Gemini. Vuelve a intentarlo cuando se restablezca.' : 'Gemini alcanzó el límite de solicitudes. Espera un momento y vuelve a intentarlo.', diagnostic);
    if (code == 401 || code == 403) return GeminiPlanningException('Gemini rechazó la API key o sus permisos. Revísala en Ajustes.', diagnostic);
    if (code == 404) return GeminiPlanningException('El modelo de Gemini configurado no existe o no está disponible para esta API key.', diagnostic);
    if (code == 503 || code == 502 || code == 500) return GeminiPlanningException('Gemini no está disponible temporalmente. Intenta más tarde.', diagnostic);
    if (code == 400) return GeminiPlanningException('Gemini rechazó el formato de la solicitud. Revisa el texto e inténtalo de nuevo.', diagnostic);
    return GeminiPlanningException('Gemini respondió con un error HTTP $code. Intenta más tarde.', diagnostic);
  }
  String _safeProviderMessage(String body) { try { final m = (jsonDecode(body) as Map)['error']; return m is Map ? (m['status'] ?? m['code'] ?? 'provider error').toString() : 'provider error'; } catch (_) { return 'provider error'; } }
}
