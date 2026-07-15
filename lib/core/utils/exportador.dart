import 'exportador_stub.dart'
    if (dart.library.html) 'exportador_web.dart'
    if (dart.library.io) 'exportador_io.dart' as impl;

Future<void> guardarOCompartirArchivo(List<int> bytes, String nombreArchivo) {
  return impl.guardarArchivo(bytes, nombreArchivo);
}