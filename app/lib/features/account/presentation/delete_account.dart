import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../bootstrap/api_providers.dart';
import '../../../shared/application/api_exception.dart';
import '../../../shared/presentation/app_theme.dart';
import '../application/auth_service.dart';
import 'session_state.dart';

/// A stale session requires a password check before the deletion is retried.
Future<void> deleteAccount(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ConfirmDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    try {
      await ref.read(accountGatewayProvider).deleteAccount();
    } on ReauthenticationRequiredException {
      if (!context.mounted) return;
      final done = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PasswordDialog(),
      );
      if (done != true) return;
    }
  } on ApiException catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_describe(error))));
    return;
  }

  ref.read(accountDeletedProvider.notifier).set(true);
  await ref.read(authServiceProvider).signOut();
}

String _describe(ApiException error) => switch (error) {
  NetworkException() ||
  ApiTimeoutException() => 'No hay conexión. Revisá tu internet e intentá de nuevo.',
  UnauthorizedException() => 'Tu sesión terminó. Volvé a entrar e intentá de nuevo.',
  _ => 'No se pudo eliminar la cuenta. Intentá de nuevo en un momento.',
};

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      icon: const CircleAvatar(
        radius: 30,
        backgroundColor: AppColors.warningBackground,
        child: Icon(Icons.delete_outline_rounded, color: AppColors.crisis, size: 28),
      ),
      title: const Text('¿Eliminar tu cuenta?', style: AppText.title, textAlign: TextAlign.center),
      content: const Text(
        'Se borran tus mensajes, recuerdos, uso y perfil. No se puede deshacer y ya no '
        'podrás entrar con esta cuenta.',
        style: AppText.body,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.crisis,
            textStyle: AppText.button,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          child: const Text('Eliminar para siempre'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Signs in again with the typed password and retries the deletion, so a wrong
/// password or a failure shows here and the person can try again. Pops `true`
/// once the account is deleted.
class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _password = TextEditingController();
  var _busy = false;
  var _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authServiceProvider);
    final email = auth.email;
    if (_password.text.isEmpty || email == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.signIn(email: email, password: _password.text);
      await ref.read(accountGatewayProvider).deleteAccount();
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailureException catch (error) {
      _fail(switch (error.failure) {
        AuthFailure.invalidCredentials => 'La contraseña no es correcta.',
        AuthFailure.tooManyAttempts => 'Demasiados intentos. Esperá unos minutos.',
        AuthFailure.network => 'No se pudo conectar. Revisá tu conexión a internet.',
        _ => 'Algo salió mal. Intentalo de nuevo en un momento.',
      });
    } on ApiException catch (error) {
      _fail(_describe(error));
    }
  }

  void _fail(String message) {
    if (mounted) {
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      title: const Text('Confirmá tu contraseña', style: AppText.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Por seguridad, escribí tu contraseña para eliminar la cuenta.',
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !_busy,
            autofocus: true,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: AppText.body,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          style: TextButton.styleFrom(foregroundColor: AppColors.crisis),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Eliminar para siempre'),
        ),
      ],
    );
  }
}
