import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/barbero_repository.dart';
import '../data/barbero_model.dart';

final barberoRepositoryProvider = Provider((ref) => BarberoRepository());

final barberosStreamProvider = StreamProvider<List<BarberoModel>>((ref) {
  return ref.watch(barberoRepositoryProvider).obtenerBarberos();
});

final barberosActivosProvider = FutureProvider<List<BarberoModel>>((ref) {
  return ref.watch(barberoRepositoryProvider).obtenerActivos();
});

class BarberosBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final barberosBusquedaProvider = NotifierProvider<BarberosBusquedaNotifier, String>(BarberosBusquedaNotifier.new);

class BarberosVistaNotifier extends Notifier<String> {
  @override
  String build() => 'filtrados';
  void actualizar(String valor) => state = valor;
}

final barberosVistaProvider = NotifierProvider<BarberosVistaNotifier, String>(BarberosVistaNotifier.new);
