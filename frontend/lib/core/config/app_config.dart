/// Compile-time configuration.
///
/// The app ships with a deterministic demo data source so that the complete
/// experience can be presented without a running backend. Point it at the
/// NestJS API with:
///
/// flutter run --dart-define=CARMAN_USE_LIVE_API=true \
///   --dart-define=CARMAN_API_URL=http://localhost:3000
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'CARMAN_API_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const useLiveApi = bool.fromEnvironment(
    'CARMAN_USE_LIVE_API',
    defaultValue: false,
  );

  static const appName = 'Carman';
  static const tagline = 'MOBILITY REIMAGINED';
  static const supportEmail = 'soporte@carman.app';
  static const supportPhone = '+34 900 100 200';
  static const demoOtp = '582301';
  static const demoEmail = 'alex.rivera@carman.es';
  static const demoPassword = 'Carman123';

  /// Time the inventory is held while a payment is being completed.
  static const paymentHoldMinutes = 15;

  /// Minutes shown in the payment-failure screen before the hold is released.
  static const retryHoldMinutes = 10;

  /// Currency used across the demo (the product is dollar-denominated).
  static const currencyLocale = 'en_US';
  static const currencySymbol = '\$';
  static const taxRate = 0.21;

  static const cities = [
    'Cartagena',
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
  ];
}
