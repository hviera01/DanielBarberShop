class ItemCompraModel {
  final String idProducto;
  final String idCategoria;
  final String nombreProducto;
  final double precioCompra;
  final double cantidad;
  final double subtotal;
  final double descuentoPorcentaje;

  ItemCompraModel({
    required this.idProducto,
    required this.idCategoria,
    required this.nombreProducto,
    required this.precioCompra,
    required this.cantidad,
    required this.subtotal,
    this.descuentoPorcentaje = 0,
  });

  factory ItemCompraModel.fromMap(Map<String, dynamic> data) {
    return ItemCompraModel(
      idProducto: data['idProducto'] ?? '',
      idCategoria: data['idCategoria'] ?? '',
      nombreProducto: data['nombreProducto'] ?? '',
      precioCompra: (data['precioCompra'] ?? 0).toDouble(),
      cantidad: (data['cantidad'] ?? 0).toDouble(),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      descuentoPorcentaje: (data['descuentoPorcentaje'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idProducto': idProducto,
      'idCategoria': idCategoria,
      'nombreProducto': nombreProducto,
      'precioCompra': precioCompra,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'descuentoPorcentaje': descuentoPorcentaje,
    };
  }

  ItemCompraModel copyWith({
    double? precioCompra,
    double? cantidad,
    double? subtotal,
    double? descuentoPorcentaje,
  }) {
    return ItemCompraModel(
      idProducto: idProducto,
      idCategoria: idCategoria,
      nombreProducto: nombreProducto,
      precioCompra: precioCompra ?? this.precioCompra,
      cantidad: cantidad ?? this.cantidad,
      subtotal: subtotal ?? this.subtotal,
      descuentoPorcentaje: descuentoPorcentaje ?? this.descuentoPorcentaje,
    );
  }
}
