import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/usuario_model.dart';
import '../../providers/usuarios_provider.dart';
import '../../../../core/constants/roles.dart';
import '../../../barberos/providers/barberos_provider.dart';

class UsuarioFormDialog extends ConsumerStatefulWidget {
  final UsuarioModel? usuario;

  const UsuarioFormDialog({super.key, this.usuario});

  @override
  ConsumerState<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends ConsumerState<UsuarioFormDialog> {
  final _documentoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _claveController = TextEditingController();
  String _rol = Roles.empleado;
  String? _idBarbero;
  bool _activo = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.usuario != null) {
      _documentoController.text = widget.usuario!.documento;
      _nombreController.text = widget.usuario!.nombreCompleto;
      _correoController.text = widget.usuario!.correo;
      _rol = widget.usuario!.rol.isNotEmpty ? widget.usuario!.rol : Roles.empleado;
      _idBarbero = widget.usuario!.idBarbero.isEmpty ? null : widget.usuario!.idBarbero;
      _activo = widget.usuario!.estado;
    }
  }

  @override
  void dispose() {
    _documentoController.dispose();
    _nombreController.dispose();
    _correoController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final documento = _documentoController.text.trim();
    final nombre = _nombreController.text.trim();
    final correo = _correoController.text.trim();
    final clave = _claveController.text.trim();
    final editando = widget.usuario != null;

    if (documento.isEmpty || nombre.isEmpty) {
      setState(() => _error = 'Documento y nombre completo son obligatorios');
      return;
    }
    if (!editando && clave.isEmpty) {
      setState(() => _error = 'La contraseña es obligatoria');
      return;
    }
    if (_rol == Roles.barbero && (_idBarbero == null || _idBarbero!.isEmpty)) {
      setState(() => _error = 'Elegí a qué barbero corresponde este usuario');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(usuarioRepositoryProvider);
      final idBarbero = _rol == Roles.barbero ? (_idBarbero ?? '') : '';
      if (!editando) {
        await repo.crear(documento, nombre, correo, clave, _rol, _activo, idBarbero: idBarbero);
      } else {
        await repo.actualizar(widget.usuario!.id, documento, nombre, correo, _rol, _activo, idBarbero: idBarbero, clave: clave.isEmpty ? null : clave);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar usuario', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que querés eliminar este usuario?', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _guardando = true);
    try {
      await ref.read(usuarioRepositoryProvider).eliminar(widget.usuario!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.usuario != null;
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 500;
    final anchoDialog = esMovil ? tamano.width - 48 : 440.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Container(
          width: anchoDialog,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1B3D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: Color(0xFF0F1B3D)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      editando ? 'Editar Usuario' : 'Nuevo Usuario',
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _documentoController,
                autofocus: true,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _decoracion('Documento'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nombreController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _decoracion('Nombre completo'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _correoController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _decoracion('Correo'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _claveController,
                obscureText: true,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _decoracion(editando ? 'Nueva contraseña (opcional)' : 'Contraseña'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                decoration: _decoracion('Rol'),
                items: [Roles.administrador, Roles.empleado, Roles.barbero]
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.poppins(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _rol = v ?? Roles.empleado),
              ),
              // Un usuario con rol Barbero solo ve su propia Agenda de
              // Citas y sus propias Comisiones (ver ModulosMenu/SideMenu):
              // necesita estar vinculado a un documento de la colección
              // `barberos` para saber cuál es "lo suyo".
              if (_rol == Roles.barbero) ...[
                const SizedBox(height: 14),
                ref.watch(barberosStreamProvider).when(
                      data: (barberos) {
                        final activos = barberos.where((b) => b.estado).toList();
                        return DropdownButtonFormField<String>(
                          initialValue: _idBarbero,
                          decoration: _decoracion('Barbero asociado'),
                          items: activos
                              .map((b) => DropdownMenuItem(value: b.id, child: Text(b.nombreCompleto, style: GoogleFonts.poppins(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setState(() => _idBarbero = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text('Error cargando barberos', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                    ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('Estado', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(
                      _activo ? 'Activo' : 'Inactivo',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _activo ? const Color(0xFF16A34A) : Colors.grey.shade500),
                    ),
                    Switch(
                      value: _activo,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (v) => setState(() => _activo = v),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (editando)
                    IconButton(
                      onPressed: _guardando ? null : _eliminar,
                      icon: const Icon(Icons.delete_outline, color: Color(0xFF0F1B3D)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0F1B3D).withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F1B3D),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : Text('Guardar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}