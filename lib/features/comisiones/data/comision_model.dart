/// Comisión de un barbero por los servicios (cortes) que atendió en un
/// periodo: cada línea de servicio ya trae su propio % de comisión
/// (capturado al momento de la venta, ver ItemVentaModel.pctComisionBarbero),
/// así que acá solo se suma.
class ComisionCorteBarbero {
  final String idBarbero;
  final String nombreBarbero;
  final double cantidadCortes;
  final double montoTotal;
  final double comisionTotal;

  ComisionCorteBarbero({
    required this.idBarbero,
    required this.nombreBarbero,
    required this.cantidadCortes,
    required this.montoTotal,
    required this.comisionTotal,
  });
}

/// Comisión por venta de producto físico atribuida a un vendedor (usuario o
/// barbero) que no es necesariamente el cajero que cobró: la tasa depende
/// del volumen total vendido por esa persona en el periodo (tramos, ver
/// tasaComisionProducto en comision_repository.dart).
class ComisionProductoVendedor {
  final String tipo; // 'Usuario' | 'Barbero'
  final String id;
  final String nombre;
  final double cantidadProductos;
  final double montoTotal;
  final double tasa;
  final double comisionTotal;

  ComisionProductoVendedor({
    required this.tipo,
    required this.id,
    required this.nombre,
    required this.cantidadProductos,
    required this.montoTotal,
    required this.tasa,
    required this.comisionTotal,
  });
}
