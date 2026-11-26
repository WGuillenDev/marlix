import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/app_theme.dart';
import '../application/auth_service.dart';
import 'auth_form_validation.dart';
import 'credential_field.dart';
import 'session_state.dart';

enum _EmailStep { request, code, password, done }

class EmailCodeScreen extends ConsumerStatefulWidget {
  const EmailCodeScreen({super.key, required this.email, this.recovery = false});

  final String email;
  final bool recovery;

  @override
  ConsumerState<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends ConsumerState<EmailCodeScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final AuthService _auth;
  late var _step = widget.recovery ? _EmailStep.request : _EmailStep.code;
  var _busy = false;
  var _seconds = 0;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _auth = ref.read(authServiceProvider);
    if (!widget.recovery) _cooldown();
  }

  void _cooldown() {
    _seconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _seconds--);
      if (_seconds == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.recovery) _auth.cancelRecovery();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit({bool resend = false}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    String? error;
    if (_step == _EmailStep.request) {
      error = validateEmail(_email.text);
    } else if (!resend && _step == _EmailStep.code) {
      if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) error = 'Escribí el código de 6 dígitos.';
    } else if (_step == _EmailStep.password) {
      error = validatePassword(_password.text, requireMinimum: true);
      if (error == null && _password.text != _confirmation.text) {
        error = 'Las contraseñas no coinciden.';
      }
    }
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _busy = true);
    try {
      if (resend || _step == _EmailStep.request) {
        if (widget.recovery) {
          await _auth.requestPasswordReset(_email.text);
        } else {
          await _auth.resendConfirmation(_email.text);
        }
        if (!mounted) return;
        setState(() {
          _step = _EmailStep.code;
          _code.clear();
          _cooldown();
        });
      } else if (_step == _EmailStep.code) {
        if (widget.recovery) {
          await _auth.verifyRecovery(email: _email.text, code: _code.text);
          if (mounted) setState(() => _step = _EmailStep.password);
        } else {
          await _auth.verifyEmail(email: _email.text, code: _code.text);
          if (!mounted) return;
          ref.read(sessionEndedProvider.notifier).set(false);
          ref.read(accountDeletedProvider.notifier).set(false);
        }
      } else if (_step == _EmailStep.password) {
        await _auth.changeRecoveredPassword(_password.text);
        _password.clear();
        _confirmation.clear();
        if (mounted) setState(() => _step = _EmailStep.done);
      }
    } on AuthFailureException catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = switch (failure.failure) {
          AuthFailure.invalidCode ||
          AuthFailure.invalidCredentials ||
          AuthFailure.emailTaken => 'El código no es válido o venció. Pedí uno nuevo.',
          AuthFailure.network => 'No se pudo conectar. Revisá tu conexión a internet.',
          AuthFailure.tooManyAttempts =>
            'Demasiados intentos. Esperá unos minutos y volvé a intentarlo.',
          AuthFailure.weakPassword =>
            'Probá con una contraseña más larga y diferente de la anterior.',
          _ => 'No se pudo completar la solicitud. Intentá de nuevo en un momento.',
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _step == _EmailStep.done;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.recovery ? 'Recuperar contraseña' : 'Confirmar correo')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(switch (_step) {
                      _EmailStep.request =>
                        'Escribí tu correo para pedir un código de recuperación.',
                      _EmailStep.code =>
                        'Si el correo puede recibir un código, llegará a ${_email.text}. Revisá también la carpeta de spam. Si ya tenés cuenta, podés volver para entrar o recuperar tu contraseña.',
                      _EmailStep.password => 'Elegí una nueva contraseña para tu cuenta.',
                      _EmailStep.done => 'Tu contraseña cambió. Volvé a entrar con la nueva.',
                    }, style: AppText.body),
                    const SizedBox(height: 24),
                    if (_step == _EmailStep.request)
                      CredentialField(
                        label: 'Correo',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _submit(),
                      ),
                    if (_step == _EmailStep.code)
                      CredentialField(
                        label: 'Código de 6 dígitos',
                        controller: _code,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onSubmitted: (_) => _submit(),
                      ),
                    if (_step == _EmailStep.password) ...[
                      CredentialField(
                        label: 'Nueva contraseña',
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      const SizedBox(height: 16),
                      CredentialField(
                        label: 'Repetir contraseña',
                        controller: _confirmation,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_error case final error?) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: AppText.bodyStrong.copyWith(color: AppColors.crisis),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : done
                          ? () => Navigator.of(context).pop()
                          : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                semanticsLabel: 'Cargando',
                              ),
                            )
                          : Text(switch (_step) {
                              _EmailStep.request => 'Enviar código',
                              _EmailStep.code => 'Verificar código',
                              _EmailStep.password => 'Guardar contraseña',
                              _EmailStep.done => 'Volver a entrar',
                            }),
                    ),
                    if (_step == _EmailStep.code)
                      TextButton(
                        onPressed: _busy || _seconds > 0 ? null : () => _submit(resend: true),
                        child: Text(
                          _seconds > 0 ? 'Reenviar código en ${_seconds}s' : 'Reenviar código',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
