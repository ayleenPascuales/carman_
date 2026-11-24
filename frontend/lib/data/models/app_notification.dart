import 'package:material_ui/material_ui.dart';

enum NotificationKind {
  reservation('Reservas', Icons.receipt_long_rounded, Color(0xFF6B38D4)),
  payment('Pagos', Icons.credit_card_rounded, Color(0xFF0E8A75)),
  license('Licencia', Icons.verified_user_rounded, Color(0xFFB45309)),
  message('Mensajes', Icons.chat_bubble_outline_rounded, Color(0xFF2563EB)),
  system('Sistema', Icons.campaign_outlined, Color(0xFF7B7486));

  const NotificationKind(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    actionRoute: actionRoute,
  );
}
