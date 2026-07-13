import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import '../data/usuario_model.dart';
import '../../../core/providers/tabs_provider.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthState {
  final UsuarioModel? usuario;
  final bool cargando;
  final String? error;

  AuthState({this.usuario, this.cargando = false, this.error});
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  Future<void> login(String documento, String clave) async {
    state = AuthState(cargando: true);
    try {
      final usuario = await ref.read(authRepositoryProvider).login(documento, clave);
      state = AuthState(usuario: usuario);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuario_id', usuario.id);
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
    }
  }

 Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_id');
    state = AuthState();
    ref.invalidate(tabsProvider);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);