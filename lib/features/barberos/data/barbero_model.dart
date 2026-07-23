class BarberoModel {
  final String id;
  final String documento;
  final String nombreCompleto;
  final String telefono;
  final String especialidad;
  final double porcentajeComision;
  final String notas;
  final bool estado;

  BarberoModel({
    required this.id,
    required this.documento,
    required this.nombreCompleto,
    required this.telefono,
    required this.especialidad,
    required this.porcentajeComision,
    required this.notas,
    required this.estado,
  });

  factory BarberoModel.fromMap(String id, Map<String, dynamic> data) {
    return BarberoModel(
      id: id,
      documento: data['documento'] ?? '',
      nombreCompleto: data['nombreCompleto'] ?? '',
      telefono: data['telefono'] ?? '',
      especialidad: data['especialidad'] ?? '',
      porcentajeComision: (data['porcentajeComision'] ?? 0).toDouble(),
      notas: data['notas'] ?? '',
      estado: data['estado'] ?? true,
    );
  }

  String get textoBusqueda => '$documento $nombreCompleto $telefono $especialidad';
}
