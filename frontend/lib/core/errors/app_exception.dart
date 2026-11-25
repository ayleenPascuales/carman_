/// Domain-level error with a message that can be shown to the user.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException({
    String message = 'No pudimos conectar con Carman. Revisa tu conexión.',
    this.isTimeout = false,
  }) : super(message, code: 'network');

  final bool isTimeout;
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code = 'auth'});
}

class PaymentDeclinedException extends AppException {
  const PaymentDeclinedException({
    this.declineCode = 'ERR_CARD_DECLINED',
    this.reason = 'Fondos insuficientes o límite de tarjeta excedido',
  }) : super('Tu banco no autorizó el cargo.', code: 'payment_declined');

  final String declineCode;
  final String reason;
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code = 'validation'});
}
