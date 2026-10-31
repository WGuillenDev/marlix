import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/help_screen.dart';
import 'package:marlix/services/help_resources.dart';

import '../helpers/fake_backend.dart';

Future<void> openHelp(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ayuda'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the help button in the chat header opens the help screen', (tester) async {
    await openChat(tester);
    await openHelp(tester);

    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
  });

  testWidgets('shows 9-1-1 first, the psychological support line and the disclaimer', (
    tester,
  ) async {
    await openChat(tester, size: const Size(360, 1400));
    await openHelp(tester);

    expect(find.text('¿Estás en peligro o necesitas ayuda ya?'), findsOneWidget);
    expect(
      find.text(
        'Servicio: Atención inmediata ante emergencias o situaciones de riesgo',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Horario: 24 horas, 7 días de la semana', findRichText: true), findsOneWidget);
    expect(find.text('Llamar al 9-1-1'), findsOneWidget);
    expect(find.text('Otros recursos en Costa Rica'), findsOneWidget);
    expect(find.text('Llamar a Línea Aquí Estoy'), findsOneWidget);
    expect(
      find.text(
        'Servicio: Atención psicológica gratuita y confidencial del Colegio de Psicólogos de Costa Rica',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Horario: Lunes a viernes de 2:00 p. m. a 10:00 p. m. y sábados de 9:00 a. m. a 4:00 p. m.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Teléfono: 800-273-7869', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('gratuit', findRichText: true),
      findsOneWidget,
      reason: '9-1-1 is not called free',
    );
    expect(
      find.text(
        'marlix es compañía para conversar. No reemplaza la atención de un profesional de la '
        'salud.',
      ),
      findsOneWidget,
    );
    expect(find.text('Esta pantalla funciona sin internet.'), findsOneWidget);
  });

  testWidgets('every button dials its number', (tester) async {
    final dialer = FakeDialer();
    await openChat(tester, dialer: dialer, size: const Size(360, 1400));
    await openHelp(tester);

    await tester.tap(find.text('Llamar al 9-1-1'));
    await tester.pump();
    await tester.tap(find.text('Llamar a Línea Aquí Estoy'));
    await tester.pump();

    expect(dialer.dialed, ['911', '8002737869']);
  });

  testWidgets('without a dialer it says which number to dial', (tester) async {
    final dialer = FakeDialer()..available = false;
    await openChat(tester, dialer: dialer);
    await openHelp(tester);

    await tester.tap(find.text('Llamar al 9-1-1'));
    await tester.pump();

    expect(find.text('No se pudo abrir el teléfono. Marcá el 9-1-1.'), findsOneWidget);
  });

  testWidgets('offline and never connected, 9-1-1 is still there', (tester) async {
    await openChat(tester, backend: FakeBackend()..offline = true);
    await openHelp(tester);

    expect(find.text('Llamar al 9-1-1'), findsOneWidget);
    expect(
      find.text(
        'Servicio: Atención inmediata ante emergencias o situaciones de riesgo',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Otros recursos en Costa Rica'), findsNothing);
  });

  testWidgets('offline, it shows the list saved from the last connection', (tester) async {
    final saved = jsonEncode({
      'updatedAt': '2026-10-14T00:00:00Z',
      'resources': [
        ...crisisResources,
        {
          'id': 'otra-linea',
          'name': 'Otra línea',
          'phone': '22257511',
          'hours': 'Consultar',
          'primary': false,
        },
      ],
    });
    await openChat(
      tester,
      backend: FakeBackend()..offline = true,
      size: const Size(360, 1400),
      savedPreferences: {HelpResourcesController.cacheKey: saved},
    );
    await openHelp(tester);

    expect(find.text('Llamar al 9-1-1'), findsOneWidget);
    expect(find.text('Llamar a Otra línea'), findsOneWidget);
    expect(find.text('Horario: Consultar', findRichText: true), findsOneWidget);
    expect(find.text('Teléfono: 2225-7511', findRichText: true), findsOneWidget);
  });

  testWidgets('opening the chat saves the list for later offline use', (tester) async {
    final backend = await openChat(tester);
    await tester.pumpAndSettle();
    backend.offline = true;

    await openHelp(tester);
    expect(find.text('Llamar a Línea Aquí Estoy'), findsOneWidget);
  });
}
