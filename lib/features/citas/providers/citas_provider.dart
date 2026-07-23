import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cita_repository.dart';
import '../data/cita_model.dart';

final citaRepositoryProvider = Provider((ref) => CitaRepository());

final citasStreamProvider = StreamProvider<List<CitaModel>>((ref) {
  return ref.watch(citaRepositoryProvider).obtenerCitas();
});
