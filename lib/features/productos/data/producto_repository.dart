import 'package:cloud_firestore/cloud_firestore.dart';
import 'producto_model.dart';
import 'historial_stock_model.dart';

class ProductoRepository {
  final _col = FirebaseFirestore.instance.collection('productos');

  Stream<List<ProductoModel>> obtenerProductos() {
    return _col.orderBy('nombre').snapshots().map((snap) {
      return snap.docs.map((d) => ProductoModel.fromMap(d.id, d.data())).toList();
    });
  }

  String _generarCodigo() {
    final ahora = DateTime.now().millisecondsSinceEpoch.toString();
    return 'PROD-${ahora.substring(ahora.length - 8)}';
  }

  Future<void> crear({
    required String codigo,
    required String codigoBarras,
    required String nombre,
    required String descripcion,
    required String idCategoria,
    required double stock,
    required double precioCompra,
    required double precioVenta,
    required double precioVenta2,
    required double precioVenta3,
    required bool estado,
  }) async {
    var codigoFinal = codigo.trim();
    if (codigoFinal.isEmpty) {
      codigoFinal = _generarCodigo();
    } else {
      final existe = await _col.where('codigo', isEqualTo: codigoFinal).limit(1).get();
      if (existe.docs.isNotEmpty) {
        throw Exception('Ya existe un producto con ese código');
      }
    }
    await _col.add({
      'codigo': codigoFinal,
      'codigoBarras': codigoBarras.trim(),
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'idCategoria': idCategoria,
      'stock': stock,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'precioVenta2': precioVenta2,
      'precioVenta3': precioVenta3,
      'estado': estado,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar({
    required String id,
    required String codigo,
    required String codigoBarras,
    required String nombre,
    required String descripcion,
    required String idCategoria,
    required double precioCompra,
    required double precioVenta,
    required double precioVenta2,
    required double precioVenta3,
    required bool estado,
  }) async {
    final codigoFinal = codigo.trim().isEmpty ? _generarCodigo() : codigo.trim();
    final existe = await _col.where('codigo', isEqualTo: codigoFinal).get();
    final duplicado = existe.docs.any((d) => d.id != id);
    if (duplicado) {
      throw Exception('Ya existe un producto con ese código');
    }
    await _col.doc(id).update({
      'codigo': codigoFinal,
      'codigoBarras': codigoBarras.trim(),
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'idCategoria': idCategoria,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'precioVenta2': precioVenta2,
      'precioVenta3': precioVenta3,
      'estado': estado,
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> ajustarStock({
    required String id,
    required double stockActual,
    required double stockNuevo,
    required String usuario,
    String motivo = '',
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(id), {'stock': stockNuevo});
    final historialRef = _col.doc(id).collection('historial').doc();
    batch.set(historialRef, {
      'stockAnterior': stockActual,
      'stockNuevo': stockNuevo,
      'usuario': usuario,
      'motivo': motivo,
      'fecha': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<HistorialStockModel>> obtenerHistorialStock(String idProducto) {
    return _col.doc(idProducto).collection('historial').orderBy('fecha', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => HistorialStockModel.fromMap(d.id, d.data())).toList();
    });
  }
}