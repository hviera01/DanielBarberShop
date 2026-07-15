import 'package:cloud_firestore/cloud_firestore.dart';
import 'compra_credito_model.dart';
import 'abono_compra_model.dart';

class DistribucionAbono {
  final CompraCreditoModel compra;
  final double montoAplicado;
  final double saldoResultante;

  DistribucionAbono({required this.compra, required this.montoAplicado, required this.saldoResultante});
}

class CompraCreditoRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('comprasCredito');

  String _generarNumeroDocumento() {
    final ahora = DateTime.now().millisecondsSinceEpoch.toString();
    return ahora.substring(ahora.length - 8);
  }

  Stream<List<CompraCreditoModel>> obtenerCompras() {
    return _col.orderBy('fechaRegistro', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => CompraCreditoModel.fromMap(d.id, d.data())).toList();
    });
  }

  Stream<List<AbonoCompraModel>> obtenerAbonos(String idCompra) {
    return _col.doc(idCompra).collection('abonosCompra').orderBy('fecha', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => AbonoCompraModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> crearCreditoManual({
    required String idProveedor,
    required String documentoProveedor,
    required String nombreProveedor,
    required String numeroDocumento,
    required String noFactura,
    required double montoTotal,
    required double saldoPendiente,
    required DateTime fechaVencimiento,
  }) async {
    await _col.add({
      'idProveedor': idProveedor,
      'documentoProveedor': documentoProveedor.isEmpty ? 'N/A' : documentoProveedor,
      'nombreProveedor': nombreProveedor,
      'numeroDocumento': numeroDocumento.isEmpty ? _generarNumeroDocumento() : numeroDocumento,
      'noFactura': noFactura,
      'montoTotal': montoTotal,
      'saldoPendiente': saldoPendiente,
      'fechaRegistro': FieldValue.serverTimestamp(),
      'fechaVencimiento': Timestamp.fromDate(fechaVencimiento),
      'manual': true,
    });
  }

  Future<void> registrarAbono({
    required String idCompra,
    required String idProveedor,
    required String nombreProveedor,
    required double saldoAnterior,
    required double montoAbonado,
    required double interes,
    required String metodoPago,
    required String numeroRecibo,
    required String usuario,
  }) async {
    final nuevoSaldo = (saldoAnterior - montoAbonado + interes).clamp(0, double.infinity).toDouble();
    final batch = _db.batch();
    batch.update(_col.doc(idCompra), {'saldoPendiente': nuevoSaldo});
    final abonoRef = _col.doc(idCompra).collection('abonosCompra').doc();
    batch.set(abonoRef, {
      'idCompra': idCompra,
      'idProveedor': idProveedor,
      'nombreProveedor': nombreProveedor,
      'fecha': FieldValue.serverTimestamp(),
      'montoAbonado': montoAbonado,
      'saldoAnterior': saldoAnterior,
      'interes': interes,
      'saldoPendiente': nuevoSaldo,
      'metodoPago': metodoPago,
      'numeroRecibo': numeroRecibo,
      'usuario': usuario,
    });
    await batch.commit();
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }

  /// Calcula cómo se repartiría [monto] entre las facturas pendientes de un proveedor,
  /// pagando primero las que vencen antes. No escribe nada todavía.
  List<DistribucionAbono> calcularDistribucion(List<CompraCreditoModel> comprasProveedor, double monto) {
    final pendientes = comprasProveedor.where((c) => !c.liquidada).toList()
      ..sort((a, b) {
        if (a.fechaVencimiento == null && b.fechaVencimiento == null) return 0;
        if (a.fechaVencimiento == null) return 1;
        if (b.fechaVencimiento == null) return -1;
        return a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
      });

    var restante = monto;
    final resultado = <DistribucionAbono>[];
    for (final compra in pendientes) {
      if (restante <= 0) break;
      final aplicado = restante >= compra.saldoPendiente ? compra.saldoPendiente : restante;
      resultado.add(DistribucionAbono(compra: compra, montoAplicado: aplicado, saldoResultante: compra.saldoPendiente - aplicado));
      restante -= aplicado;
    }
    return resultado;
  }

  Future<void> registrarAbonoGeneral({
    required List<DistribucionAbono> distribucion,
    required String metodoPago,
    required String usuario,
  }) async {
    final batch = _db.batch();
    for (final item in distribucion) {
      batch.update(_col.doc(item.compra.id), {'saldoPendiente': item.saldoResultante});
      final abonoRef = _col.doc(item.compra.id).collection('abonosCompra').doc();
      batch.set(abonoRef, {
        'idCompra': item.compra.id,
        'idProveedor': item.compra.idProveedor,
        'nombreProveedor': item.compra.nombreProveedor,
        'fecha': FieldValue.serverTimestamp(),
        'montoAbonado': item.montoAplicado,
        'saldoAnterior': item.compra.saldoPendiente,
        'interes': 0,
        'saldoPendiente': item.saldoResultante,
        'metodoPago': metodoPago,
        'numeroRecibo': '',
        'usuario': usuario,
        'esAbonoGeneral': true,
      });
    }
    await batch.commit();
  }

  Future<List<AbonoCompraModel>> obtenerAbonosPorRango(DateTime inicio, DateTime finInclusive) async {
    final snap = await _db
        .collectionGroup('abonosCompra')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .get();
    return snap.docs.map((d) => AbonoCompraModel.fromMap(d.id, d.data())).toList();
  }
}
