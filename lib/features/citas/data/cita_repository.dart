import 'package:cloud_firestore/cloud_firestore.dart';
import 'cita_model.dart';

class CitaRepository {
  final _col = FirebaseFirestore.instance.collection('citas');

  /// Trae todas las citas ordenadas por fecha/hora; el filtrado por rango de
  /// fechas, barbero y texto se hace en memoria en la pantalla (igual que
  /// Clientes/Proveedores), ya que el volumen de citas de una barbería es
  /// chico y así evita índices compuestos.
  Stream<List<CitaModel>> obtenerCitas() {
    return _col.orderBy('fechaHora').snapshots().map((snap) {
      return snap.docs.map((d) => CitaModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> crear({
    required String idCliente,
    required String nombreCliente,
    required String telefonoCliente,
    required String idBarbero,
    required String nombreBarbero,
    required String idServicio,
    required String nombreServicio,
    required DateTime fechaHora,
    required String notas,
    required String usuarioReg,
  }) async {
    await _col.add({
      'idCliente': idCliente,
      'nombreCliente': nombreCliente,
      'telefonoCliente': telefonoCliente,
      'idBarbero': idBarbero,
      'nombreBarbero': nombreBarbero,
      'idServicio': idServicio,
      'nombreServicio': nombreServicio,
      'fechaHora': Timestamp.fromDate(fechaHora),
      'estado': 'Programada',
      'notas': notas,
      'usuarioReg': usuarioReg,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar({
    required String id,
    required String idCliente,
    required String nombreCliente,
    required String telefonoCliente,
    required String idBarbero,
    required String nombreBarbero,
    required String idServicio,
    required String nombreServicio,
    required DateTime fechaHora,
    required String notas,
  }) async {
    await _col.doc(id).update({
      'idCliente': idCliente,
      'nombreCliente': nombreCliente,
      'telefonoCliente': telefonoCliente,
      'idBarbero': idBarbero,
      'nombreBarbero': nombreBarbero,
      'idServicio': idServicio,
      'nombreServicio': nombreServicio,
      'fechaHora': Timestamp.fromDate(fechaHora),
      'notas': notas,
    });
  }

  Future<void> cambiarEstado(String id, String estado) async {
    await _col.doc(id).update({'estado': estado});
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }
}
