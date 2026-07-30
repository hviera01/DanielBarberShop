import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/barbero_repository.dart';
import '../data/barbero_model.dart';

final barberoRepositoryProvider = Provider((ref) => BarberoRepository());

final barberosStreamProvider = StreamProvider<List<BarberoModel>>((ref) {
  return ref.watch(barberoRepositoryProvider).obtenerBarberos();
});

// Derivado de barberosStreamProvider (en vivo) en vez de una consulta propia
// de una sola vez: antes, si alguien agregaba un barbero mientras una venta
// ya estaba en curso, el selector de "¿quién atendió?"/"¿quién vendió?" no
// lo mostraba hasta reabrir la pestaña -leía un FutureProvider que solo se
// resolvía una vez y quedaba en caché-. Así siempre refleja el estado actual
// de Firestore sin depender de cuándo se montó la pantalla.
final barberosActivosProvider = Provider<List<BarberoModel>>((ref) {
  final barberos = ref.watch(barberosStreamProvider).value ?? [];
  return barberos.where((b) => b.estado).toList();
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
