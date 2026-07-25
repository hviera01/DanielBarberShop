import 'package:cloud_firestore/cloud_firestore.dart';
import 'comision_model.dart';
import '../../ventas/data/item_venta_model.dart';
import '../../reportes/data/reporte_repository.dart';

/// Tramos de comisión por venta de producto físico según volumen del
/// periodo: a diferencia del sistema viejo (que los traía hardcodeados
/// 7%/10% y los calculaba de forma algo inconsistente entre el detalle y el
/// resumen), acá quedan como constantes únicas en un solo lugar.
const double tasaComisionProductoBase = 0.07;
const double tasaComisionProductoAlta = 0.10;
const double umbralComisionProductoAlta = 30;

double tasaComisionProducto(double cantidadTotal) => cantidadTotal >= umbralComisionProductoAlta ? tasaComisionProductoAlta : tasaComisionProductoBase;

/// Una línea de detalle ya cruzada con los datos de la venta a la que
/// pertenece (número de documento, fecha, cliente): `_lineasActivasDelPeriodo`
/// la arma una sola vez para que tanto `_calcularCortes` como
/// `_calcularProductos` puedan agrupar por lo que necesiten sin perder de
/// vista a qué venta pertenece cada línea (necesario para el drill-down de
/// "Cortes por barbero" -> lista de ventas -> detalle de venta).
class _LineaDetalle {
  final String idVenta;
  final String numeroDocumento;
  final DateTime? fecha;
  final String cliente;
  final ItemVentaModel item;

  _LineaDetalle({required this.idVenta, required this.numeroDocumento, required this.fecha, required this.cliente, required this.item});
}

class ComisionRepository {
  final _db = FirebaseFirestore.instance;
  final _reporteRepository = ReporteRepository();

  /// Trae, en una sola consulta de collectionGroup, todas las líneas de
  /// detalle del periodo (igual que ReporteFinancieroRepository), y las junta
  /// con la venta a la que pertenecen (para excluir anuladas/cotizaciones y
  /// para poder armar el drill-down por venta).
  Future<List<_LineaDetalle>> _lineasActivasDelPeriodo(DateTime inicio, DateTime finInclusive) async {
    // Las dos consultas son independientes (una a 'ventas', otra a la
    // collectionGroup 'detalle') así que se disparan en paralelo en vez de
    // esperar una y luego la otra.
    final ventasFuture = _reporteRepository.obtenerReporteVentas(inicio, finInclusive);
    final detalleFuture = _db
        .collectionGroup('detalle')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .get();

    final ventas = await ventasFuture;
    final activasPorId = {for (final v in ventas.where((v) => v.esActiva && !v.esCotizacion)) v.id: v};
    final snap = await detalleFuture;

    final lineas = <_LineaDetalle>[];
    for (final doc in snap.docs) {
      final docPadre = doc.reference.parent.parent;
      if (docPadre == null) continue;
      if (docPadre.parent.id != 'ventas') continue;
      final venta = activasPorId[docPadre.id];
      if (venta == null) continue;
      lineas.add(_LineaDetalle(
        idVenta: docPadre.id,
        numeroDocumento: venta.numeroDocumento,
        fecha: venta.fechaRegistro,
        cliente: venta.nombreCliente,
        item: ItemVentaModel.fromMap(doc.data()),
      ));
    }
    return lineas;
  }

  /// Trae cortes y productos del mismo periodo en una sola pasada: antes la
  /// pantalla llamaba a [obtenerComisionCortes] y [obtenerComisionProductos]
  /// por separado y cada uno volvía a pedir las líneas del periodo,
  /// duplicando las consultas a Firestore.
  /// [tipoFiltro]/[idFiltro] identifican a la persona elegida en el combo de
  /// la pantalla, que puede ser un barbero o un usuario (para ver si un
  /// usuario que no es barbero vendió productos). Un usuario nunca tiene
  /// cortes propios, así que si el filtro es de tipo 'Usuario' la lista de
  /// cortes queda vacía en vez de mostrar la de todos los barberos.
  Future<({List<ComisionCorteBarbero> cortes, List<ComisionProductoVendedor> productos})> obtenerComisionesDelPeriodo(
    DateTime inicio,
    DateTime finInclusive, {
    String? tipoFiltro,
    String? idFiltro,
  }) async {
    final lineas = await _lineasActivasDelPeriodo(inicio, finInclusive);
    return (
      cortes: tipoFiltro == 'Usuario' ? <ComisionCorteBarbero>[] : _calcularCortes(lineas, idBarbero: tipoFiltro == 'Barbero' ? idFiltro : null),
      productos: _calcularProductos(lineas, tipo: tipoFiltro, id: idFiltro),
    );
  }

  Future<List<ComisionCorteBarbero>> obtenerComisionCortes(DateTime inicio, DateTime finInclusive, {String? idBarbero}) async {
    final lineas = await _lineasActivasDelPeriodo(inicio, finInclusive);
    return _calcularCortes(lineas, idBarbero: idBarbero);
  }

  List<ComisionCorteBarbero> _calcularCortes(List<_LineaDetalle> lineas, {String? idBarbero}) {
    final cortes = lineas.where((l) => l.item.esServicio && l.item.idBarbero.isNotEmpty).where((l) => idBarbero == null || l.item.idBarbero == idBarbero);

    final porBarbero = <String, ComisionCorteBarbero>{};
    for (final linea in cortes) {
      final item = linea.item;
      final actual = porBarbero[item.idBarbero];
      final comisionLinea = item.subtotal * (item.pctComisionBarbero / 100);
      final lineaComision = LineaComisionVenta(
        idVenta: linea.idVenta,
        numeroDocumento: linea.numeroDocumento,
        fecha: linea.fecha,
        cliente: linea.cliente,
        nombreItem: item.nombreProducto,
        monto: item.subtotal,
        comision: comisionLinea,
      );
      if (actual == null) {
        porBarbero[item.idBarbero] = ComisionCorteBarbero(
          idBarbero: item.idBarbero,
          nombreBarbero: item.nombreBarbero,
          cantidadCortes: item.cantidad,
          montoTotal: item.subtotal,
          comisionTotal: comisionLinea,
          lineas: [lineaComision],
        );
      } else {
        porBarbero[item.idBarbero] = ComisionCorteBarbero(
          idBarbero: actual.idBarbero,
          nombreBarbero: actual.nombreBarbero,
          cantidadCortes: actual.cantidadCortes + item.cantidad,
          montoTotal: actual.montoTotal + item.subtotal,
          comisionTotal: actual.comisionTotal + comisionLinea,
          lineas: [...actual.lineas, lineaComision],
        );
      }
    }
    final lista = porBarbero.values.toList();
    lista.sort((a, b) => b.montoTotal.compareTo(a.montoTotal));
    return lista;
  }

  Future<List<ComisionProductoVendedor>> obtenerComisionProductos(DateTime inicio, DateTime finInclusive, {String? tipo, String? id}) async {
    final lineas = await _lineasActivasDelPeriodo(inicio, finInclusive);
    return _calcularProductos(lineas, tipo: tipo, id: id);
  }

  List<ComisionProductoVendedor> _calcularProductos(List<_LineaDetalle> lineasDetalle, {String? tipo, String? id}) {
    final productos = lineasDetalle.where((l) => !l.item.esServicio && l.item.vendidoPorTipo != 'N/A' && l.item.vendidoPorId.isNotEmpty).where((l) {
      if (tipo != null && l.item.vendidoPorTipo != tipo) return false;
      if (id != null && l.item.vendidoPorId != id) return false;
      return true;
    });

    final cantidadPorClave = <String, double>{};
    final montoPorClave = <String, double>{};
    final infoPorClave = <String, (String tipo, String id, String nombre)>{};
    final detallePorClave = <String, List<_LineaDetalle>>{};
    for (final l in productos) {
      final item = l.item;
      final clave = '${item.vendidoPorTipo}:${item.vendidoPorId}';
      cantidadPorClave[clave] = (cantidadPorClave[clave] ?? 0) + item.cantidad;
      montoPorClave[clave] = (montoPorClave[clave] ?? 0) + item.subtotal;
      infoPorClave[clave] = (item.vendidoPorTipo, item.vendidoPorId, item.vendidoPorNombre);
      detallePorClave.putIfAbsent(clave, () => []).add(l);
    }

    final lista = cantidadPorClave.keys.map((clave) {
      final info = infoPorClave[clave]!;
      final cantidad = cantidadPorClave[clave]!;
      final monto = montoPorClave[clave]!;
      final tasa = tasaComisionProducto(cantidad);
      // La comisión por línea se calcula recién acá (no al armar
      // detallePorClave) porque la tasa depende del volumen total del
      // vendedor en el periodo, que solo se conoce una vez sumadas todas
      // sus líneas.
      final lineasComision = detallePorClave[clave]!
          .map((l) => LineaComisionVenta(
                idVenta: l.idVenta,
                numeroDocumento: l.numeroDocumento,
                fecha: l.fecha,
                cliente: l.cliente,
                nombreItem: l.item.nombreProducto,
                monto: l.item.subtotal,
                comision: l.item.subtotal * tasa,
              ))
          .toList();
      return ComisionProductoVendedor(
        tipo: info.$1,
        id: info.$2,
        nombre: info.$3,
        cantidadProductos: cantidad,
        montoTotal: monto,
        tasa: tasa,
        comisionTotal: monto * tasa,
        lineas: lineasComision,
      );
    }).toList();
    lista.sort((a, b) => b.montoTotal.compareTo(a.montoTotal));
    return lista;
  }
}
