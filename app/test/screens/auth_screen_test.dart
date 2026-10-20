import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/auth_screen.dart';
import 'package:marlix/screens/chat/chat_screen.dart';
import 'package:marlix/services/auth_service.dart';

import '../helpers/fake_backend.dart';

Finder field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(MergeSemantics)),
  matching: find.byType(TextField),
);

Future<void> fill(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
  await tester.pump();
}

/// Taps anything, scrolling to it first: the form is taller than a phone.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> submit(WidgetTester tester, String button) async {
  await tapVisible(tester, find.widgetWithText(FilledButton, button));
  // Errors fade in under their field.
  await settle(tester);
}

/// The birth date of someone who turns [years] old today, as typed in the form.
String bornYearsAgo(int years, {int plusDays = 0}) {
  final now = DateTime.now();
  final date = DateTime(now.year - years, now.month, now.day + plusDays);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

void main() {
  late FakeAuthService auth;

  /// Opens the app signed out. The fake is created inside the test, so its
  /// futures run on the test's fake clock.
  Future<FakeBackend> openSignedOut(WidgetTester tester) {
    auth = FakeAuthService();
    return openChat(tester, auth: auth);
  }

  testWidgets('opens on the sign-in screen without a session', (tester) async {
    await openSignedOut(tester);

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('¡Hola! Soy marlix'), findsOneWidget);
    expect(find.text('marlix no sustituye la atención profesional.'), findsOneWidget);
    expect(field('Fecha de nacimiento'), findsNothing);
  });

  testWidgets('opens straight on the chat when a session was saved', (tester) async {
    await openChat(tester, auth: FakeAuthService(userId: 'user-ana@example.com'));

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('signs in and opens the chat, which sends the session token', (tester) async {
    final backend = await openSignedOut(tester);

    await fill(tester, 'Correo', ' ana@example.com ');
    await fill(tester, 'Contraseña', 'contraseña-de-ana');
    await submit(tester, 'Entrar');
    await settle(tester);

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(backend.authorizations, contains('Bearer token-of-user-ana@example.com'));
  });

  testWidgets('wrong credentials show one clear message and keep the email', (tester) async {
    await openSignedOut(tester);

    await fill(tester, 'Correo', 'ana@example.com');
    await fill(tester, 'Contraseña', 'otra-cosa');
    await submit(tester, 'Entrar');

    expect(find.text('El correo o la contraseña no son correctos.'), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('an unknown email gets the same message as a wrong password', (tester) async {
    await openSignedOut(tester);

    await fill(tester, 'Correo', 'nadie@example.com');
    await fill(tester, 'Contraseña', 'contraseña-de-ana');
    await submit(tester, 'Entrar');

    expect(find.text('El correo o la contraseña no son correctos.'), findsOneWidget);
  });

  testWidgets('checks the fields before calling Supabase', (tester) async {
    await openSignedOut(tester);

    await submit(tester, 'Entrar');
    expect(find.text('Escribí tu correo.'), findsOneWidget);
    expect(find.text('Escribí tu contraseña.'), findsOneWidget);

    await fill(tester, 'Correo', 'ana-sin-arroba');
    await submit(tester, 'Entrar');
    expect(find.text('Revisá el correo: no parece válido.'), findsOneWidget);
    expect(auth.userId, isNull);
  });

  testWidgets('shows a loading button and blocks a second submit', (tester) async {
    await openSignedOut(tester);
    auth.gate = Completer();

    await fill(tester, 'Correo', 'ana@example.com');
    await fill(tester, 'Contraseña', 'contraseña-de-ana');
    await submit(tester, 'Entrar');

    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    auth.gate.complete();
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('without a connection it says so', (tester) async {
    await openSignedOut(tester);
    auth.nextFailure = AuthFailure.network;

    await fill(tester, 'Correo', 'ana@example.com');
    await fill(tester, 'Contraseña', 'contraseña-de-ana');
    await submit(tester, 'Entrar');

    expect(find.text('No se pudo conectar. Revisá tu conexión a internet.'), findsOneWidget);
  });

  testWidgets('the eye button shows and hides the password', (tester) async {
    await openSignedOut(tester);
    bool obscured() => tester.widget<TextField>(field('Contraseña')).obscureText;

    expect(obscured(), isTrue);
    await tapVisible(tester, find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(obscured(), isFalse);
    await tapVisible(tester, find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('the help lines are reachable without an account', (tester) async {
    await openSignedOut(tester);

    await tapVisible(tester, find.text('Ayuda: 9-1-1 y otras líneas'));
    await tester.pumpAndSettle();

    expect(find.text('Ayuda'), findsOneWidget);
  });

  group('sign-up', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await openSignedOut(tester);
      await tapVisible(tester, find.text('Crear cuenta'));
      await tester.pump();
    }

    testWidgets('asks for the birth date and creates the account', (tester) async {
      await openSignUp(tester);

      await fill(tester, 'Correo', 'beto@example.com');
      await fill(tester, 'Contraseña', 'una-contraseña-larga');
      await fill(tester, 'Fecha de nacimiento', '02111985');
      expect(find.text('02/11/1985'), findsOneWidget, reason: 'the slashes are added');
      await submit(tester, 'Crear cuenta');
      await settle(tester);

      expect(auth.signUps.single.email, 'beto@example.com');
      expect(auth.signUps.single.birthDate, DateTime(1985, 11, 2));
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('"next" on the keyboard goes field by field, skipping the eye button', (
      tester,
    ) async {
      await openSignUp(tester);
      bool focused(String label) => tester
          .widget<EditableText>(
            find.descendant(of: field(label), matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;

      await tapVisible(tester, field('Correo'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(focused('Contraseña'), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(focused('Fecha de nacimiento'), isTrue);
    });

    testWidgets('refuses someone under 18 without calling Supabase', (tester) async {
      await openSignUp(tester);

      await fill(tester, 'Correo', 'joven@example.com');
      await fill(tester, 'Contraseña', 'una-contraseña-larga');
      await fill(tester, 'Fecha de nacimiento', bornYearsAgo(18, plusDays: 1));
      await submit(tester, 'Crear cuenta');

      expect(
        find.descendant(
          of: field('Fecha de nacimiento'),
          matching: find.text('marlix es para personas de 18 años o más.'),
        ),
        findsOneWidget,
      );
      expect(auth.signUps, isEmpty);
    });

    testWidgets('someone who turns 18 today can sign up', (tester) async {
      await openSignUp(tester);

      await fill(tester, 'Correo', 'cumple@example.com');
      await fill(tester, 'Contraseña', 'una-contraseña-larga');
      await fill(tester, 'Fecha de nacimiento', bornYearsAgo(18));
      await submit(tester, 'Crear cuenta');

      expect(auth.signUps, hasLength(1));
    });

    testWidgets('rejects a date that does not exist and a short password', (tester) async {
      await openSignUp(tester);

      await fill(tester, 'Correo', 'beto@example.com');
      await fill(tester, 'Contraseña', 'corta');
      await fill(tester, 'Fecha de nacimiento', '31021990');
      await submit(tester, 'Crear cuenta');

      expect(find.text('Revisá la fecha: día, mes y año, como 25/03/1990.'), findsOneWidget);
      expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);
      expect(auth.signUps, isEmpty);
    });

    testWidgets('an email with an account suggests signing in', (tester) async {
      await openSignUp(tester);

      await fill(tester, 'Correo', 'ana@example.com');
      await fill(tester, 'Contraseña', 'una-contraseña-larga');
      await fill(tester, 'Fecha de nacimiento', '20051990');
      await submit(tester, 'Crear cuenta');

      expect(find.text('Ya hay una cuenta con este correo. Probá entrar.'), findsOneWidget);
    });
  });

  group('sign-out and the end of a session', () {
    testWidgets('signs out from settings after confirming', (tester) async {
      final signedIn = FakeAuthService(userId: 'user-ana@example.com');
      await openChat(tester, auth: signedIn);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200);
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(signedIn.userId, isNotNull);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(signedIn.userId, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Ajustes'), findsNothing, reason: 'no screen of the session is left');
    });

    testWidgets('the next account does not see the previous messages', (tester) async {
      final signedIn = FakeAuthService(userId: 'user-ana@example.com')
        ..accounts['beto@example.com'] = 'contraseña-de-beto';
      final backend = await openChat(tester, auth: signedIn);
      await type(tester, 'Algo privado de Ana');
      await tester.tap(sendButton);
      backend.answer('Algo privado de Ana', 'Te escucho');
      await settle(tester);

      await signedIn.signOut();
      await settle(tester);
      await fill(tester, 'Correo', 'beto@example.com');
      await fill(tester, 'Contraseña', 'contraseña-de-beto');
      await submit(tester, 'Entrar');
      await settle(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Algo privado de Ana'), findsNothing);
    });

    testWidgets('a session the backend rejects returns to sign-in and says why', (tester) async {
      final signedIn = FakeAuthService(userId: 'user-ana@example.com');
      final backend = await openChat(tester, auth: signedIn);

      await type(tester, 'Hola');
      await tester.tap(sendButton);
      backend.fail(401, 'UNAUTHORIZED');
      await settle(tester);

      expect(signedIn.userId, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Tu sesión terminó. Volvé a entrar para seguir.'), findsOneWidget);

      await fill(tester, 'Correo', 'ana@example.com');
      await fill(tester, 'Contraseña', 'contraseña-de-ana');
      await submit(tester, 'Entrar');
      await settle(tester);
      expect(find.text('Tu sesión terminó. Volvé a entrar para seguir.'), findsNothing);
    });
  });
}
