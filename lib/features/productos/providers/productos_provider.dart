import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/producto_repository.dart';
import '../data/producto_model.dart';
import '../data/historial_stock_model.dart';
import '../data/historial_precio_compra_model.dart';
import '../data/historial_venta_producto_model.dart';

final productoRepositoryProvider = Provider((ref) => ProductoRepository());

final productosStreamProvider = StreamProvider<List<ProductoModel>>((ref) {
  return ref.watch(productoRepositoryProvider).obtenerProductos();
});

// FutureProvider.family + autoDispose (no StreamProvider): estos tres solo
// alimentan diálogos de solo lectura (HistorialStockDialog,
// HistorialMovimientosDialog) que el usuario abre y cierra, nunca escriben
// nada. Sin autoDispose, un StreamProvider.family deja un listener de
// Firestore abierto para siempre por cada producto cuyo historial se haya
// mirado alguna vez en la sesión, aunque el diálogo ya esté cerrado. Con
// autoDispose, apenas se cierra el diálogo (nadie más lo escucha) Riverpod
// libera el provider; la próxima vez que se abra, se vuelve a pedir con
// `.get()` y siempre trae el dato fresco de ese momento.
final historialStockProvider = FutureProvider.autoDispose.family<List<HistorialStockModel>, String>((ref, idProducto) {
  return ref.watch(productoRepositoryProvider).obtenerHistorialStock(idProducto);
});

final historialPreciosCompraProvider = FutureProvider.autoDispose.family<List<HistorialPrecioCompraModel>, String>((ref, idProducto) {
  return ref.watch(productoRepositoryProvider).obtenerHistorialPreciosCompra(idProducto);
});

final historialVentasProductoProvider = FutureProvider.autoDispose.family<List<HistorialVentaProductoModel>, String>((ref, idProducto) {
  return ref.watch(productoRepositoryProvider).obtenerHistorialVentas(idProducto);
});

class InventarioBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final inventarioBusquedaProvider = NotifierProvider<InventarioBusquedaNotifier, String>(InventarioBusquedaNotifier.new);

class InventarioVistaNotifier extends Notifier<String> {
  @override
  String build() => 'filtrados';
  void actualizar(String valor) => state = valor;
}

final inventarioVistaProvider = NotifierProvider<InventarioVistaNotifier, String>(InventarioVistaNotifier.new);