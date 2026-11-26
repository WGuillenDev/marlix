import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/app_theme.dart';
import '../../safety/presentation/help_screen.dart';
import '../application/auth_service.dart';
import '../domain/minimum_age.dart';
import 'auth_form_validation.dart';
import 'birth_date_input_formatter.dart';
import 'credential_field.dart';
import 'email_code_screen.dart';
import 'session_state.dart';

enum _Mode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _birthDate = TextEditingController();
  // Keep the control accessible without adding it to keyboard traversal.
  final _eyeFocus = FocusNode(skipTraversal: true);
  var _mode = _Mode.signIn;
  var _showPassword = false;
  var _busy = false;

  String? _emailError;
  String? _passwordError;
  String? _birthDateError;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _birthDate.dispose();
    _eyeFocus.dispose();
    super.dispose();
  }

  void _switchMode(_Mode mode) {
    if (mode == _mode || _busy) return;
    setState(() {
      _mode = mode;
      _emailError = _passwordError = _birthDateError = _formError = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final signUp = _mode == _Mode.signUp;
    final birthDate = parseBirthDate(_birthDate.text);
    setState(() {
      _emailError = validateEmail(_email.text);
      _passwordError = validatePassword(_password.text, requireMinimum: signUp);
      _birthDateError = signUp ? _validateBirthDate(_birthDate.text, birthDate) : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null || _birthDateError != null) return;

    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (signUp) {
        try {
          await auth.signUp(email: _email.text, password: _password.text, birthDate: birthDate!);
        } on AuthFailureException catch (error) {
          if (error.failure != AuthFailure.emailTaken) rethrow;
        }
        if (mounted && auth.userId == null) {
          _password.clear();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => EmailCodeScreen(email: _email.text.trim())),
          );
        }
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      if (!mounted) return;
      ref.read(sessionEndedProvider.notifier).set(false);
      ref.read(accountDeletedProvider.notifier).set(false);
    } on AuthFailureException catch (error) {
      if (!mounted) return;
      setState(() => _showFailure(error.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFailure(AuthFailure failure) {
    switch (failure) {
      case AuthFailure.invalidCredentials:
        _passwordError = 'El correo o la contraseña no son correctos.';
      case AuthFailure.emailTaken:
        _formError = 'No se pudo completar la solicitud. Intentá de nuevo en un momento.';
      case AuthFailure.invalidEmail:
        _emailError = 'Revisá el correo: no parece válido.';
      case AuthFailure.weakPassword:
        _passwordError = 'Esa contraseña es fácil de adivinar. Probá con una más larga.';
      case AuthFailure.tooManyAttempts:
        _formError = 'Demasiados intentos. Esperá unos minutos y volvé a intentarlo.';
      case AuthFailure.network:
        _formError = 'No se pudo conectar. Revisá tu conexión a internet.';
      case AuthFailure.unexpected:
        _formError = 'Algo salió mal. Intentalo de nuevo en un momento.';
      case AuthFailure.invalidCode:
        _formError = 'El código no es válido o venció. Pedí uno nuevo.';
    }
  }

  static String? _validateBirthDate(String text, DateTime? date) {
    if (text.isEmpty) return 'Escribí tu fecha de nacimiento.';
    final today = DateTime.now();
    if (date == null || date.year < 1900 || date.isAfter(today)) {
      return 'Revisá la fecha: día, mes y año, como 25/03/1990.';
    }
    if (!isOldEnough(date, today)) return 'marlix es para personas de $minimumAge años o más.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final signUp = _mode == _Mode.signUp;
    final sessionEnded = ref.watch(sessionEndedProvider);
    final accountDeleted = ref.watch(accountDeletedProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Welcome(),
                    const SizedBox(height: 24),
                    if (sessionEnded) ...[
                      const _Notice(text: 'Tu sesión terminó. Volvé a entrar para seguir.'),
                      const SizedBox(height: 16),
                    ],
                    if (accountDeleted) ...[
                      const _Notice(text: 'Tu cuenta y todos tus datos se eliminaron.'),
                      const SizedBox(height: 16),
                    ],
                    _ModeSwitch(mode: _mode, onChanged: _switchMode),
                    const SizedBox(height: 20),
                    CredentialField(
                      label: 'Correo',
                      controller: _email,
                      error: _emailError,
                      hint: 'nombre@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CredentialField(
                      label: 'Contraseña',
                      controller: _password,
                      error: _passwordError,
                      helper: signUp ? 'Al menos $minPasswordLength caracteres' : null,
                      obscureText: !_showPassword,
                      autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: signUp ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: signUp ? null : (_) => _submit(),
                      suffix: IconButton(
                        focusNode: _eyeFocus,
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                        tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                        icon: Icon(
                          _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                    if (signUp) ...[
                      const SizedBox(height: 16),
                      CredentialField(
                        label: 'Fecha de nacimiento',
                        controller: _birthDate,
                        error: _birthDateError,
                        hint: 'DD/MM/AAAA',
                        helper: 'Hay que tener $minimumAge años o más.',
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.birthday],
                        inputFormatters: const [BirthDateInputFormatter()],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_formError case final error?) ...[
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
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: AppColors.tanDark,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.tanDark.withValues(alpha: 0.6),
                        textStyle: AppText.button.copyWith(fontSize: 18),
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.white,
                                semanticsLabel: 'Cargando',
                              ),
                            )
                          : Text(signUp ? 'Crear cuenta' : 'Entrar'),
                    ),
                    const SizedBox(height: 24),
                    if (!signUp)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      EmailCodeScreen(email: _email.text.trim(), recovery: true),
                                ),
                              ),
                        child: const Text('Olvidé mi contraseña'),
                      ),
                    Text(
                      'marlix no sustituye la atención profesional.',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // Help must remain available offline and before sign-in.
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(HelpScreen.route()),
                      icon: const Icon(Icons.support_rounded),
                      label: const Text('Ayuda: 9-1-1 y otras líneas'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.crisis,
                        minimumSize: const Size.fromHeight(48),
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

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 80,
            backgroundColor: AppColors.tanLight,
            foregroundImage: const AssetImage('assets/avatar/marlix.png'),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: const Text(
            '¡Hola! Soy marlix',
            textAlign: TextAlign.center,
            style: AppText.display,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu compañía para conversar, cuando quieras.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(_Mode value, String label) {
      final selected = mode == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(value),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    label,
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 17,
                      color: selected ? AppColors.charcoal : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [option(_Mode.signIn, 'Entrar'), option(_Mode.signUp, 'Crear cuenta')],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warningBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: AppText.bodyStrong),
        ),
      ),
    );
  }
}
