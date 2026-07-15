import 'package:intl/intl.dart';

String formatearMoneda(double valor) {
  final formato = NumberFormat('#,##0.00', 'en_US');
  return 'L. ${formato.format(valor)}';
}

/// Redondea un monto a centavos evitando errores de precisión binaria.
///
/// Multiplicar por 100 y usar `.round()` directamente puede fallar (ej.
/// `2.675 * 100` da `267.49999999999997` en punto flotante binario), lo que
/// produce cifras que terminan en `.99` en vez del valor correcto. Pasar por
/// `toStringAsFixed` usa la conversión decimal correctamente redondeada de
/// Dart antes de volver a un double, evitando ese problema.
double redondearMoneda(double valor) {
  return double.parse(valor.toStringAsFixed(2));
}