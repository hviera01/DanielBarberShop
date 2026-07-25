class UsuarioModel {
  final String id;
  final String documento;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final bool estado;
  // Solo se usa (y solo tiene sentido) cuando rol == Roles.barbero: vincula
  // este usuario a un documento de la colección `barberos`, para poder
  // filtrar Agenda de Citas y Comisiones a lo suyo únicamente.
  final String idBarbero;

  UsuarioModel({
    required this.id,
    required this.documento,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.estado,
    this.idBarbero = '',
  });

  factory UsuarioModel.fromMap(String id, Map<String, dynamic> data) {
    return UsuarioModel(
      id: id,
      documento: data['documento'] ?? '',
      nombreCompleto: data['nombreCompleto'] ?? '',
      correo: data['correo'] ?? '',
      rol: data['rol'] ?? '',
      estado: data['estado'] ?? true,
      idBarbero: data['idBarbero'] ?? '',
    );
  }
}
