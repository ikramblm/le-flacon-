import 'package:intl/intl.dart';

final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');
final DateFormat _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

String formatPrice(dynamic value) {
  final v = value == null
      ? 0.0
      : (value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0);
  return '${v.toStringAsFixed(2).replaceAll('.', ',')} DA';
}

String formatNumber(dynamic value) {
  if (value == null) return '';
  final v = value is num ? value : double.tryParse(value.toString());
  if (v == null) return value.toString();
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

String formatDate(dynamic iso) {
  if (iso == null || iso.toString().isEmpty) return '';
  final dt = DateTime.tryParse(iso.toString());
  if (dt == null) return iso.toString();
  return _dateFmt.format(dt);
}

String formatDateTime(dynamic iso) {
  if (iso == null || iso.toString().isEmpty) return '';
  final dt = DateTime.tryParse(iso.toString());
  if (dt == null) return iso.toString();
  return _dateTimeFmt.format(dt);
}
