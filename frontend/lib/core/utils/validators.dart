import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../config/app_config.dart';

/// Pure validation helpers shared by every form in the app.
abstract final class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final _phone = RegExp(r'^[+]?[\d\s()-]{7,20}$');
  static final _plate = RegExp(r'^[A-Za-z0-9-]{4,10}$');

  static String? required(String? value, {String label = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label es obligatorio';
    }
    return null;
  }

  static String? email(String? value) {
    final base = required(value, label: 'El correo');
    if (base != null) return base;
    if (!_email.hasMatch(value!.trim())) return 'Introduce un correo válido';
    return null;
  }

  static String? phone(String? value) {
    final base = required(value, label: 'El teléfono');
    if (base != null) return base;
    if (!_phone.hasMatch(value!.trim())) return 'Introduce un teléfono válido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
    if (value.length < 8) return 'Usa al menos 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Incluye una mayúscula';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Incluye una minúscula';
    if (!RegExp(r'[\d\W]').hasMatch(value)) {
      return 'Incluye un número o símbolo';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? document(String? value) {
    final base = required(value, label: 'El documento');
    if (base != null) return base;
    if (value!.trim().length < 6) return 'Introduce un documento válido';
    return null;
  }

  static String? plate(String? value) {
    final base = required(value, label: 'La placa');
    if (base != null) return base;
    if (!_plate.hasMatch(value!.trim())) return 'Formato de placa no válido';
    return null;
  }

  static String? year(String? value) {
    final parsed = int.tryParse(value ?? '');
    final current = DateTime.now().year;
    if (parsed == null) return 'Introduce un año válido';
    if (parsed < 1990 || parsed > current + 1) {
      return 'Año entre 1990 y ${current + 1}';
    }
    return null;
  }

  static String? cardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13 || digits.length > 19) {
      return 'Introduce un número de tarjeta válido';
    }
    if (!_luhn(digits)) return 'El número de tarjeta no es válido';
    return null;
  }

  static String? expiry(String? value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value ?? '');
    if (match == null) return 'Usa el formato MM/AA';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Mes no válido';
    final expiryDate = DateTime(year, month + 1, 0);
    if (expiryDate.isBefore(DateTime.now())) return 'La tarjeta está vencida';
    return null;
  }

  static String? cvv(String? value) {
    if (value == null || !RegExp(r'^\d{3,4}$').hasMatch(value)) {
      return 'CVV no válido';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Introduce los 6 dígitos';
    }
    return null;
  }

  static bool _luhn(String digits) {
    var sum = 0;
    var double = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var digit = int.parse(digits[i]);
      if (double) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      double = !double;
    }
    return sum % 10 == 0;
  }
}

enum PasswordStrength { weak, fair, strong, excellent }

class PasswordAssessment {
  const PasswordAssessment({
    required this.score,
    required this.label,
    required this.color,
    required this.checks,
  });

  final int score; // 0..4
  final String label;
  final Color color;
  final List<PasswordCheck> checks;

  bool get isStrong => score >= 3;
}

class PasswordCheck {
  const PasswordCheck(this.label, this.passed);

  final String label;
  final bool passed;
}

PasswordAssessment assessPassword(String value) {
  final checks = <PasswordCheck>[
    PasswordCheck('Al menos 8 caracteres', value.length >= 8),
    PasswordCheck(
      'Incluye mayúsculas y minúsculas',
      RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value),
    ),
    PasswordCheck(
      'Contiene un número o símbolo',
      RegExp(r'[\d\W]').hasMatch(value),
    ),
    PasswordCheck('12 caracteres o más', value.length >= 12),
  ];
  final score = checks.where((check) => check.passed).length;
  final label = switch (score) {
    0 || 1 => 'Débil',
    2 => 'Aceptable',
    3 => 'Fuerte',
    _ => 'Excelente',
  };
  final color = switch (score) {
    0 || 1 => const Color(0xFFBA1A1A),
    2 => const Color(0xFFB45309),
    3 => const Color(0xFF6B38D4),
    _ => const Color(0xFF0E8A75),
  };
  return PasswordAssessment(
    score: min(score, 4),
    label: label,
    color: color,
    checks: checks,
  );
}

/// Demo helper for card input formatting: 4242 4242 4242 4242.
String formatCardNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatExpiry(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 2) return digits;
  return '${digits.substring(0, 2)}/${digits.substring(2, min(4, digits.length))}';
}

/// Standard phone mask used by the registration form.
String formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final local = digits.startsWith('57') ? digits.substring(2) : digits;
  final buffer = StringBuffer();
  for (var i = 0; i < local.length && i < 10; i++) {
    if (i == 3 || i == 6) buffer.write(' ');
    buffer.write(local[i]);
  }
  return buffer.toString();
}

String defaultPhoneCountryCode() => '+57';

String supportEmailLink() => AppConfig.supportEmail;
