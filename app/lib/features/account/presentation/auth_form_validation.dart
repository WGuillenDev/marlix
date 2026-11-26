const minPasswordLength = 8;

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Escribí tu correo.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Revisá el correo: no parece válido.';
  }
  return null;
}

String? validatePassword(String value, {required bool requireMinimum}) {
  if (value.isEmpty) return 'Escribí tu contraseña.';
  if (requireMinimum && value.length < minPasswordLength) {
    return 'La contraseña debe tener al menos $minPasswordLength caracteres.';
  }
  return null;
}
