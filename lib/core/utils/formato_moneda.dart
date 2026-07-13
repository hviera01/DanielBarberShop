import 'package:intl/intl.dart';

String formatearMoneda(double valor) {
  final formato = NumberFormat('#,##0.00', 'en_US');
  return 'L. ${formato.format(valor)}';
}