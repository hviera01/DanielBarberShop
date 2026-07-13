import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'usuario_model.dart';

class AuthRepository {
  final _db = FirebaseFirestore.instance;

  String hashClave(String clave) {
    return sha256.convert(utf8.encode(clave)).toString();
  }

  Future<UsuarioModel> login(String documento, String clave) async {
    final claveHash = hashClave(clave);

    final query = await _db
        .collection('usuarios')
        .where('documento', isEqualTo: documento)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Código de acceso no encontrado');
    }

    final doc = query.docs.first;
    final data = doc.data();

    if (data['estado'] != true) {
      throw Exception('Usuario inactivo, contacte al administrador');
    }

    if (data['clave'] != claveHash) {
      throw Exception('Contraseña incorrecta');
    }

    return UsuarioModel.fromMap(doc.id, data);
  }
}