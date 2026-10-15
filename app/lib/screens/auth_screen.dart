import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'help_screen.dart';

enum _Mode { signIn, signUp }

/// Sign-in and sign-up (wireframe docs/diagrams/wireframes/screens/01-login.png).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  static const minPasswordLength = 8;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _birthDate = TextEditingController();
  // Still tappable and read by screen readers, but "next" on the keyboard
  // goes from the password to the birth date, not to this button.
  final _eyeFocus = FocusNode(skipTraversal: true);
  var _mode = _Mode.signIn;
  var _showPassword = false;
  var _busy = false;

  // Shown only after a submit, so nobody gets an error while still typing.
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
      _emailError = _validateEmail(_email.text);
      _passwordError = _validatePassword(_password.text, signUp: signUp);
      _birthDateError = signUp ? _validateBirthDate(_birthDate.text, birthDate) : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null || _birthDateError != null) return;

    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (signUp) {
        await auth.signUp(email: _email.text, password: _password.text, birthDate: birthDate!);
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      // The app switches to the chat on its own when the session starts.
      ref.read(sessionEndedProvider.notifier).set(false);
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
        _emailError = 'Ya hay una cuenta con este correo. Probá entrar.';
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
    }
  }

  static String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Escribí tu correo.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Revisá el correo: no parece válido.';
    }
    return null;
  }

  static String? _validatePassword(String value, {required bool signUp}) {
    if (value.isEmpty) return 'Escribí tu contraseña.';
    if (signUp && value.length < AuthScreen.minPasswordLength) {
      return 'La contraseña debe tener al menos ${AuthScreen.minPasswordLength} caracteres.';
    }
    return null;
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
                    _ModeSwitch(mode: _mode, onChanged: _switchMode),
                    const SizedBox(height: 20),
                    _Field(
                      label: 'Correo',
                      controller: _email,
                      error: _emailError,
                      hint: 'nombre@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      label: 'Contraseña',
                      controller: _password,
                      error: _passwordError,
                      helper: signUp ? 'Al menos ${AuthScreen.minPasswordLength} caracteres' : null,
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
                      _Field(
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
                    Text(
                      'marlix no sustituye la atención profesional.',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // The help lines must be one tap away even without an
                    // account, and they work offline.
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

/// Reads `DD/MM/AAAA`; null when it is not a real date.
DateTime? parseBirthDate(String text) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  final [day, month, year] = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  final date = DateTime(year, month, day);
  // DateTime rolls 31/02 over to March; a real date comes back unchanged.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Adds the slashes while typing, so only the digits have to be typed.
class BirthDateInputFormatter extends TextInputFormatter {
  const BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.helper,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    // Merged so screen readers announce the label with the field.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: !obscureText,
            style: AppText.body.copyWith(fontSize: 17),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
              helperText: error == null ? helper : null,
              helperMaxLines: 2,
              errorText: error,
              errorMaxLines: 3,
              errorStyle: AppText.bodyStrong.copyWith(fontSize: 14, color: AppColors.crisis),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              suffixIcon: suffix,
              enabledBorder: border(AppColors.line),
              focusedBorder: border(AppColors.tanDark),
              errorBorder: border(AppColors.crisis, 2),
              focusedErrorBorder: border(AppColors.crisis, 2),
            ),
          ),
        ],
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
