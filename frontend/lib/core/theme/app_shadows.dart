import 'package:material_ui/material_ui.dart';

abstract final class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x07000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  static const floating = [
    BoxShadow(
      color: Color(0x16000000),
      blurRadius: 36,
      offset: Offset(0, 16),
      spreadRadius: -10,
    ),
  ];

  static const violetGlow = [
    BoxShadow(
      color: Color(0x267C5AF6),
      blurRadius: 18,
      offset: Offset(0, 6),
      spreadRadius: -4,
    ),
  ];

  static const bottomBar = [
    BoxShadow(color: Color(0x14FFFFFF), blurRadius: 0, offset: Offset(0, -1)),
  ];
}
