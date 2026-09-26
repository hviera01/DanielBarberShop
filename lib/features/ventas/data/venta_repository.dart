import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'venta_model.dart';
import 'venta_en_espera_model.dart';
import 'item_venta_model.dart';
import 'pago_detalle_model.dart';
import '../../../core/utils/formato_moneda.dart';
import '../../../core/services/funciones_nube.dart';
import '../../productos/data/lote_costo_repository.dart';

class VentaRepository {
  final _db = FirebaseFirestore.instance;
  final _colVentas = FirebaseFirestore.instance.collection('ventas');
  final _colEspera = FirebaseFirestore.instance.collection('ventasEnEspera');
  final _lotes = LoteCostoRepository();
  final _colContadores = FirebaseFirestore.instance.collection('contadores');
  final _colVentasCredito = FirebaseFirestore.instance.collection('ventasCredito');

  String _claveContador(String tipoDocumento) {
    switch (tipoDocumento) {
      case 'Cotizacion':
        return 'cotizacion';
      case 'Venta':
        return 'ventaSinFacturar';
      default:
        return 'venta';
    }
  }

  String _formatearCorrelativo(String tipoDocumento, int numero) {
    if (tipoDocumento == 'Venta') {
      return numero.toString().padLeft(5, '0');
    }
    return numero.toString().padLeft(8, '0');
  }

  /// Próximo número que le tocaría a la próxima Factura/Boleta (comparten
  /// el mismo contador 'venta', ver _claveContador). Para uso en Negocio,
  /// donde se puede consultar y fijar manualmente antes de empezar a
  /// facturar (por ejemplo, para continuar la numeración de un talonario
  /// físico en vez de arrancar siempre desde 1).
  Future<int> obtenerProximoNumeroFactura() async {
    final snap = await _colContadores.doc('venta').get();
    final actual = ((snap.data()?['ultimo'] ?? 0) as num).toInt();
    return actual + 1;
  }

  Future<void> establecerProximoNumeroFactura(int proximoNumero) async {
    final nuevoUltimo = proximoNumero - 1;
    await _colContadores.doc('venta').set({'ultimo': nuevoUltimo < 0 ? 0 : nuevoUltimo}, SetOptions(merge: true));
  }

  Future<VentaModel> registrarVenta({
    required String tipoDocumento,
    required String condicion,
    required String metodoPago,
    required String documentoCliente,
    required String nombreCliente,
    required DateTime fechaRegistro,
    required DateTime? fechaVencimiento,
    required String oc,
    required String regExonerado,
    required String regSag,
    double descuentoGlobal = 0,
    required List<ItemVentaModel> items,
    required double montoPago,
    required double montoCambio,
    List<PagoDetalle> pagosMixtos = const [],
    required double subtotal,
    required double impuesto,
    required double totalAPagar,
    required String usuario,
    // Categorías marcadas para no controlar existencia (servicios, pintura
    // preparada, etc.): sus productos no bajan del inventario al venderse.
    // Se recibe ya resuelta desde la UI (que ya tiene las categorías
    // cargadas en memoria vía su stream) en vez de volver a consultarlas
    // acá: hacerlo adentro agregaba una ida y vuelta extra a Firestore justo
    // antes de cada venta, y el registro de venta tiene que sentirse casi
    // instantáneo.
    Set<String> categoriasSinControlStock = const {},
    // % sugerido (2.9/3.5, solo referencia para calcular montoRecargoTarjeta
    // en la UI) y monto real del recargo por pago con tarjeta cuando
    // metodoPago == 'Tarjeta' (ver carrito_provider/_selectorComisionTarjeta
    // en RegistrarVentaScreen). El cliente paga totalAPagar + este recargo
    // (ver VentaModel.totalConRecargo), pero totalAPagar -y por lo tanto
    // subtotal/impuesto/utilidad en todos los reportes- se guarda SIEMPRE
    // limpio, sin el recargo mezclado: el recargo es solo un traslado del
    // costo de procesamiento de la tarjeta, no ingreso real del negocio.
    double porcentajeTarjeta = 0,
    double montoRecargoTarjeta = 0,
  }) async {
    final claveContador = _claveContador(tipoDocumento);
    final contadorRef = _colContadores.doc(claveContador);
    final ventaRef = _colVentas.doc();
    // Los servicios (esServicio) nunca controlan stock, sin importar su
    // categoría: a diferencia del sistema viejo, que lo inferia de una
    // categoría mágica, acá es un campo explícito del producto.
    final itemsADescontar = items.where((i) => !i.reembasado && !i.esServicio && !categoriasSinControlStock.contains(i.idCategoria)).toList();

    late String numeroDocumento;
    late Map<ItemVentaModel, double> costosFifo;

    // Timeout corto (el default del SDK es 30s): en cajas con internet
    // lento/intermitente es mejor que el cajero vea rápido que falló y
    // pueda reintentar, a que la pantalla quede "cargando" media hora.
    await _db.runTransaction((transaction) async {
      // Todas las lecturas de la transacción (contador, stock de cada
      // producto, y los lotes de costo de cada producto distinto) se
      // disparan juntas, en vez de esperar unas antes de lanzar las otras:
      // eso ahorra idas y vueltas completas a Firestore en cada venta, que
      // es justo lo que la hacía sentir lenta (sobre todo en cajas con
      // internet móvil) — tiene que sentirse instantánea. Los lotes se leen
      // con una consulta simple (no transaccional, ver consultarLotes) que
      // no depende de nada más, así que se lanza en paralelo con el resto
      // en vez de esperar a que terminen el contador y el stock primero.
      final idsProductoUnicos = itemsADescontar.map((i) => i.idProducto).toSet().toList();
      final futureResultados = Future.wait([
        transaction.get(contadorRef),
        ...itemsADescontar.map((item) => transaction.get(_db.collection('productos').doc(item.idProducto))),
      ]);
      final futureLotes = Future.wait(idsProductoUnicos.map((id) => _lotes.consultarLotes(id)));

      final resultados = await futureResultados;
      final contadorSnap = resultados[0];
      final snapsStock = resultados.sublist(1);

      final actual = ((contadorSnap.data()?['ultimo'] ?? 0) as num).toInt();
      final nuevo = actual + 1;
      numeroDocumento = _formatearCorrelativo(tipoDocumento, nuevo);

      final stocksActuales = <String, double>{};
      final precioCompraActual = <String, double>{};
      for (var i = 0; i < itemsADescontar.length; i++) {
        final data = snapsStock[i].data();
        stocksActuales[itemsADescontar[i].idProducto] = ((data?['stock'] ?? 0) as num).toDouble();
        precioCompraActual[itemsADescontar[i].idProducto] = ((data?['precioCompra'] ?? 0) as num).toDouble();
      }

      // Costeo FIFO: si el carrito tiene más de una línea del mismo
      // producto, comparten el mismo estado para no contar dos veces la
      // misma capacidad de un lote.
      final queriesLotes = await futureLotes;
      final estadoLotesPorProducto = <String, EstadoLotesProducto>{
        for (var i = 0; i < idsProductoUnicos.length; i++) idsProductoUnicos[i]: _lotes.inicializarEstado(queriesLotes[i]),
      };
      costosFifo = <ItemVentaModel, double>{};
      for (final item in itemsADescontar) {
        final estado = estadoLotesPorProducto[item.idProducto]!;
        final costoFallback = precioCompraActual[item.idProducto] ?? item.precioCompraUsado;
        costosFifo[item] = _lotes.consumir(estado, item.cantidad, costoFallback: costoFallback);
      }

      transaction.set(contadorRef, {'ultimo': nuevo}, SetOptions(merge: true));

      transaction.set(ventaRef, {
        'tipoDocumento': tipoDocumento,
        'numeroDocumento': numeroDocumento,
        'documentoCliente': documentoCliente,
        'nombreCliente': nombreCliente,
        'metodoPago': metodoPago,
        'montoPago': montoPago,
        'montoCambio': montoCambio,
        'pagosMixtos': PagoDetalle.listaToMaps(pagosMixtos),
        'subtotal': subtotal,
        'impuesto': impuesto,
        'totalAPagar': totalAPagar,
        'condicion': condicion,
        'fechaVencimiento': fechaVencimiento != null ? Timestamp.fromDate(fechaVencimiento) : null,
        // 'fechaRegistro' es la fecha de negocio (el cajero la puede elegir
        // con el selector de fecha, para atrasar una factura, por ejemplo),
        // no necesariamente cuándo se creó de verdad el registro. 'creadoEn'
        // sí es siempre el momento real, puesto por el servidor: se usa
        // para ordenar el Reporte de Ventas por orden de creación (ver
        // ReporteRepository.obtenerReporteVentas) sin importar qué fecha de
        // negocio se haya elegido.
        'fechaRegistro': Timestamp.fromDate(fechaRegistro),
        'creadoEn': FieldValue.serverTimestamp(),
        'estado': 'Activa',
        'usuarioRegistro': usuario,
        'cantidadProductos': items.fold<double>(0, (s, i) => s + i.cantidad),
        'oc': oc,
        'regExonerado': regExonerado,
        'regSag': regSag,
        'descuentoGlobal': descuentoGlobal,
        'pendienteImpresion': false,
        'porcentajeTarjeta': metodoPago == 'Tarjeta' ? porcentajeTarjeta : 0,
        'montoRecargoTarjeta': metodoPago == 'Tarjeta' ? montoRecargoTarjeta : 0,
      });

      for (final item in items) {
        final itemRef = ventaRef.collection('detalle').doc();
        final costoReal = costosFifo[item];
        final itemAGuardar = costoReal != null ? item.copyWith(precioCompraUsado: costoReal) : item;
        // 'fecha' permite consultar el detalle de todas las ventas de un
        // rango con una sola query (collectionGroup) en vez de tener que
        // leer la subcolección de cada venta una por una.
        transaction.set(itemRef, {...itemAGuardar.toMap(), 'fecha': Timestamp.fromDate(fechaRegistro)});
      }

      if (condicion == 'Credito') {
        transaction.set(_colVentasCredito.doc(ventaRef.id), {
          'documentoCliente': documentoCliente.isEmpty ? 'N/A' : documentoCliente,
          'nombreCliente': nombreCliente,
          'numeroDocumento': numeroDocumento,
          'montoTotal': totalAPagar,
          'saldoPendiente': totalAPagar,
          'fechaRegistro': Timestamp.fromDate(fechaRegistro),
          'fechaVencimiento': Timestamp.fromDate(fechaVencimiento ?? fechaRegistro),
        });
      }

      for (final item in itemsADescontar) {
        final ref = _db.collection('productos').doc(item.idProducto);
        final stockActual = stocksActuales[item.idProducto] ?? 0;
        // Nunca queda en negativo: si ya estaba en 0 (por ejemplo, se vendió
        // a propósito sin existencia disponible) el piso es 0, no un número
        // negativo que después confunda los reportes de inventario.
        final stockNuevo = (stockActual - item.cantidad) < 0 ? 0.0 : stockActual - item.cantidad;
        transaction.update(ref, {'stock': stockNuevo});
        final historialRef = ref.collection('historial').doc();
        transaction.set(historialRef, {
          'stockAnterior': stockActual,
          'stockNuevo': stockNuevo,
          'usuario': usuario,
          'motivo': 'Venta $numeroDocumento',
          'fecha': FieldValue.serverTimestamp(),
        });
      }

      for (final estado in estadoLotesPorProducto.values) {
        _lotes.aplicarEstado(transaction, estado);
      }

      // Historial de precio de venta por producto: no aplica a cotizaciones,
      // que todavía no son una venta concretada.
      final aplicaIsv = tipoDocumento == 'Factura' || tipoDocumento == 'Boleta';
      if (tipoDocumento != 'Cotizacion') {
        for (final item in items) {
          final ref = _db.collection('productos').doc(item.idProducto);
          final precioBase = item.precioVenta * (1 - item.descuentoPorcentaje / 100);
          final precioFinal = redondearMoneda(aplicaIsv ? precioBase * 1.15 : precioBase);
          final historialVentaRef = ref.collection('historialVentas').doc();
          transaction.set(historialVentaRef, {
            'idVenta': ventaRef.id,
            'precioVenta': precioFinal,
            'precioUnitario': item.precioVenta,
            'descuentoPorcentaje': item.descuentoPorcentaje,
            'cantidad': item.cantidad,
            'tipoDocumento': tipoDocumento,
            'numeroDocumento': numeroDocumento,
            'cliente': nombreCliente,
            'usuario': usuario,
            'fecha': FieldValue.serverTimestamp(),
          });
        }
      }
    }, timeout: const Duration(seconds: 12));

    return VentaModel(
      id: ventaRef.id,
      tipoDocumento: tipoDocumento,
      numeroDocumento: numeroDocumento,
      documentoCliente: documentoCliente,
      nombreCliente: nombreCliente,
      metodoPago: metodoPago,
      montoPago: montoPago,
      montoCambio: montoCambio,
      pagosMixtos: pagosMixtos,
      subtotal: subtotal,
      impuesto: impuesto,
      totalAPagar: totalAPagar,
      condicion: condicion,
      fechaVencimiento: fechaVencimiento,
      fechaRegistro: fechaRegistro,
      estado: 'Activa',
      usuarioRegistro: usuario,
      cantidadProductos: items.fold<double>(0, (s, i) => s + i.cantidad),
      oc: oc,
      regExonerado: regExonerado,
      regSag: regSag,
      descuentoGlobal: descuentoGlobal,
      detalle: items.map((item) {
        final costoReal = costosFifo[item];
        return costoReal != null ? item.copyWith(precioCompraUsado: costoReal) : item;
      }).toList(),
      porcentajeTarjeta: metodoPago == 'Tarjeta' ? porcentajeTarjeta : 0,
      montoRecargoTarjeta: metodoPago == 'Tarjeta' ? montoRecargoTarjeta : 0,
    );
  }

  // Best-effort: es solo una bandera de conveniencia para ubicar después
  // ventas sin imprimir, así que si el documento ya no existe (por ejemplo,
  // una venta vieja que quedó en el caché local de un dispositivo después de
  // vaciar la base de datos) no debe reventar con un error feo en pantalla.
  Future<void> marcarPendienteImpresion(String id, bool valor) async {
    try {
      await _colVentas.doc(id).update({'pendienteImpresion': valor});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found' && e.code != 'invalid-argument') rethrow;
    }
  }

  // Best-effort, mismo criterio que marcarPendienteImpresion. [esCopia]
  // viaja junto con la solicitud para que la PC sepa si esta reimpresión en
  // particular debe salir como "copia" u "original" (ver
  // DetalleVentaScreen._reimprimir y ImpresionEnVivoService). Se deja en
  // null (default) para una venta recién confirmada, que no tiene una
  // elección explícita de original/copia — ver VentaModel.
  // solicitudImpresionEsCopia.
  Future<void> marcarSolicitudImpresionEnVivo(String id, bool valor, {bool? esCopia}) async {
    try {
      await _colVentas.doc(id).update({'solicitudImpresionEnVivo': valor, 'solicitudImpresionEsCopia': esCopia});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found' && e.code != 'invalid-argument') rethrow;
    }
  }

  /// Ventas pendientes de impresión que además le están pidiendo a la PC
  /// principal que la imprima automáticamente apenas la detecte (ver
  /// AppShell). Sin `orderBy` por el mismo motivo que
  /// obtenerVentasPendientesImpresion.
  Stream<List<VentaModel>> obtenerVentasConSolicitudImpresionEnVivo() {
    return _colVentas.where('solicitudImpresionEnVivo', isEqualTo: true).snapshots().map((snap) {
      return snap.docs.map((d) => VentaModel.fromMap(d.id, d.data(), const [])).toList();
    });
  }

  /// Arma un [VentaModel] a partir del JSON "crudo" que devuelven las Cloud
  /// Functions ventaPorId/ventasPorNumero (ver functions/index.js,
  /// serializarVentaCruda): mismo shape que un documento de Firestore leído
  /// directo (mismos nombres de campo, Timestamp reconstruidos por
  /// [revivirTimestamps]), así que se puede pasar tal cual al mismo
  /// `VentaModel.fromMap` que ya usa el resto del repositorio.
  VentaModel _ventaDesdeJsonCrudo(Map<String, dynamic> json) {
    final revivido = revivirTimestamps(json) as Map<String, dynamic>;
    final detalle = (revivido['detalle'] as List).cast<Map<String, dynamic>>();
    final items = detalle.map((d) => ItemVentaModel.fromMap(d)).toList();
    return VentaModel.fromMap(revivido['id'] as String, revivido, items);
  }

  /// Trae una venta con su detalle en una sola llamada a la Cloud Function
  /// `ventaPorId` (ver functions/index.js): antes eran 2 consultas directas
  /// a Firestore desde el dispositivo, cada una pagando el viaje completo de
  /// ida y vuelta por la red del cajero; ahora es 1 sola llamada y esas 2
  /// lecturas ocurren del lado del servidor, en la misma red de Google. Si
  /// la función no responde (sin internet, la primera vez que se despliega,
  /// etc.) cae al camino directo de siempre, para que la pantalla de
  /// Detalle de Venta nunca quede sin poder buscar.
  Future<VentaModel?> obtenerVentaPorId(String id) async {
    try {
      final resultado = await FuncionesNube.llamar('ventaPorId', {'id': id}, timeout: const Duration(seconds: 8));
      final venta = (resultado as Map<String, dynamic>)['venta'];
      return venta == null ? null : _ventaDesdeJsonCrudo(venta as Map<String, dynamic>);
    } catch (_) {
      return _obtenerVentaPorIdLocal(id);
    }
  }

  Future<VentaModel?> _obtenerVentaPorIdLocal(String id) async {
    // Las dos lecturas no dependen una de la otra (el id ya se conoce de
    // entrada), así que se disparan juntas en vez de esperar el documento
    // antes de recién ahí pedir el detalle: ahorra una vuelta completa a
    // Firestore.
    final futureVenta = _colVentas.doc(id).get();
    final futureDetalle = _colVentas.doc(id).collection('detalle').get();
    final snap = await futureVenta;
    if (!snap.exists) return null;
    final detalleSnap = await futureDetalle;
    final items = detalleSnap.docs.map((d) => ItemVentaModel.fromMap(d.data())).toList();
    return VentaModel.fromMap(id, snap.data()!, items);
  }

  /// Solo el detalle (items) de una venta, sin volver a leer el documento
  /// principal: para cuando ya se tiene el resto de la venta por otro lado
  /// (por ejemplo, de un stream) y solo hace falta completarla con el
  /// detalle antes de imprimir — ver VentaModel.copyWith y AppShell.
  Future<List<ItemVentaModel>> obtenerDetalleVenta(String id) async {
    final detalleSnap = await _colVentas.doc(id).collection('detalle').get();
    return detalleSnap.docs.map((d) => ItemVentaModel.fromMap(d.data())).toList();
  }

  Future<VentaModel?> obtenerVentaPorNumeroDocumento(String numeroDocumento) async {
    final texto = numeroDocumento.trim();
    if (texto.isEmpty) return null;
    final query = await _colVentas.where('numeroDocumento', isEqualTo: texto).limit(1).get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final detalleSnap = await doc.reference.collection('detalle').get();
    final items = detalleSnap.docs.map((d) => ItemVentaModel.fromMap(d.data())).toList();
    return VentaModel.fromMap(doc.id, doc.data(), items);
  }

  /// Busca ventas por número de documento sin que el usuario tenga que
  /// escribir los ceros de relleno (por ejemplo "5" en vez de "00000005"):
  /// arma las variantes rellenadas posibles -8 dígitos para Factura/Boleta/
  /// Cotización, 5 para Venta Sin Facturar (ver _formatearCorrelativo)- y
  /// las busca todas. Si se indica [tipoDocumento] filtra además por ese
  /// tipo: hace falta porque Factura/Boleta y Cotización usan contadores
  /// separados pero el mismo relleno de 8 dígitos, así que un mismo número
  /// bien podría coincidir con una Factura Y una Cotización a la vez. Cada
  /// candidato se busca con una consulta de igualdad simple (no `whereIn`)
  /// para no depender de un índice compuesto.
  /// Igual idea que [obtenerVentaPorId]: la Cloud Function `ventasPorNumero`
  /// arma del lado del servidor las variantes con ceros de relleno, busca
  /// cada una y trae el detalle de cada coincidencia -antes eran hasta 5
  /// consultas más una por cada resultado encontrado, todas desde el
  /// dispositivo-. Si falla, cae al camino directo de siempre.
  Future<List<VentaModel>> buscarVentasPorNumeroDocumento(String texto, {String? tipoDocumento}) async {
    try {
      final resultado = await FuncionesNube.llamar('ventasPorNumero', {
        'texto': texto,
        if (tipoDocumento != null && tipoDocumento.isNotEmpty) 'tipoDocumento': tipoDocumento,
      });
      final ventas = (resultado as Map<String, dynamic>)['ventas'] as List;
      return ventas.map((v) => _ventaDesdeJsonCrudo(v as Map<String, dynamic>)).toList();
    } catch (_) {
      return _buscarVentasPorNumeroDocumentoLocal(texto, tipoDocumento: tipoDocumento);
    }
  }

  Future<List<VentaModel>> _buscarVentasPorNumeroDocumentoLocal(String texto, {String? tipoDocumento}) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return [];

    final candidatos = <String>{limpio};
    if (RegExp(r'^\d+$').hasMatch(limpio)) {
      candidatos.add(limpio.padLeft(8, '0'));
      candidatos.add(limpio.padLeft(5, '0'));
      candidatos.add(limpio.padLeft(4, '0'));
    }

    final snaps = await Future.wait(candidatos.map((c) => _colVentas.where('numeroDocumento', isEqualTo: c).get()));
    final docs = snaps.expand((s) => s.docs).toList();

    final resultados = <VentaModel>[];
    for (final doc in docs) {
      if (tipoDocumento != null && tipoDocumento.isNotEmpty && doc.data()['tipoDocumento'] != tipoDocumento) continue;
      final detalleSnap = await doc.reference.collection('detalle').get();
      final items = detalleSnap.docs.map((d) => ItemVentaModel.fromMap(d.data())).toList();
      resultados.add(VentaModel.fromMap(doc.id, doc.data(), items));
    }
    resultados.sort((a, b) => (b.fechaRegistro ?? DateTime(0)).compareTo(a.fechaRegistro ?? DateTime(0)));
    return resultados;
  }

  /// Anula una venta: la marca como 'Anulada', repone al inventario el stock
  /// de los productos que no fueron reembasados, y si era una venta a
  /// crédito sin abonos, elimina su registro en `ventasCredito`.
  ///
  /// Con tope de tiempo: ninguna anulación puede quedar cargando para
  /// siempre. En web el SDK de Firestore ignora el `timeout` de las
  /// transacciones y las lecturas simples no tienen ninguno, así que si la
  /// conexión se traba el spinner quedaba eterno. Si vence el tiempo, la
  /// anulación puede haberse completado igual: la pantalla vuelve a leer la
  /// venta para mostrar el estado real.
  Future<void> anularVenta({
    required String id,
    required String usuario,
    String motivo = '',
  }) {
    return _anularVentaSinLimite(id: id, usuario: usuario, motivo: motivo).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('anularVenta'),
    );
  }

  Future<void> _anularVentaSinLimite({
    required String id,
    required String usuario,
    String motivo = '',
  }) async {
    // Las tres lecturas no dependen entre sí (el id ya se conoce): juntas
    // cuestan una sola ida y vuelta en vez de dos o tres seguidas.
    final (ventaSnap, detalleSnap, creditoSnap) = await (
      _colVentas.doc(id).get(),
      _colVentas.doc(id).collection('detalle').get(),
      _colVentasCredito.doc(id).get(),
    ).wait;
    if (!ventaSnap.exists) {
      throw Exception('No se encontró la venta');
    }
    final data = ventaSnap.data()!;
    if (data['estado'] == 'Anulada') {
      throw Exception('Esta venta ya está anulada');
    }
    final condicion = data['condicion'] as String? ?? '';
    final numeroDocumento = data['numeroDocumento'] as String? ?? '';

    final items = detalleSnap.docs.map((d) => ItemVentaModel.fromMap(d.data())).toList();

    var creditoExiste = false;
    if (condicion == 'Credito') {
      if (creditoSnap.exists) {
        creditoExiste = true;
        final montoTotal = ((creditoSnap.data()?['montoTotal'] ?? 0) as num).toDouble();
        final saldoPendiente = ((creditoSnap.data()?['saldoPendiente'] ?? 0) as num).toDouble();
        if (saldoPendiente < montoTotal) {
          throw Exception('No se puede anular: esta venta a crédito ya tiene abonos registrados');
        }
      }
    }

    final idsCategoriaRestaurar = items.map((i) => i.idCategoria).where((id) => id.isNotEmpty).toSet();
    final categoriasSinControlStockRestaurar = <String>{};
    if (idsCategoriaRestaurar.isNotEmpty) {
      final snapsCategorias = await Future.wait(idsCategoriaRestaurar.map((id) => _db.collection('categorias').doc(id).get()));
      for (final snap in snapsCategorias) {
        if (snap.exists && (snap.data()?['controlaStock'] ?? true) == false) {
          categoriasSinControlStockRestaurar.add(snap.id);
        }
      }
    }
    final itemsARestaurar = items.where((i) => !i.reembasado && !categoriasSinControlStockRestaurar.contains(i.idCategoria)).toList();

    // Si la venta se borró del servidor pero seguía "existiendo" en el
    // caché local (por ejemplo, después de vaciar la base de datos desde
    // otro dispositivo), la comprobación de arriba pasa igual porque lee del
    // caché, y recién acá, al hablar con el servidor de verdad, aparece el
    // error. Se traduce a un mensaje claro en vez de mostrar el texto crudo
    // de Firestore.
    try {
      await _anularVentaTransaccion(
        id: id,
        usuario: usuario,
        motivo: motivo,
        numeroDocumento: numeroDocumento,
        creditoExiste: creditoExiste,
        itemsARestaurar: itemsARestaurar,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'not-found' || e.code == 'invalid-argument') {
        throw Exception('No se pudo anular: la venta ya no existe en el servidor (puede que se haya borrado desde otro dispositivo)');
      }
      rethrow;
    }
  }

  Future<void> _anularVentaTransaccion({
    required String id,
    required String usuario,
    required String motivo,
    required String numeroDocumento,
    required bool creditoExiste,
    required List<ItemVentaModel> itemsARestaurar,
  }) async {
    await _db.runTransaction((transaction) async {
      final stocksActuales = <String, double>{};
      final snapsStock = await Future.wait(
        itemsARestaurar.map((item) => transaction.get(_db.collection('productos').doc(item.idProducto))),
      );
      for (var i = 0; i < itemsARestaurar.length; i++) {
        stocksActuales[itemsARestaurar[i].idProducto] = ((snapsStock[i].data()?['stock'] ?? 0) as num).toDouble();
      }

      transaction.update(_colVentas.doc(id), {
        'estado': 'Anulada',
        'usuarioAnulacion': usuario,
        'motivoAnulacion': motivo,
        'fechaAnulacion': FieldValue.serverTimestamp(),
      });

      if (creditoExiste) {
        transaction.delete(_colVentasCredito.doc(id));
      }

      for (final item in itemsARestaurar) {
        final ref = _db.collection('productos').doc(item.idProducto);
        final stockActual = stocksActuales[item.idProducto] ?? 0;
        final stockNuevo = stockActual + item.cantidad;
        transaction.update(ref, {'stock': stockNuevo});
        final historialRef = ref.collection('historial').doc();
        transaction.set(historialRef, {
          'stockAnterior': stockActual,
          'stockNuevo': stockNuevo,
          'usuario': usuario,
          'motivo': 'Anulación de venta $numeroDocumento',
          'fecha': FieldValue.serverTimestamp(),
        });

        // El stock repuesto vuelve como un lote nuevo, al costo real que
        // tenía esa venta (ya sea el costo de fábrica o el ya calculado por
        // FIFO). Es más simple y igual de correcto hacia adelante que tratar
        // de deshacer el consumo exacto de lotes de la venta original.
        _lotes.crearLote(
          transaction,
          item.idProducto,
          cantidad: item.cantidad,
          costoUnitario: item.precioCompraUsado,
          fecha: DateTime.now(),
          origen: 'ajuste',
        );
      }
    }, timeout: const Duration(seconds: 12));
  }

  Stream<List<VentaEnEsperaModel>> obtenerVentasEnEspera() {
    return _colEspera.orderBy('fecha', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => VentaEnEsperaModel.fromMap(d.id, d.data())).toList();
    });
  }

  /// Ventas guardadas pero sin imprimir (típicamente hechas desde el
  /// celular sin la impresora a mano). Sin `orderBy` a propósito -filtrar
  /// por `pendienteImpresion` y además ordenar por fecha pediría un índice
  /// compuesto en Firestore- así que el orden se resuelve acá en memoria.
  Stream<List<VentaModel>> obtenerVentasPendientesImpresion() {
    return _colVentas.where('pendienteImpresion', isEqualTo: true).snapshots().map((snap) {
      final ventas = snap.docs.map((d) => VentaModel.fromMap(d.id, d.data(), const [])).toList();
      ventas.sort((a, b) => (b.fechaRegistro ?? DateTime(0)).compareTo(a.fechaRegistro ?? DateTime(0)));
      return ventas;
    });
  }

  Future<String> guardarVentaEnEspera(VentaEnEsperaModel sesion) async {
    final ref = await _colEspera.add(sesion.toMap());
    return ref.id;
  }

  Future<void> actualizarVentaEnEspera(String id, VentaEnEsperaModel sesion) async {
    await _colEspera.doc(id).update(sesion.toMap());
  }

  Future<void> eliminarVentaEnEspera(String id) async {
    await _colEspera.doc(id).delete();
  }
}
