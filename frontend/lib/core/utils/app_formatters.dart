import 'package:intl/intl.dart';

import '../config/app_config.dart';

abstract final class AppFormatters {
  static final NumberFormat _money = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: AppConfig.currencySymbol,
    decimalDigits: 0,
  );

  static final NumberFormat _moneyPrecise = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: AppConfig.currencySymbol,
    decimalDigits: 2,
  );

  static final DateFormat _shortDate = DateFormat('d MMM', 'es');
  static final DateFormat _longDate = DateFormat("d 'de' MMMM", 'es');
  static final DateFormat _weekdayDate = DateFormat('EEE d MMM', 'es');
  static final DateFormat _time = DateFormat('h:mm a', 'es');
  static final DateFormat _monthYear = DateFormat('MMM yyyy', 'es');
  static final NumberFormat _integer = NumberFormat.decimalPattern(
    AppConfig.currencyLocale,
  );

  /// `$75` for whole amounts, `$366.63` when cents matter.
  static String money(num value, {bool precise = false}) {
    if (precise || value % 1 != 0) {
      return _moneyPrecise.format(value);
    }
    return _money.format(value);
  }

  static String moneyPer(num value, String unit) => '${money(value)} / $unit';

  static String integer(num value) => _integer.format(value);

  static String shortDate(DateTime date) => _shortDate.format(date);

  static String longDate(DateTime date) => _longDate.format(date);

  static String weekdayDate(DateTime date) {
    final formatted = _weekdayDate.format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  static String time(DateTime date) => _time.format(date);

  static String monthYear(DateTime date) {
    final value = _monthYear.format(date);
    return value[0].toUpperCase() + value.substring(1);
  }

  static String dateRange(DateTime start, DateTime end) =>
      '${shortDate(start)} – ${shortDate(end)}';

  static String dateRangeWithYear(DateTime start, DateTime end) =>
      '${start.day} ${DateFormat('MMM', 'es').format(start)} – '
      '${end.day} ${DateFormat('MMM', 'es').format(end)} ${end.year}';

  static String duration(int hours) {
    if (hours < 24) return '$hours h';
    final days = (hours / 24).ceil();
    return days == 1 ? '1 día' : '$days días';
  }

  static String relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return shortDate(date);
  }

  static String distance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  static String countdown(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) {
      return '${value.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String maskCard(String last4) => '•••• $last4';

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
