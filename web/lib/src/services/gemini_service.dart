import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'secure_storage_service.dart';

class GeminiService {
  final SecureStorageService secureStorage;
  final http.Client _client;

  GeminiService(this.secureStorage, {http.Client? client})
      : _client = client ?? http.Client();

  Future<PlanningResult> plan({
    required String userInput,
    required List<CroniaTask> existingTasks,
    required List<MealBlock> mealBlocks,
    required AppSettings settings,
  }) async {
    final apiKey = await secureStorage.getGeminiApiKey();

    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('No hay API key de Gemini configurada.');
    }

    final now = settings.userNow();

    final relevantTasks = existingTasks.where((task) {
      final difference = task.date.difference(now).inDays;
      return difference >= -1 && difference <= 14;
    }).toList();

    final prompt = _buildPrompt(
      userInput: userInput,
      now: now,
      existingTasks: relevantTasks,
      mealBlocks: mealBlocks,
      settings: settings,
    );

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
    );

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
          'maxOutputTokens': 2048,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_formatGeminiError(response.body));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];

    if (text == null || text is! String) {
      throw Exception('Gemini no devolvió texto válido.');
    }

    final cleanText = _cleanJsonText(text);
    final json = jsonDecode(cleanText) as Map<String, dynamic>;

    _validatePlanningJson(json);

    return PlanningResult.fromJson(json);
  }

  String _buildPrompt({
    required String userInput,
    required DateTime now,
    required List<CroniaTask> existingTasks,
    required List<MealBlock> mealBlocks,
    required AppSettings settings,
  }) {
    return '''
Eres el asistente de planificación de Project-Cronia.

Tu tarea es convertir la solicitud del usuario en una propuesta de agenda.

Devuelve únicamente un JSON válido con esta estructura exacta:
{
  "version": "1.0",
  "summary": "Resumen breve de la planificación.",
  "requiresUserConfirmation": true,
  "tasks": [
    {
      "action": "create",
      "existingTaskId": null,
      "title": "Título de la actividad",
      "description": null,
      "date": "2026-06-17T00:00:00",
      "startAt": "2026-06-17T12:00:00",
      "endAt": "2026-06-17T13:00:00",
      "durationMinutes": 60,
      "priority": "medium",
      "status": "pending",
      "isFlexible": true,
      "canBeMoved": true,
      "deadline": null,
      "reason": "Motivo de la ubicación propuesta"
    }
  ],
  "warnings": []
}

Reglas obligatorias:
- Devuelve solo JSON válido.
- No uses Markdown.
- No agregues texto fuera del JSON.
- No elimines actividades directamente.
- Si una actividad debe eliminarse, usa action = "delete_request".
- No muevas actividades con canBeMoved = false.
- Respeta prioridades.
- Respeta horarios de comida y bloquea también el tiempo de cocina cuando needsCooking sea true.
- Respeta la hora de levantarse y la hora de dormir.
- Si el usuario pide recordatorios días antes, toma eso en cuenta en la razón, aunque los recordatorios se creen luego en la app.
- Si hay conflicto, agrega advertencias en warnings.
- Las fechas deben ir en hora local del usuario y sin zona horaria al final.
- Formato correcto: 2026-06-17T14:00:00.
- No devuelvas Z, UTC, -06:00, -05:00 ni ningún sufijo de zona horaria.
- Las prioridades válidas son: low, medium, high, urgent.
- Los estados válidos son: pending, inProgress, completed, postponed, cancelled.
- Las acciones válidas son: create, update, move, postpone, cancel, delete_request.
- Si el usuario no dice una hora exacta, propone una hora razonable dentro del día indicado.
- Si el usuario dice "hoy", usa la fecha de currentLocalDateTime.
- Si el usuario dice "mañana", usa el día siguiente a currentLocalDateTime.

Información de ubicación y hora del usuario:
País: ${settings.country}
Estado/provincia: ${settings.state.isEmpty ? 'No indicado' : settings.state}
Zona horaria IANA: ${settings.timeZoneId}
Offset configurado: ${settings.utcOffsetLabel}
Hora local actual del usuario:
${dateTimeForGemini(now)}
Hora de levantarse:
${settings.wakeUpTime}
Hora de dormir:
${settings.sleepTime}

Solicitud del usuario:
$userInput

Actividades existentes relevantes:
${jsonEncode(existingTasks.map((e) => e.toJson()).toList())}

Horarios de comida:
${jsonEncode(mealBlocks.map((e) => e.toJson()).toList())}
''';
  }

  String _cleanJsonText(String text) {
    return text.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  void _validatePlanningJson(Map<String, dynamic> json) {
    if (json['tasks'] is! List) {
      throw Exception('Gemini devolvió un JSON sin lista de tareas.');
    }

    for (final item in json['tasks'] as List) {
      if (item is! Map<String, dynamic>) {
        throw Exception('Gemini devolvió una tarea con formato inválido.');
      }

      final action = item['action'];
      final priority = item['priority'];
      final status = item['status'];
      final duration = item['durationMinutes'];

      const validActions = {
        'create',
        'update',
        'move',
        'postpone',
        'cancel',
        'delete_request',
      };

      const validPriorities = {'low', 'medium', 'high', 'urgent'};
      const validStatuses = {
        'pending',
        'inProgress',
        'completed',
        'postponed',
        'cancelled',
      };

      if (!validActions.contains(action)) {
        throw Exception('Gemini devolvió una acción inválida: $action');
      }

      if (!validPriorities.contains(priority)) {
        throw Exception('Gemini devolvió una prioridad inválida: $priority');
      }

      if (!validStatuses.contains(status)) {
        throw Exception('Gemini devolvió un estado inválido: $status');
      }

      if (duration is! int || duration <= 0) {
        throw Exception('Gemini devolvió una duración inválida.');
      }

      if (item['date'] == null) {
        throw Exception('Gemini devolvió una tarea sin fecha.');
      }

      parseCroniaDateTime(item['date'] as String);

      if (item['startAt'] != null) {
        parseCroniaDateTime(item['startAt'] as String);
      }

      if (item['endAt'] != null) {
        parseCroniaDateTime(item['endAt'] as String);
      }

      if (item['deadline'] != null) {
        parseCroniaDateTime(item['deadline'] as String);
      }
    }
  }

  String _formatGeminiError(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      final message = decoded['error']?['message'];
      if (message is String && message.isNotEmpty) {
        return 'Gemini respondió con error: $message';
      }
    } catch (_) {
      // Si no se puede leer como JSON, devuelve el cuerpo original.
    }

    return 'Gemini respondió con error: $rawBody';
  }
}
