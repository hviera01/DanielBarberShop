import 'package:cloud_firestore/cloud_firestore.dart';
import 'color_model.dart';

class ColorRepository {
  final _col = FirebaseFirestore.instance.collection('colores');

  Stream<List<ColorModel>> obtenerColores() {
    return _col.orderBy('fechaRegistro', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => ColorModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> crear({
    required String codigo,
    required String cliente,
    required String descripcion,
    required String ubicacionFisica,
    required String pagina,
    required DateTime? fechaRegistro,
    required String observaciones,
  }) async {
    await _col.add({
      'codigo': codigo,
      'cliente': cliente,
      'descripcion': descripcion,
      'ubicacionFisica': ubicacionFisica,
      'pagina': pagina,
      'fechaRegistro': fechaRegistro != null ? Timestamp.fromDate(fechaRegistro) : FieldValue.serverTimestamp(),
      'observaciones': observaciones,
    });
  }

  Future<void> actualizar({
    required String id,
    required String codigo,
    required String cliente,
    required String descripcion,
    required String ubicacionFisica,
    required String pagina,
    required DateTime? fechaRegistro,
    required String observaciones,
  }) async {
    await _col.doc(id).update({
      'codigo': codigo,
      'cliente': cliente,
      'descripcion': descripcion,
      'ubicacionFisica': ubicacionFisica,
      'pagina': pagina,
      'fechaRegistro': fechaRegistro != null ? Timestamp.fromDate(fechaRegistro) : null,
      'observaciones': observaciones,
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }
}
