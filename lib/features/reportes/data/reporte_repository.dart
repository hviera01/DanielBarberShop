import 'package:cloud_firestore/cloud_firestore.dart';
import 'reporte_venta_model.dart';
import 'reporte_compra_model.dart';

class ReporteRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<ReporteVentaModel>> obtenerReporteVentas(DateTime inicio, DateTime finInclusive) async {
    final snap = await _db
        .collection('ventas')
        .where('fechaRegistro', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaRegistro', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .orderBy('fechaRegistro', descending: true)
        .get();
    return snap.docs.map((d) => ReporteVentaModel.fromMap(d.id, d.data())).toList();
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
