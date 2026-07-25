/// Un corte (línea de servicio) individual dentro de una venta, con los
/// datos de la venta a la que pertenece ya resueltos -para poder listar
/// "qué ventas componen este total" y navegar al detalle de cada una, ver
/// ReporteComisionesScreen-.
class LineaComisionVenta {
  final String idVenta;
  final String numeroDocumento;
  final DateTime? fecha;
  final String cliente;
  final String nombreItem;
  final double monto;
  final double comision;

  LineaComisionVenta({
    required this.idVenta,
    required this.numeroDocumento,
    required this.fecha,
    required this.cliente,
    required this.nombreItem,
    required this.monto,
    required this.comision,
  });
}

/// Comisión de un barbero por los servicios (cortes) que atendió en un
/// periodo: cada línea de servicio ya trae su propio % de comisión
/// (capturado al momento de la venta, ver ItemVentaModel.pctComisionBarbero),
/// así que acá solo se suma. [lineas] guarda el detalle de cada corte
/// individual que compone el total, para el drill-down de la pantalla.
class ComisionCorteBarbero {
  final String idBarbero;
  final String nombreBarbero;
  final double cantidadCortes;
  final double montoTotal;
  final double comisionTotal;
  final List<LineaComisionVenta> lineas;

  ComisionCorteBarbero({
    required this.idBarbero,
    required this.nombreBarbero,
    required this.cantidadCortes,
    required this.montoTotal,
    required this.comisionTotal,
    this.lineas = const [],
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
  final List<LineaComisionVenta> lineas;

  ComisionProductoVendedor({
    required this.tipo,
    required this.id,
    required this.nombre,
    required this.cantidadProductos,
    required this.montoTotal,
    required this.tasa,
    required this.comisionTotal,
    this.lineas = const [],
  });
}
