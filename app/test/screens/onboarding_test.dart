import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/chat/chat_screen.dart';
import 'package:marlix/screens/onboarding/onboarding_screen.dart';
import 'package:marlix/screens/auth_screen.dart';
import 'package:marlix/widgets/avatar_marlix.dart';

import '../helpers/fake_backend.dart';

FakeBackend newUser() => FakeBackend()..onboardingDone = false;

Finder get continueButton => find.widgetWithText(FilledButton, 'Continuar');
Finder get remindersSwitch => find.byType(Switch);
Finder get acceptButton => find.widgetWithText(FilledButton, 'Aceptar y continuar');

Future<void> toConsent(WidgetTester tester) async {
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

Future<void> acceptConsent(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(acceptButton);
  await tester.pumpAndSettle();
}

Future<void> toHelp(WidgetTester tester) async {
  await toConsent(tester);
  await acceptConsent(tester);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

void main() {
  group('who sees it', () {
    testWidgets('a new account sees it first, and not the chat', (tester) async {
      await openChat(tester, backend: newUser());

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.text('¡Hola! Soy marlix'), findsOneWidget);
    });

    testWidgets('an account that finished it goes straight to the chat', (tester) async {
      await openChat(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('the chat stays closed while the profile loads', (tester) async {
      final backend = newUser()..meGate = Completer();
      await openChat(tester, backend: backend);

      expect(find.text('Un momento…'), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);

      backend.meGate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('if the profile cannot be read it offers a retry, never the chat', (tester) async {
      final backend = FakeBackend()
        ..meFailure = (() => jsonResponse({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Unexpected error.'},
        }, 500));
      await openChat(tester, backend: backend);

      expect(find.text('No se pudo abrir tu cuenta'), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.text('Ayuda: 9-1-1 y otros recursos'), findsOneWidget);

      backend.meFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('a rejected session goes back to sign in', (tester) async {
      final backend = FakeBackend()
        ..meFailure = (() => jsonResponse({
          'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid session.'},
        }, 401));
      await openChat(tester, backend: backend);
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Tu sesión terminó. Volvé a entrar para seguir.'), findsOneWidget);
    });
  });

  group('the steps', () {
    testWidgets('the avatar introduces itself with a welcome animation', (tester) async {
      await openChat(tester, backend: newUser());

      expect(tester.widget<AvatarMarlix>(find.byType(AvatarMarlix)).state, AvatarState.happy);
      expect(find.textContaining('Me inspiré en Marley'), findsOneWidget);
    });

    testWidgets('the welcome says marlix and its voice are an AI, not a person', (tester) async {
      await openChat(tester, backend: newUser());

      expect(
        find.textContaining('Soy una inteligencia artificial, no una persona'),
        findsOneWidget,
      );
      expect(find.textContaining('Mi voz también la genera una máquina'), findsOneWidget);
    });

    testWidgets('the notice and what is stored come before the consent', (tester) async {
      await openChat(tester, backend: newUser());
      await toConsent(tester);

      expect(find.text('No soy terapia'), findsOneWidget);
      expect(find.textContaining('Soy compañía para conversar'), findsOneWidget);
      expect(find.textContaining('No doy diagnósticos ni reemplazo a un'), findsOneWidget);
      expect(find.textContaining('Guardo tus mensajes 90 días'), findsOneWidget);
      expect(find.textContaining('Puedes verlos, editarlos y borrarlos'), findsOneWidget);
      expect(find.textContaining('Nunca guardo cédula, tarjetas ni diagnósticos'), findsOneWidget);
      expect(find.textContaining('Puedes eliminar tu cuenta'), findsOneWidget);
    });

    testWidgets('it cannot continue without ticking the consent', (tester) async {
      await openChat(tester, backend: newUser());
      await toConsent(tester);

      FilledButton button() => tester.widget<FilledButton>(acceptButton);
      expect(button().onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(button().onPressed, isNull);
    });

    testWidgets('the steps do not swipe, so the consent cannot be skipped', (tester) async {
      await openChat(tester, backend: newUser());
      await toConsent(tester);

      await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.text('Antes de empezar'), findsOneWidget);
      expect(find.text('Hablemos también por voz'), findsNothing);
    });

    testWidgets('someone who does not accept can leave by signing out', (tester) async {
      final auth = FakeAuthService(userId: 'user-ana@example.com');
      await openChat(tester, backend: newUser(), auth: auth);
      await toConsent(tester);

      await tester.tap(find.text('No acepto, cerrar sesión'));
      await tester.pumpAndSettle();

      expect(auth.userId, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('the back button goes to the previous step', (tester) async {
      await openChat(tester, backend: newUser());
      await toConsent(tester);
      expect(find.text('Antes de empezar'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('¡Hola! Soy marlix'), findsOneWidget);
    });

    testWidgets('it shows where help is and that it works offline', (tester) async {
      await openChat(tester, backend: newUser());
      await toHelp(tester);

      expect(find.text('Si no estás bien, aquí hay ayuda'), findsOneWidget);
      expect(find.textContaining('Toca el salvavidas'), findsOneWidget);
      expect(find.text('También funciona sin internet.'), findsOneWidget);
    });
  });

  group('the microphone', () {
    testWidgets('explains what it is for and asks the system when the person allows it', (
      tester,
    ) async {
      final microphone = FakeMicrophone();
      await openChat(tester, backend: newUser(), microphone: microphone);
      await toConsent(tester);
      await acceptConsent(tester);

      expect(find.textContaining('Lo uso solo cuando estás en modo voz'), findsOneWidget);
      expect(find.textContaining('viaja a nuestro servidor para pasarlo a texto'), findsOneWidget);
      expect(microphone.asked, 0, reason: 'nothing is asked before the person chooses');

      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(microphone.asked, 1);
      expect(find.text('Micrófono permitido.'), findsOneWidget);
      expect(find.text('Permitir'), findsNothing);
    });

    testWidgets('"Ahora no" asks nothing and says it will come back in voice mode', (tester) async {
      final microphone = FakeMicrophone();
      await openChat(tester, backend: newUser(), microphone: microphone);
      await toConsent(tester);
      await acceptConsent(tester);

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(microphone.asked, 0);
      expect(find.textContaining('te lo pido cuando abras el modo voz'), findsOneWidget);
    });

    testWidgets('a refusal in the system dialog is not an error', (tester) async {
      final microphone = FakeMicrophone()..allows = false;
      await openChat(tester, backend: newUser(), microphone: microphone);
      await toConsent(tester);
      await acceptConsent(tester);

      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('te lo pido cuando abras el modo voz'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
    });
  });

  group('the daily reminders offer', () {
    testWidgets('explains them, with no guilt, and is off until the person says yes', (
      tester,
    ) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, backend: newUser(), reminders: reminders);
      await toConsent(tester);
      await acceptConsent(tester);

      expect(find.text('¿Te saludo todos los días?'), findsOneWidget);
      expect(find.textContaining('Sin culpas ni rachas'), findsOneWidget);
      expect(find.textContaining('Si dices que no, no pasa nada'), findsOneWidget);
      expect(tester.widget<Switch>(remindersSwitch).value, isFalse);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('saying yes asks for the permission and schedules them', (tester) async {
      final reminders = FakeReminderScheduler();
      final backend = newUser();
      await openChat(tester, backend: backend, reminders: reminders);
      await toConsent(tester);
      await acceptConsent(tester);

      await tester.tap(remindersSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(remindersSwitch).value, isTrue);
      expect(reminders.scheduled, hasLength(7));

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();

      expect(backend.onboardingRequests.single, {'dataConsent': true, 'remindersEnabled': true});
    });

    testWidgets('a refusal of the notification permission leaves it off and goes on', (
      tester,
    ) async {
      final reminders = FakeReminderScheduler()..grantsPermission = false;
      final backend = newUser();
      await openChat(tester, backend: backend, reminders: reminders);
      await toConsent(tester);
      await acceptConsent(tester);

      await tester.tap(remindersSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(remindersSwitch).value, isFalse);
      expect(find.textContaining('permite las notificaciones'), findsOneWidget);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();

      expect(backend.onboardingRequests.single, {'dataConsent': true, 'remindersEnabled': false});
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('can be turned back off before finishing', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, backend: newUser(), reminders: reminders);
      await toConsent(tester);
      await acceptConsent(tester);

      await tester.tap(remindersSwitch);
      await tester.pumpAndSettle();
      await tester.tap(remindersSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(remindersSwitch).value, isFalse);
      expect(reminders.scheduled, isEmpty);
    });
  });

  group('finishing', () {
    testWidgets('records the consent and opens the chat', (tester) async {
      final backend = newUser();
      await openChat(tester, backend: backend);
      await toHelp(tester);

      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();

      expect(backend.onboardingRequests.single, {'dataConsent': true, 'remindersEnabled': false});
      expect(backend.authorizations, contains('Bearer token-of-user-ana@example.com'));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('if it cannot be saved, it says so and stays to try again', (tester) async {
      final backend = newUser()
        ..onboardingFailure = (() => jsonResponse({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Unexpected error.'},
        }, 500));
      await openChat(tester, backend: backend);
      await toHelp(tester);

      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      backend.onboardingFailure = null;
      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('if another phone finished it first, it opens the chat without a fuss', (
      tester,
    ) async {
      final backend = newUser();
      await openChat(tester, backend: backend);
      await toHelp(tester);

      backend
        ..onboardingDone = true
        ..onboardingFailure = (() => jsonResponse({
          'error': {'code': 'ONBOARDING_ALREADY_COMPLETED', 'message': 'Already done.'},
        }, 409));
      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('does not come back after it was done: a new session reads the profile', (
      tester,
    ) async {
      final backend = newUser();
      final auth = FakeAuthService(userId: 'user-ana@example.com');
      await openChat(tester, backend: backend, auth: auth);
      await toHelp(tester);
      await tester.tap(find.text('¡Empecemos!'));
      await tester.pumpAndSettle();

      await auth.signOut();
      await tester.pumpAndSettle();
      await auth.signIn(email: 'ana@example.com', password: 'contraseña-de-ana');
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(backend.meRequests, 2, reason: 'once per session');
    });
  });

  testWidgets('every step fits a small screen', (tester) async {
    await openChat(tester, size: const Size(320, 568), backend: newUser());
    expect(tester.takeException(), isNull);
    await toConsent(tester);
    expect(tester.takeException(), isNull);
    await acceptConsent(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
