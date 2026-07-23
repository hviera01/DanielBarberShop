import 'package:cloud_firestore/cloud_firestore.dart';
import 'barbero_model.dart';

class BarberoRepository {
  final _col = FirebaseFirestore.instance.collection('barberos');

  Stream<List<BarberoModel>> obtenerBarberos() {
    return _col.orderBy('nombreCompleto').snapshots().map((snap) {
      return snap.docs.map((d) => BarberoModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<List<BarberoModel>> obtenerActivos() async {
    final snap = await _col.where('estado', isEqualTo: true).orderBy('nombreCompleto').get();
    return snap.docs.map((d) => BarberoModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> crear({
    required String documento,
    required String nombreCompleto,
    required String telefono,
    required String especialidad,
    required double porcentajeComision,
    required String notas,
    required bool estado,
  }) async {
    if (documento.isNotEmpty) {
      final existe = await _col.where('documento', isEqualTo: documento).limit(1).get();
      if (existe.docs.isNotEmpty) {
        throw Exception('Ya existe un barbero con ese documento');
      }
    }
    await _col.add({
      'documento': documento,
      'nombreCompleto': nombreCompleto,
      'telefono': telefono,
      'especialidad': especialidad,
      'porcentajeComision': porcentajeComision,
      'notas': notas,
      'estado': estado,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar({
    required String id,
    required String documento,
    required String nombreCompleto,
    required String telefono,
    required String especialidad,
    required double porcentajeComision,
    required String notas,
    required bool estado,
  }) async {
    if (documento.isNotEmpty) {
      final existe = await _col.where('documento', isEqualTo: documento).limit(2).get();
      final duplicado = existe.docs.any((d) => d.id != id);
      if (duplicado) {
        throw Exception('Ya existe un barbero con ese documento');
      }
    }
    await _col.doc(id).update({
      'documento': documento,
      'nombreCompleto': nombreCompleto,
      'telefono': telefono,
      'especialidad': especialidad,
      'porcentajeComision': porcentajeComision,
      'notas': notas,
      'estado': estado,
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }
}
