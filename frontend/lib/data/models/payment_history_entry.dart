/// Movimiento de pago de una reserva propia. No incluye datos de tarjeta,
/// referencias de la pasarela ni información de otros participantes.
class PaymentHistoryEntry {
  const PaymentHistoryEntry({
    required this.id,
    required this.reservationId,
    required this.amount,
    required this.status,
    required this.type,
    this.date,
    this.method,
  });

  final String id;
  final String reservationId;
  final double amount;
  final String status;
  final String type;
  final DateTime? date;
  final String? method;

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> raw) {
    return PaymentHistoryEntry(
      id: '${raw['idPago']}',
      reservationId: '${raw['idReserva']}',
      amount: double.parse('${raw['monto']}'),
      status: '${raw['estadoPago']}',
      type: '${raw['tipoPago']}',
      date: DateTime.tryParse('${raw['fechaHoraPago']}'),
      method: raw['metodoPago'] is String ? raw['metodoPago'] as String : null,
    );
  }
}
