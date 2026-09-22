import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Se lanza cuando una Cloud Function no responde bien: sin conexión, tardó
/// demasiado, o devolvió un error. Quien la captura decide si sigue con el
/// camino local de respaldo o le muestra el mensaje al usuario.
class FuncionesNubeException implements Exception {
  final String mensaje;
  FuncionesNubeException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Llama a las Cloud Functions de este proyecto (ver /functions/index.js)
/// por HTTPS plano, con el paquete `http`, en vez de con el paquete
/// `cloud_functions`. Ese paquete no tiene implementación para Windows
/// (revisar su pubspec.yaml: solo declara android/ios/macos/web), y esta
/// app corre también como programa de escritorio en Windows -usarlo hubiera
/// roto esa versión-. Un POST HTTPS común, siguiendo el mismo protocolo
/// simple que usa el SDK de Firebase para "callable functions"
/// (`{"data": ...}` de entrada, `{"result": ...}` o `{"error": ...}` de
/// salida), funciona igual en Windows, Android, y cualquier navegador
/// -celular (incluido Safari en iPhone) o de escritorio-. La app no usa
/// Firebase Authentication, así que no hay token que adjuntar.
class FuncionesNube {
  // us-central1 es la región de menor latencia hacia Firestore de este
  // proyecto (nam5, multi-región de EE. UU. que la comprende). Ver
  // functions/index.js.
  static const _baseUrl = 'https://us-central1-danielbarbershop-53e3f.cloudfunctions.net';

  // Un solo cliente HTTP compartido para todas las llamadas, con el mismo
  // criterio que ImagenProductoNetwork: reusar la conexión (keep-alive) en
  // vez de abrir una nueva por cada llamada.
  static final http.Client _client = http.Client();

  static Future<dynamic> llamar(
    String nombre,
    Map<String, dynamic> datos, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    http.Response respuesta;
    try {
      respuesta = await _client
          .post(
            Uri.parse('$_baseUrl/$nombre'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'data': datos}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw FuncionesNubeException('$nombre: se agotó el tiempo de espera');
    } catch (e) {
      throw FuncionesNubeException('$nombre: sin conexión con el servidor ($e)');
    }

    Map<String, dynamic> cuerpo;
    try {
      cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw FuncionesNubeException('$nombre: respuesta inválida del servidor');
    }

    if (respuesta.statusCode != 200 || cuerpo.containsKey('error')) {
      final error = cuerpo['error'];
      final mensaje = error is Map ? (error['message']?.toString() ?? 'error desconocido') : 'error desconocido';
      throw FuncionesNubeException('$nombre: $mensaje');
    }
    return cuerpo['result'];
  }
}

/// Convierte de vuelta a [Timestamp] los valores que `functions/index.js`
/// serializó como `{"__timestampMillis": ms}` (JSON no tiene un tipo de
/// fecha propio), para que el resultado se pueda pasar tal cual a los mismos
/// `fromMap` que ya usan los repositorios al leer directo de Firestore, sin
/// tener que duplicar esa lógica de parseo acá.
dynamic revivirTimestamps(dynamic valor) {
  if (valor is Map) {
    if (valor.length == 1 && valor.containsKey('__timestampMillis')) {
      return Timestamp.fromMillisecondsSinceEpoch((valor['__timestampMillis'] as num).toInt());
    }
    return valor.map((clave, v) => MapEntry(clave as String, revivirTimestamps(v)));
  }
  if (valor is List) return valor.map(revivirTimestamps).toList();
  return valor;
}

DateTime? fechaDesdeMillis(dynamic millis) => millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);

double numDesde(dynamic valor) => (valor as num?)?.toDouble() ?? 0;
