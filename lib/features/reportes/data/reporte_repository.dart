import 'package:cloud_firestore/cloud_firestore.dart';
import 'reporte_venta_model.dart';
import 'reporte_compra_model.dart';
import '../../../core/services/funciones_nube.dart';

const _tamanoPaginaReporte = 150;

/// Una tanda de ventas/compras del Reporte de Ventas/Compras, con el cursor
/// para pedir la siguiente (ver [ReporteRepository.obtenerPaginaVentas]).
class PaginaReporteVentas {
  final List<ReporteVentaModel> ventas;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hayMas;
  PaginaReporteVentas({required this.ventas, required this.cursor, required this.hayMas});
}

class PaginaReporteCompras {
  final List<ReporteCompraModel> compras;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hayMas;
  PaginaReporteCompras({required this.compras, required this.cursor, required this.hayMas});
}

/// Total exacto (activas, sin cotizaciones) de un rango de fechas, sin tener
/// que bajar los documentos: lo resuelve la Cloud Function `totalReporteVentas`
/// con una agregación de Firestore. Se pide aparte de [obtenerPaginaVentas]
/// para que la pantalla pueda mostrar el total correcto al instante mientras
/// la lista todavía se sigue cargando de a tandas en segundo plano.
class TotalReporte {
  final double total;
  final int cantidad;
  const TotalReporte({required this.total, required this.cantidad});
}

class ReporteRepository {
  final _db = FirebaseFirestore.instance;

  /// Trae una tanda de ventas del rango (ordenadas por 'fechaRegistro', el
  /// mismo campo del filtro de rango, para poder paginar con
  /// `startAfterDocument` sin pedir un índice compuesto extra). Antes
  /// [obtenerReporteVentas] traía TODO el rango de una sola vez -con 2 meses
  /// o más de historial, eso significa bajar cientos o miles de documentos
  /// completos por la red real del que está mirando el reporte, y ahí es
  /// donde se sentía la demora-. Con esto, la pantalla pinta la primera
  /// tanda casi al instante sin importar qué tan largo sea el rango, y seguí
  /// pidiendo el resto de a tandas en segundo plano (ver
  /// ReporteVentasScreen._seguirCargandoEnFondo).
  Future<PaginaReporteVentas> obtenerPaginaVentas(
    DateTime inicio,
    DateTime finInclusive, {
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int tamano = _tamanoPaginaReporte,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('ventas')
        .where('fechaRegistro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaRegistro', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .orderBy('fechaRegistro', descending: true)
        .limit(tamano);
    if (despuesDe != null) query = query.startAfterDocument(despuesDe);
    final snap = await query.get();
    final ventas = snap.docs.map((d) => ReporteVentaModel.fromMap(d.id, d.data())).toList();
    return PaginaReporteVentas(
      ventas: ventas,
      cursor: snap.docs.isEmpty ? despuesDe : snap.docs.last,
      hayMas: snap.docs.length == tamano,
    );
  }

  Future<PaginaReporteCompras> obtenerPaginaCompras(
    DateTime inicio,
    DateTime finInclusive, {
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int tamano = _tamanoPaginaReporte,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('compras')
        .where('fechaRegistro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaRegistro', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .orderBy('fechaRegistro', descending: true)
        .limit(tamano);
    if (despuesDe != null) query = query.startAfterDocument(despuesDe);
    final snap = await query.get();
    final compras = snap.docs.map((d) => ReporteCompraModel.fromMap(d.id, d.data())).toList();
    return PaginaReporteCompras(
      compras: compras,
      cursor: snap.docs.isEmpty ? despuesDe : snap.docs.last,
      hayMas: snap.docs.length == tamano,
    );
  }

  /// Total real de ventas activas y facturables del rango (sin cotizaciones,
  /// sin anuladas), vía la Cloud Function `totalReporteVentas`
  /// (agregación de Firestore, no baja documentos). Si falla, se calcula
  /// localmente con el método de siempre.
  Future<TotalReporte> obtenerTotalVentas(DateTime inicio, DateTime finInclusive) async {
    try {
      final resultado = await FuncionesNube.llamar('totalReporteVentas', {
        'inicioMillis': inicio.millisecondsSinceEpoch,
        'finMillis': finInclusive.millisecondsSinceEpoch,
      }) as Map<String, dynamic>;
      return TotalReporte(total: numDesde(resultado['total']), cantidad: (resultado['cantidad'] as num).toInt());
    } catch (_) {
      final ventas = await obtenerReporteVentas(inicio, finInclusive);
      final activas = ventas.where((v) => v.esActiva && !v.esCotizacion).toList();
      return TotalReporte(total: activas.fold<double>(0, (s, v) => s + v.totalAPagar), cantidad: activas.length);
    }
  }

  Future<TotalReporte> obtenerTotalCompras(DateTime inicio, DateTime finInclusive) async {
    try {
      final resultado = await FuncionesNube.llamar('totalReporteCompras', {
        'inicioMillis': inicio.millisecondsSinceEpoch,
        'finMillis': finInclusive.millisecondsSinceEpoch,
      }) as Map<String, dynamic>;
      return TotalReporte(total: numDesde(resultado['total']), cantidad: (resultado['cantidad'] as num).toInt());
    } catch (_) {
      final compras = await obtenerReporteCompras(inicio, finInclusive);
      final activas = compras.where((c) => c.esActiva).toList();
      return TotalReporte(total: activas.fold<double>(0, (s, c) => s + c.montoTotal), cantidad: activas.length);
    }
  }

  Future<List<ReporteVentaModel>> obtenerReporteVentas(DateTime inicio, DateTime finInclusive) async {
    // El filtro de rango tiene que ir por 'fechaRegistro' (Firestore exige
    // que el primer orderBy coincida con el campo del filtro de rango), así
    // que no se puede pedirle a la propia consulta que además ordene por
    // 'creadoEn'. Se reordena acá, ya en memoria, por creadoEn descendente
    // (orden real de creación, sin importar qué fecha de negocio se haya
    // elegido para cada venta) — con fechaRegistro como respaldo en ventas
    // viejas que no tienen 'creadoEn' guardado.
    final snap = await _db
        .collection('ventas')
        .where('fechaRegistro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaRegistro', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .orderBy('fechaRegistro', descending: true)
        .get();
    final lista = snap.docs.map((d) => ReporteVentaModel.fromMap(d.id, d.data())).toList();
    lista.sort((a, b) {
      final claveA = a.creadoEn ?? a.fechaRegistro ?? DateTime(0);
      final claveB = b.creadoEn ?? b.fechaRegistro ?? DateTime(0);
      return claveB.compareTo(claveA);
    });
    return lista;
  }

  Future<List<ReporteCompraModel>> obtenerReporteCompras(DateTime inicio, DateTime finInclusive, {String? idProveedor}) async {
    Query<Map<String, dynamic>> query = _db
        .collection('compras')
        .where('fechaRegistro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaRegistro', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive));
    final snap = await query.orderBy('fechaRegistro', descending: true).get();
    var lista = snap.docs.map((d) => ReporteCompraModel.fromMap(d.id, d.data())).toList();
    if (idProveedor != null && idProveedor.isNotEmpty) {
      lista = lista.where((c) => c.idProveedor == idProveedor).toList();
    }
    return lista;
  }
}
