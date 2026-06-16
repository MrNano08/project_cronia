import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:project_cronia/app.dart';
import 'package:project_cronia/src/providers.dart';

void main() {
  testWidgets('Project-Cronia abre onboarding sin perfil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CroniaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Project-Cronia'), findsOneWidget);
    expect(find.text('Configura tu asistente de planificación.'), findsOneWidget);
  });
}
