import 'package:material_ui/material_ui.dart';

enum PaymentMethodType {
  applePay('Apple Pay', Icons.phone_iphone_rounded),
  googlePay('Google Pay', Icons.account_balance_wallet_rounded),
  card('Tarjeta', Icons.credit_card_rounded),
  paypal('PayPal', Icons.account_balance_wallet_outlined),
  bizum('Bizum / transferencia', Icons.swap_horiz_rounded);

  const PaymentMethodType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    required this.subtitle,
    this.last4,
    this.expiry,
    this.holder,
    this.isDefault = false,
    this.email,
  });

  final String id;
  final PaymentMethodType type;
  final String label;
  final String subtitle;
  final String? last4;
  final String? expiry;
  final String? holder;
  final bool isDefault;
  final String? email;

  bool get isCard => type == PaymentMethodType.card;

  /// Demo cards ending in 0002 emulate a declined charge, like the standard
  /// `4000 0000 0000 0002` test card used by payment gateways.
  bool get isDeclineScenario => last4 == '0002';

  String get description {
    if (type == PaymentMethodType.applePay) {
      return 'Mastercard${last4 != null ? ' ${_dots(last4!)}' : ''}';
    }
    if (type == PaymentMethodType.card) {
      return 'Visa ${_dots(last4 ?? '4242')}${expiry != null ? ' · Expira $expiry' : ''}';
    }
    if (type == PaymentMethodType.paypal) {
      return email ?? 'Cuenta PayPal vinculada';
    }
    return subtitle;
  }

  String _dots(String value) => '•••• $value';

  String get displayLabel => switch (type) {
    PaymentMethodType.applePay => 'Apple Pay',
    PaymentMethodType.googlePay => 'Google Pay',
    PaymentMethodType.card => 'Visa ${_dots(last4 ?? '')}',
    PaymentMethodType.paypal => 'PayPal',
    PaymentMethodType.bizum => 'Transferencia / Bizum',
  };

  PaymentMethod copyWith({
    String? label,
    String? subtitle,
    bool? isDefault,
    String? expiry,
    String? holder,
  }) {
    return PaymentMethod(
      id: id,
      type: type,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      last4: last4,
      expiry: expiry ?? this.expiry,
      holder: holder ?? this.holder,
      isDefault: isDefault ?? this.isDefault,
      email: email,
    );
  }
}

abstract final class PaymentMethodsSeed {
  static const applePay = PaymentMethod(
    id: 'pm-apple',
    type: PaymentMethodType.applePay,
    label: 'Apple Pay',
    subtitle: 'Por defecto',
    last4: '4242',
    isDefault: true,
  );

  static const visa = PaymentMethod(
    id: 'pm-visa',
    type: PaymentMethodType.card,
    label: 'Visa Débito',
    subtitle: 'Tarjeta principal',
    last4: '8819',
    expiry: '09/27',
    holder: 'Elena V.',
  );

  static const paypal = PaymentMethod(
    id: 'pm-paypal',
    type: PaymentMethodType.paypal,
    label: 'PayPal',
    subtitle: 'Confirmación en 60 segundos',
    email: 'alex.rivera@carman.es',
  );

  static const all = [applePay, visa, paypal];
}
