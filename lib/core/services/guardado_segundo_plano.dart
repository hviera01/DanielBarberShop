import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/mensaje_error_guardado.dart';
import '../utils/error_web_stub.dart' if (dart.library.html) '../utils/error_web_web.dart' as web;

/// Guardado optimista: la pantalla ya avanzó (se cerró el formulario, se
/// limpió el carrito, se marcó la venta como anulada) y [accion] corre acá,
/// en segundo plano, sin bloquear a nadie.
///
/// - Si falla por algo pasajero (sin internet estable, tiempo agotado,
///   choque con otro equipo) se reintenta sola hasta [intentosMaximos]
///   veces, esperando un poco más entre cada intento. Solo se hace si la
///   operación es [idempotente] (repetirla no puede duplicar nada); las que
///   no lo son (crear con `add`, registrar un abono) no se reintentan a
///   ciegas porque un intento "fallido" pudo haberse guardado igual.
/// - Si sigue fallando -o el error no era pasajero, como "ya existe un
///   producto con ese código"- avisa con un mensaje que no se cierra solo,
///   con botón Reintentar, y llama a [alFallar] para que quien lo pidió
///   revierta lo que mostró de forma optimista.
/// - Si tarda más de [avisoLento] avisa que sigue guardando (mala conexión)
///   para que nadie crea que se perdió.
///
/// El [ScaffoldMessenger] se captura acá, de una vez, porque casi siempre
/// quien llama se cierra justo después (Navigator.pop) y su contexto deja de
/// servir; el messenger vive a nivel de toda la app y sobrevive.
///
/// [accion] recibe el número de intento (1, 2, ...): las operaciones que
/// pueden haberse completado en un intento anterior lo usan para tratar
/// "ya estaba hecho" como éxito (ver anular venta).
void guardarEnSegundoPlano(
  BuildContext context, {
  required String descripcion,
  required Future<void> Function(int intento) accion,
  bool idempotente = false,
  int intentosMaximos = 3,
  Duration avisoLento = const Duration(seconds: 12),
  VoidCallback? alFallar,
  VoidCallback? alTerminar,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  unawaited(_ejecutar(
    messenger: messenger,
    descripcion: descripcion,
    accion: accion,
    idempotente: idempotente,
    intentosMaximos: intentosMaximos,
    avisoLento: avisoLento,
    alFallar: alFallar,
    alTerminar: alTerminar,
  ));
}

bool _esPasajero(Object e) {
  final real = web.desenvolverErrorBoxed(e);
  if (real is TimeoutException) return true;
  if (real is FirebaseException) {
    return const {'unavailable', 'deadline-exceeded', 'aborted', 'network-request-failed', 'resource-exhausted', 'internal'}.contains(real.code);
  }
  // Un error del SDK web que no se pudo desenvolver: no se sabe qué fue,
  // pero casi siempre es de red o de una transacción interrumpida.
  return real is! Exception && real is! Error;
}

Future<void> _ejecutar({
  required ScaffoldMessengerState? messenger,
  required String descripcion,
  required Future<void> Function(int intento) accion,
  required bool idempotente,
  required int intentosMaximos,
  required Duration avisoLento,
  required VoidCallback? alFallar,
  required VoidCallback? alTerminar,
}) async {
  var avisoMostrado = false;
  final temporizadorAviso = Timer(avisoLento, () {
    avisoMostrado = true;
    messenger?.showSnackBar(SnackBar(
      content: Text('Sigue guardando: $descripcion. Parece que la conexión está lenta; no cierres el sistema todavía.', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      duration: const Duration(seconds: 6),
    ));
  });

  Object? ultimoError;
  for (var intento = 1; intento <= (idempotente ? intentosMaximos : 1); intento++) {
    try {
      await accion(intento);
      temporizadorAviso.cancel();
      if (avisoMostrado) {
        messenger?.showSnackBar(SnackBar(
          content: Text('Listo: $descripcion se guardó.', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          duration: const Duration(seconds: 3),
        ));
      }
      alTerminar?.call();
      return;
    } catch (e) {
      ultimoError = e;
      if (!_esPasajero(e)) break;
      if (intento < intentosMaximos && idempotente) {
        await Future<void>.delayed(Duration(seconds: 2 * intento));
      }
    }
  }
  temporizadorAviso.cancel();
  alFallar?.call();
  final error = ultimoError!;
  messenger?.showSnackBar(
    SnackBar(
      content: Text('⚠ No se pudo guardar ($descripcion): ${mensajeErrorGuardado(error)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF0F1B3D),
      duration: const Duration(seconds: 15),
      showCloseIcon: true,
      closeIconColor: Colors.white,
      action: SnackBarAction(
        label: 'Reintentar',
        textColor: Colors.white,
        onPressed: () => unawaited(_ejecutar(
          messenger: messenger,
          descripcion: descripcion,
          accion: accion,
          idempotente: idempotente,
          intentosMaximos: intentosMaximos,
          avisoLento: avisoLento,
          alFallar: alFallar,
          alTerminar: alTerminar,
        )),
      ),
    ),
  );
}
