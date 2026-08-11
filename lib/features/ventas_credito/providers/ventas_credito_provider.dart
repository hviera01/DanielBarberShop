import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/venta_credito_repository.dart';
import '../data/venta_credito_model.dart';
import '../data/abono_model.dart';

final ventaCreditoRepositoryProvider = Provider((ref) => VentaCreditoRepository());

final ventasCreditoStreamProvider = StreamProvider<List<VentaCreditoModel>>((ref) {
  return ref.watch(ventaCreditoRepositoryProvider).obtenerCreditos();
});

// FutureProvider.autoDispose (no StreamProvider): solo alimenta un diálogo de
// solo lectura (HistorialAbonosDialog) que se abre y cierra; ver el mismo
// criterio en productos_provider.dart (historialStockProvider y compañía).
final abonosProvider = FutureProvider.autoDispose.family<List<AbonoModel>, String>((ref, idCredito) {
  return ref.watch(ventaCreditoRepositoryProvider).obtenerAbonos(idCredito);
});

class VentasCreditoBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final ventasCreditoBusquedaProvider = NotifierProvider<VentasCreditoBusquedaNotifier, String>(VentasCreditoBusquedaNotifier.new);

class VentasCreditoVistaNotifier extends Notifier<String> {
  @override
  String build() => 'debe';
  void actualizar(String valor) => state = valor;
}

final ventasCreditoVistaProvider = NotifierProvider<VentasCreditoVistaNotifier, String>(VentasCreditoVistaNotifier.new);
