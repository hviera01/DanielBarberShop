import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/producto_repository.dart';
import '../data/producto_model.dart';

final productoRepositoryProvider = Provider((ref) => ProductoRepository());

final productosStreamProvider = StreamProvider<List<ProductoModel>>((ref) {
  return ref.watch(productoRepositoryProvider).obtenerProductos();
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