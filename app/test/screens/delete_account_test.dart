import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marlix/screens/auth_screen.dart';

import '../helpers/fake_backend.dart';

const _token = 'Bearer token-of-user-ana@example.com';
const _deletedNotice = 'Tu cuenta y todos tus datos se eliminaron.';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes'));
  await tester.pumpAndSettle();
}

Future<void> startDeleting(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Eliminar mi cuenta'));
  await tester.tap(find.text('Eliminar mi cuenta'));
  await tester.pumpAndSettle();
}

Finder get confirmButton => find.widgetWithText(FilledButton, 'Eliminar para siempre');
Finder get passwordButton => find.widgetWithText(TextButton, 'Eliminar para siempre');

void main() {
  testWidgets('settings offers it apart from the rest, and cancelling deletes nothing', (
    tester,
  ) async {
    final auth = FakeAuthService(userId: 'user-ana@example.com');
    final backend = await openChat(tester, auth: auth);
    await openSettings(tester);

    expect(find.text('Borra todos tus datos para siempre'), findsOneWidget);
    await startDeleting(tester);
    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(backend.accountDeletions, isEmpty);
    expect(auth.userId, isNotNull);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('after confirming, the account is deleted and the app returns to sign-in', (
    tester,
  ) async {
    final auth = FakeAuthService(userId: 'user-ana@example.com');
    final backend = await openChat(tester, auth: auth);
    await openSettings(tester);
    await startDeleting(tester);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(backend.accountDeletions, [_token]);
    expect(auth.userId, isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text(_deletedNotice), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing, reason: 'no screen of the session is left');
  });

  testWidgets('the notice goes away with the next sign-in', (tester) async {
    final auth = FakeAuthService(userId: 'user-ana@example.com')
      ..accounts['beto@example.com'] = 'contraseña-de-beto';
    await openChat(tester, auth: auth);
    await openSettings(tester);
    await startDeleting(tester);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(find.text(_deletedNotice), findsOneWidget);

    final email = find.descendant(
      of: find.ancestor(of: find.text('Correo'), matching: find.byType(MergeSemantics)),
      matching: find.byType(TextField),
    );
    final password = find.descendant(
      of: find.ancestor(of: find.text('Contraseña'), matching: find.byType(MergeSemantics)),
      matching: find.byType(TextField),
    );
    await tester.enterText(email, 'beto@example.com');
    await tester.enterText(password, 'contraseña-de-beto');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text(_deletedNotice), findsNothing);
  });

  group('when the last sign-in is too old', () {
    Future<(FakeBackend, FakeAuthService)> openWithOldSession(WidgetTester tester) async {
      final auth = FakeAuthService(userId: 'user-ana@example.com');
      final backend = FakeBackend()..sessionIsOld = true;
      await openChat(tester, auth: auth, backend: backend);
      await openSettings(tester);
      await startDeleting(tester);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      return (backend, auth);
    }

    testWidgets('asks for the password, signs in again and retries', (tester) async {
      final (backend, auth) = await openWithOldSession(tester);

      expect(find.text('Confirmá tu contraseña'), findsOneWidget);
      expect(backend.accountDeletions, hasLength(1), reason: 'the first try was refused');

      await tester.enterText(find.byType(TextField), 'contraseña-de-ana');
      await tester.tap(passwordButton);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(backend.accountDeletions, [_token, _token]);
      expect(auth.userId, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text(_deletedNotice), findsOneWidget);
    });

    testWidgets('a wrong password says so, deletes nothing and lets the person try again', (
      tester,
    ) async {
      final (backend, auth) = await openWithOldSession(tester);

      await tester.enterText(find.byType(TextField), 'otra-contraseña');
      await tester.tap(passwordButton);
      await tester.pumpAndSettle();

      expect(find.text('La contraseña no es correcta.'), findsOneWidget);
      expect(backend.accountDeletions, hasLength(1));
      expect(auth.userId, isNotNull);

      await tester.enterText(find.byType(TextField), 'contraseña-de-ana');
      await tester.tap(passwordButton);
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('cancelling keeps the account and the session', (tester) async {
      final (backend, auth) = await openWithOldSession(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmá tu contraseña'), findsNothing);
      expect(backend.accountDeletions, hasLength(1));
      expect(auth.userId, isNotNull);
      expect(find.text('Ajustes'), findsOneWidget);
    });
  });

  testWidgets('without a connection it says so and keeps the account', (tester) async {
    final auth = FakeAuthService(userId: 'user-ana@example.com');
    final backend = FakeBackend()
      ..accountFailure = () => throw http.ClientException('No connection');
    await openChat(tester, auth: auth, backend: backend);
    await openSettings(tester);
    await startDeleting(tester);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.text('No hay conexión. Revisá tu internet e intentá de nuevo.'), findsOneWidget);
    expect(auth.userId, isNotNull);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('an unexpected error keeps the account and does not claim it was deleted', (
    tester,
  ) async {
    final auth = FakeAuthService(userId: 'user-ana@example.com');
    final backend = FakeBackend()
      ..accountFailure = () => jsonResponse({
        'error': {'code': 'INTERNAL_ERROR', 'message': 'Boom.'},
      }, 500);
    await openChat(tester, auth: auth, backend: backend);
    await openSettings(tester);
    await startDeleting(tester);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo eliminar la cuenta'), findsOneWidget);
    expect(auth.userId, isNotNull);
    expect(find.text(_deletedNotice), findsNothing);
  });
}
