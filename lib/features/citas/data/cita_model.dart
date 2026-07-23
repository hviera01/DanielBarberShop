import 'package:cloud_firestore/cloud_firestore.dart';

const estadosCita = ['Programada', 'Completada', 'Cancelada'];

class CitaModel {
  final String id;
  final String idCliente;
  final String nombreCliente;
  final String telefonoCliente;
  final String idBarbero;
  final String nombreBarbero;
  final String idServicio;
  final String nombreServicio;
  final DateTime fechaHora;
  final String estado;
  final String notas;
  final String usuarioReg;

  CitaModel({
    required this.id,
    required this.idCliente,
    required this.nombreCliente,
    required this.telefonoCliente,
    required this.idBarbero,
    required this.nombreBarbero,
    required this.idServicio,
    required this.nombreServicio,
    required this.fechaHora,
    required this.estado,
    required this.notas,
    required this.usuarioReg,
  });

  bool get esProgramada => estado == 'Programada';

  factory CitaModel.fromMap(String id, Map<String, dynamic> data) {
    return CitaModel(
      id: id,
      idCliente: data['idCliente'] ?? '',
      nombreCliente: data['nombreCliente'] ?? '',
      telefonoCliente: data['telefonoCliente'] ?? '',
      idBarbero: data['idBarbero'] ?? '',
      nombreBarbero: data['nombreBarbero'] ?? '',
      idServicio: data['idServicio'] ?? '',
      nombreServicio: data['nombreServicio'] ?? '',
      fechaHora: (data['fechaHora'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: data['estado'] ?? 'Programada',
      notas: data['notas'] ?? '',
      usuarioReg: data['usuarioReg'] ?? '',
    );
  }

  String get textoBusqueda => '$nombreCliente $telefonoCliente $nombreBarbero $nombreServicio';
}
