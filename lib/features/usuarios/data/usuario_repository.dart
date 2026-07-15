import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'usuario_model.dart';

class UsuarioRepository {
  final _col = FirebaseFirestore.instance.collection('usuarios');

  String _hashClave(String clave) {
    return sha256.convert(utf8.encode(clave)).toString();
  }

  Stream<List<UsuarioModel>> obtenerUsuarios() {
    return _col.orderBy('nombreCompleto').snapshots().map((snap) {
      return snap.docs.map((d) => UsuarioModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> crear(String documento, String nombreCompleto, String correo, String clave, String rol, bool estado) async {
    final existe = await _col.where('documento', isEqualTo: documento).limit(1).get();
    if (existe.docs.isNotEmpty) {
      throw Exception('El número de documento ya existe');
    }
    await _col.add({
      'documento': documento,
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'clave': _hashClave(clave),
      'rol': rol,
      'estado': estado,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar(String id, String documento, String nombreCompleto, String correo, String rol, bool estado, [String? clave]) async {
    final existe = await _col.where('documento', isEqualTo: documento).limit(2).get();
    final duplicado = existe.docs.any((d) => d.id != id);
    if (duplicado) {
      throw Exception('El número de documento ya existe');
    }
    final data = <String, dynamic>{
      'documento': documento,
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'rol': rol,
      'estado': estado,
    };
    if (clave != null && clave.trim().isNotEmpty) {
      data['clave'] = _hashClave(clave);
    }
    await _col.doc(id).update(data);
  }

  Future<void> eliminar(String id) async {
    final compras = await FirebaseFirestore.instance
        .collection('compras')
        .where('idUsuario', isEqualTo: id)
        .limit(1)
        .get();
    if (compras.docs.isNotEmpty) {
      throw Exception('No se puede eliminar porque el usuario se encuentra relacionado a una compra');
    }
    final ventas = await FirebaseFirestore.instance
        .collection('ventas')
        .where('idUsuario', isEqualTo: id)
        .limit(1)
        .get();
    if (ventas.docs.isNotEmpty) {
      throw Exception('No se puede eliminar porque el usuario se encuentra relacionado a una venta');
    }
    await _col.doc(id).delete();
  }
}