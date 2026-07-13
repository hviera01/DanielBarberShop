class CategoriaModel {
  final String id;
  final String descripcion;
  final bool estado;

  CategoriaModel({
    required this.id,
    required this.descripcion,
    required this.estado,
  });

  factory CategoriaModel.fromMap(String id, Map<String, dynamic> data) {
    return CategoriaModel(
      id: id,
      descripcion: data['descripcion'] ?? '',
      estado: data['estado'] ?? true,
    );
  }
}