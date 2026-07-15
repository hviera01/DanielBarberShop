import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/venta_repository.dart';
import '../data/venta_en_espera_model.dart';

final ventaRepositoryProvider = Provider((ref) => VentaRepository());

final ventasEnEsperaStreamProvider = StreamProvider<List<VentaEnEsperaModel>>((ref) {
  return ref.watch(ventaRepositoryProvider).obtenerVentasEnEspera();
});
