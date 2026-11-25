import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/payment_method.dart';

class PaymentState {
  const PaymentState({
    required this.methods,
    required this.selectedId,
    this.saveForFuture = true,
    this.isSaving = false,
    this.error,
  });

  final List<PaymentMethod> methods;
  final String selectedId;
  final bool saveForFuture;
  final bool isSaving;
  final String? error;

  PaymentMethod get selected {
    return methods.firstWhere(
      (method) => method.id == selectedId,
      orElse: () => methods.first,
    );
  }

  PaymentState copyWith({
    List<PaymentMethod>? methods,
    String? selectedId,
    bool? saveForFuture,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return PaymentState(
      methods: methods ?? this.methods,
      selectedId: selectedId ?? this.selectedId,
      saveForFuture: saveForFuture ?? this.saveForFuture,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaymentController extends Notifier<PaymentState> {
  @override
  PaymentState build() {
    return const PaymentState(
      methods: PaymentMethodsSeed.all,
      selectedId: 'pm-apple',
    );
  }

  void select(String id) {
    if (state.methods.any((method) => method.id == id)) {
      state = state.copyWith(selectedId: id, clearError: true);
    }
  }

  void setSaveForFuture(bool value) {
    state = state.copyWith(saveForFuture: value);
  }

  Future<bool> addCard({
    required String number,
    required String expiry,
    required String holder,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13) {
      state = state.copyWith(
        isSaving: false,
        error: 'El número de tarjeta no es válido.',
      );
      return false;
    }
    final last4 = digits.substring(digits.length - 4);
    final method = PaymentMethod(
      id: 'pm-${DateTime.now().millisecondsSinceEpoch}',
      type: PaymentMethodType.card,
      label: 'Visa Crédito',
      subtitle: 'Añadida recientemente',
      last4: last4,
      expiry: expiry,
      holder: holder,
    );
    state = state.copyWith(
      methods: [...state.methods, method],
      selectedId: method.id,
      isSaving: false,
    );
    return true;
  }

  Future<void> setDefault(String id) async {
    final updated = state.methods
        .map((method) => method.copyWith(isDefault: method.id == id))
        .toList();
    state = state.copyWith(methods: updated, selectedId: id);
  }

  Future<void> remove(String id) async {
    if (state.methods.length <= 1) return;
    final updated = state.methods.where((method) => method.id != id).toList();
    final selected = state.selectedId == id
        ? updated.first.id
        : state.selectedId;
    state = state.copyWith(methods: updated, selectedId: selected);
  }
}

final paymentControllerProvider =
    NotifierProvider<PaymentController, PaymentState>(PaymentController.new);
