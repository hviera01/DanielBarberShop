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

class ComisionRepository {
  final _db = FirebaseFirestore.instance;
  final _reporteRepository = ReporteRepository();

  /// Trae, en una sola consulta de collectionGroup, todas las líneas de
  /// detalle del periodo (igual que ReporteFinancieroRepository), y las junta
  /// con el estado/número de la venta a la que pertenecen para poder excluir
  /// ventas anuladas y cotizaciones.
  Future<List<ItemVentaModel>> _lineasActivasDelPeriodo(DateTime inicio, DateTime finInclusive) async {
    final ventas = await _reporteRepository.obtenerReporteVentas(inicio, finInclusive);
    final idsActivos = {for (final v in ventas.where((v) => v.esActiva && !v.esCotizacion)) v.id: true};

    final snap = await _db
        .collectionGroup('detalle')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .get();

    final lineas = <ItemVentaModel>[];
    for (final doc in snap.docs) {
      final docPadre = doc.reference.parent.parent;
      if (docPadre == null) continue;
      if (docPadre.parent.id != 'ventas') continue;
      if (!idsActivos.containsKey(docPadre.id)) continue;
      lineas.add(ItemVentaModel.fromMap(doc.data()));
    }
    return lineas;
  }

  Future<List<ComisionCorteBarbero>> obtenerComisionCortes(DateTime inicio, DateTime finInclusive, {String? idBarbero}) async {
    final lineas = await _lineasActivasDelPeriodo(inicio, finInclusive);
    final cortes = lineas.where((i) => i.esServicio && i.idBarbero.isNotEmpty).where((i) => idBarbero == null || i.idBarbero == idBarbero);

    final porBarbero = <String, ComisionCorteBarbero>{};
    for (final item in cortes) {
      final actual = porBarbero[item.idBarbero];
      final comisionLinea = item.subtotal * (item.pctComisionBarbero / 100);
      if (actual == null) {
        porBarbero[item.idBarbero] = ComisionCorteBarbero(
          idBarbero: item.idBarbero,
          nombreBarbero: item.nombreBarbero,
          cantidadCortes: item.cantidad,
          montoTotal: item.subtotal,
          comisionTotal: comisionLinea,
        );
      } else {
        porBarbero[item.idBarbero] = ComisionCorteBarbero(
          idBarbero: actual.idBarbero,
          nombreBarbero: actual.nombreBarbero,
          cantidadCortes: actual.cantidadCortes + item.cantidad,
          montoTotal: actual.montoTotal + item.subtotal,
          comisionTotal: actual.comisionTotal + comisionLinea,
        );
      }
    }
    final lista = porBarbero.values.toList();
    lista.sort((a, b) => b.montoTotal.compareTo(a.montoTotal));
    return lista;
  }

  Future<List<ComisionProductoVendedor>> obtenerComisionProductos(DateTime inicio, DateTime finInclusive, {String? tipo, String? id}) async {
    final lineas = await _lineasActivasDelPeriodo(inicio, finInclusive);
    final productos = lineas.where((i) => !i.esServicio && i.vendidoPorTipo != 'N/A' && i.vendidoPorId.isNotEmpty).where((i) {
      if (tipo != null && i.vendidoPorTipo != tipo) return false;
      if (id != null && i.vendidoPorId != id) return false;
      return true;
    });

    final cantidadPorClave = <String, double>{};
    final montoPorClave = <String, double>{};
    final infoPorClave = <String, (String tipo, String id, String nombre)>{};
    for (final item in productos) {
      final clave = '${item.vendidoPorTipo}:${item.vendidoPorId}';
      cantidadPorClave[clave] = (cantidadPorClave[clave] ?? 0) + item.cantidad;
      montoPorClave[clave] = (montoPorClave[clave] ?? 0) + item.subtotal;
      infoPorClave[clave] = (item.vendidoPorTipo, item.vendidoPorId, item.vendidoPorNombre);
    }

    final lista = cantidadPorClave.keys.map((clave) {
      final info = infoPorClave[clave]!;
      final cantidad = cantidadPorClave[clave]!;
      final monto = montoPorClave[clave]!;
      final tasa = tasaComisionProducto(cantidad);
      return ComisionProductoVendedor(
        tipo: info.$1,
        id: info.$2,
        nombre: info.$3,
        cantidadProductos: cantidad,
        montoTotal: monto,
        tasa: tasa,
        comisionTotal: monto * tasa,
      );
    }).toList();
    lista.sort((a, b) => b.montoTotal.compareTo(a.montoTotal));
    return lista;
  }
}
