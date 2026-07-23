import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/cita_model.dart';
import '../../providers/citas_provider.dart';
import '../../../barberos/providers/barberos_provider.dart';
import '../../../barberos/data/barbero_model.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../clientes/data/cliente_model.dart';
import '../../../productos/providers/productos_provider.dart';
import '../../../productos/data/producto_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../ventas/presentation/widgets/buscar_cliente_dialog.dart';

/// Franjas de 15 minutos entre las 7:00 y las 22:00 (igual que el sistema
/// viejo, que arrancaba a las 7am, pero con un rango un poco más amplio).
List<TimeOfDay> _franjasHora() {
  final lista = <TimeOfDay>[];
  var minutos = 7 * 60;
  while (minutos <= 22 * 60) {
    lista.add(TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60));
    minutos += 15;
  }
  return lista;
}

class CitaFormDialog extends ConsumerStatefulWidget {
  final CitaModel? cita;
  final DateTime? fechaInicial;

  const CitaFormDialog({super.key, this.cita, this.fechaInicial});

  @override
  ConsumerState<CitaFormDialog> createState() => _CitaFormDialogState();
}

class _CitaFormDialogState extends ConsumerState<CitaFormDialog> {
  final _nombreClienteController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _notasController = TextEditingController();
  String? _idClienteExistente;
  String? _idBarbero;
  String? _nombreBarbero;
  String? _idServicio;
  String? _nombreServicio;
  late DateTime _fecha;
  late TimeOfDay _hora;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.cita;
    if (c != null) {
      _idClienteExistente = c.idCliente.isEmpty ? null : c.idCliente;
      _nombreClienteController.text = c.nombreCliente;
      _telefonoController.text = c.telefonoCliente;
      _idBarbero = c.idBarbero.isEmpty ? null : c.idBarbero;
      _nombreBarbero = c.nombreBarbero;
      _idServicio = c.idServicio.isEmpty ? null : c.idServicio;
      _nombreServicio = c.nombreServicio;
      _notasController.text = c.notas;
      _fecha = DateTime(c.fechaHora.year, c.fechaHora.month, c.fechaHora.day);
      _hora = TimeOfDay(hour: c.fechaHora.hour, minute: c.fechaHora.minute);
    } else {
      final base = widget.fechaInicial ?? DateTime.now();
      _fecha = DateTime(base.year, base.month, base.day);
      _hora = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _nombreClienteController.dispose();
    _telefonoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _elegirCliente() async {
    final elegido = await showDialog<ClienteModel>(context: context, builder: (context) => const BuscarClienteDialog());
    if (elegido == null) return;
    setState(() {
      _idClienteExistente = elegido.id;
      _nombreClienteController.text = elegido.nombreCompleto;
      if (elegido.telefono.isNotEmpty) _telefonoController.text = elegido.telefono;
    });
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida == null) return;
    setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    final nombreCliente = _nombreClienteController.text.trim();
    if (nombreCliente.isEmpty) {
      setState(() => _error = 'El nombre del cliente es obligatorio');
      return;
    }
    if (_idBarbero == null) {
      setState(() => _error = 'Elegí un barbero');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      // Si el cliente no viene de "Buscar Cliente" (o el usuario cambió el
      // nombre a mano después de elegirlo), se registra rápido uno nuevo:
      // agendar no debería obligar a salir de este formulario para crear el
      // cliente primero.
      var idCliente = _idClienteExistente ?? '';
      if (idCliente.isEmpty) {
        final creado = await ref.read(clienteRepositoryProvider).crearRapido(
              nombreCompleto: nombreCliente,
              telefono: _telefonoController.text.trim(),
            );
        idCliente = creado.id;
      }

      final fechaHora = DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
      final repo = ref.read(citaRepositoryProvider);
      if (widget.cita == null) {
        final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? '';
        await repo.crear(
          idCliente: idCliente,
          nombreCliente: nombreCliente,
          telefonoCliente: _telefonoController.text.trim(),
          idBarbero: _idBarbero!,
          nombreBarbero: _nombreBarbero ?? '',
          idServicio: _idServicio ?? '',
          nombreServicio: _nombreServicio ?? '',
          fechaHora: fechaHora,
          notas: _notasController.text.trim(),
          usuarioReg: usuario,
        );
      } else {
        await repo.actualizar(
          id: widget.cita!.id,
          idCliente: idCliente,
          nombreCliente: nombreCliente,
          telefonoCliente: _telefonoController.text.trim(),
          idBarbero: _idBarbero!,
          nombreBarbero: _nombreBarbero ?? '',
          idServicio: _idServicio ?? '',
          nombreServicio: _nombreServicio ?? '',
          fechaHora: fechaHora,
          notas: _notasController.text.trim(),
        );
      }
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.cita != null;
    final barberosAsync = ref.watch(barberosStreamProvider);
    final productosAsync = ref.watch(productosStreamProvider);
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final anchoDialog = esMovil ? tamano.width - 48 : 460.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: anchoDialog,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF0F1B3D).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.event_outlined, color: Color(0xFF0F1B3D)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      editando ? 'Editar Cita' : 'Nueva Cita',
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nombreClienteController,
                      autofocus: true,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _decoracion('Cliente').copyWith(
                        suffixIcon: IconButton(icon: const Icon(Icons.search, size: 20), tooltip: 'Buscar cliente', onPressed: _elegirCliente),
                      ),
                      onChanged: (_) => setState(() => _idClienteExistente = null),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _telefonoController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _decoracion('Teléfono (opcional)'),
                    ),
                    const SizedBox(height: 14),
                    barberosAsync.when(
                      data: (barberos) {
                        final activos = barberos.where((b) => b.estado).toList();
                        return DropdownButtonFormField<String>(
                          initialValue: _idBarbero,
                          decoration: _decoracion('Barbero'),
                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A1A)),
                          items: activos.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nombreCompleto))).toList(),
                          onChanged: (v) {
                            BarberoModel? elegido;
                            for (final b in activos) {
                              if (b.id == v) elegido = b;
                            }
                            setState(() {
                              _idBarbero = v;
                              _nombreBarbero = elegido?.nombreCompleto;
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text('Error cargando barberos', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                    ),
                    const SizedBox(height: 14),
                    productosAsync.when(
                      data: (productos) {
                        final servicios = productos.where((p) => p.esServicio && p.estado).toList();
                        return DropdownButtonFormField<String>(
                          initialValue: _idServicio,
                          decoration: _decoracion('Servicio (opcional)'),
                          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A1A)),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Sin definir')),
                            ...servicios.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre))),
                          ],
                          onChanged: (v) {
                            ProductoModel? elegido;
                            for (final p in servicios) {
                              if (p.id == v) elegido = p;
                            }
                            setState(() {
                              _idServicio = (v == null || v.isEmpty) ? null : v;
                              _nombreServicio = elegido?.nombre;
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text('Error cargando servicios', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _elegirFecha,
                            child: InputDecorator(
                              decoration: _decoracion('Fecha'),
                              child: Text(DateFormat('dd/MM/yyyy').format(_fecha), style: GoogleFonts.poppins(fontSize: 14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<TimeOfDay>(
                            initialValue: _hora,
                            decoration: _decoracion('Hora'),
                            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A1A)),
                            items: _franjasHora().map((h) => DropdownMenuItem(value: h, child: Text(h.format(context)))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _hora = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notasController,
                      maxLines: 2,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _decoracion('Notas (opcional)'),
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Row(
                children: [
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
            ),
          ],
        ),
      ),
    );
  }
}
