// Genera assets/images/logo_redondo.png (recorte circular con transparencia
// del logo cuadrado) a partir de assets/images/logo.jpg, para usarlo como
// ícono de la app en Windows (que sí soporta transparencia en el .ico).
// Se corre una sola vez a mano: `dart run tool/generar_logo_redondo.dart`.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.jpg').readAsBytesSync();
  final original = img.decodeJpg(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo.jpg');
    exit(1);
  }
  const tamano = 512;
  final circular = img.copyResizeCropSquare(original, size: tamano, radius: tamano / 2, antialias: true);
  File('assets/images/logo_redondo.png').writeAsBytesSync(img.encodePng(circular));
  // ignore: avoid_print
  print('Listo: assets/images/logo_redondo.png');
}
