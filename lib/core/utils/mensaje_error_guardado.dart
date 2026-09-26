import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'error_web_stub.dart' if (dart.library.html) 'error_web_web.dart' as impl;

/// Convierte cualquier error al guardar (venta, compra) en un texto que el
/// cajero pueda entender. En web, un fallo dentro de una transacción de
/// Firestore llegaba como "Dart exception thrown from converted Future..."
/// sin ninguna pista de qué pasó; acá se recupera la causa real y, si es de
/// conexión, se dice claramente.
String mensajeErrorGuardado(Object e) {
  final real = impl.desenvolverErrorBoxed(e);
  if (real is TimeoutException) {
    return 'se agotó el tiempo de espera. Revisá la conexión a internet.';
  }
  if (real is FirebaseException) {
    switch (real.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'no hay conexión estable con el servidor. Revisá el internet e intentá de nuevo.';
      case 'aborted':
      case 'failed-precondition':
        return 'otro equipo estaba guardando al mismo tiempo. Intentá de nuevo.';
      case 'permission-denied':
        return 'el servidor rechazó el guardado (permiso denegado).';
      default:
        return '${real.code}${real.message == null ? '' : ': ${real.message}'}';
    }
  }
  return '$real';
}
