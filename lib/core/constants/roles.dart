class Roles {
  static const administrador = 'Administrador';
  static const empleado = 'Empleado';
  // Un usuario con este rol tiene que estar vinculado a un barbero (ver
  // UsuarioModel.idBarbero): solo ve su propia Agenda de Citas y su propio
  // reporte de Comisiones, nada más (ver modulos_menu.dart).
  static const barbero = 'Barbero';
}