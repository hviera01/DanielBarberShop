import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/cita_model.dart';
import '../../providers/citas_provider.dart';
import '../../../barberos/providers/barberos_provider.dart';
import '../../../../core/utils/texto_utils.dart';
import '../../../../core/providers/tabs_provider.dart';
import '../../../../core/models/tab_item.dart';
import '../../../../core/utils/pantalla_builder.dart';
import '../../../ventas/providers/carrito_provider.dart';
import '../../../ventas/data/venta_model.dart';
import '../../../ventas/data/item_venta_model.dart';
import '../../../productos/providers/productos_provider.dart';
import '../../../productos/data/producto_model.dart';
import '../widgets/cita_form_dialog.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 1));
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 7));
  String? _idBarberoFiltro;
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _abrirFormulario([CitaModel? cita]) {
    showDialog(context: context, builder: (context) => CitaFormDialog(cita: cita, fechaInicial: _fechaInicio));
  }

  Future<void> _cambiarEstado(CitaModel cita, String estado) async {
    await ref.read(citaRepositoryProvider).cambiarEstado(cita.id, estado);
  }

  Future<void> _eliminar(CitaModel cita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar cita', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que querés eliminar esta cita?', style: GoogleFonts.poppins(fontSize: 13)),
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
    await ref.read(citaRepositoryProvider).eliminar(cita.id);
  }

  /// El sistema viejo nunca implementó esto en pantalla (el campo Estado
  /// existía en la base pero la UI solo creaba/editaba citas): acá sí se
  /// puede pasar directo de una cita agendada a una venta ya armada, con el
  /// cliente, barbero y servicio precargados, en una pestaña nueva de
  /// Registrar Venta.
  void _convertirEnVenta(CitaModel cita) {
    final productos = ref.read(productosStreamProvider).value ?? [];
    ProductoModel? servicio;
    for (final p in productos) {
      if (p.id == cita.idServicio) servicio = p;
    }
    final item = ItemVentaModel(
      idProducto: cita.idServicio,
      idCategoria: servicio?.idCategoria ?? '',
      nombreProducto: cita.nombreServicio.isEmpty ? (servicio?.nombre ?? 'Servicio') : cita.nombreServicio,
      precioVenta: servicio?.precioVenta ?? 0,
      cantidad: 1,
      subtotal: servicio?.precioVenta ?? 0,
      precioCompraUsado: servicio?.precioCompra ?? 0,
      esServicio: true,
      idBarbero: cita.idBarbero,
      nombreBarbero: cita.nombreBarbero,
    );
    final ventaBase = VentaModel(
      id: '',
      tipoDocumento: 'VentaSinFacturar',
      numeroDocumento: '',
      documentoCliente: '',
      nombreCliente: cita.nombreCliente,
      metodoPago: 'Efectivo',
      montoPago: 0,
      montoCambio: 0,
      subtotal: item.subtotal,
      impuesto: 0,
      totalAPagar: item.subtotal,
      condicion: 'Contado',
      fechaVencimiento: null,
      fechaRegistro: DateTime.now(),
      estado: 'Activa',
      usuarioRegistro: '',
      cantidadProductos: 1,
      oc: '',
      regExonerado: '',
      regSag: '',
      detalle: cita.idServicio.isEmpty ? [] : [item],
    );
    ref.read(ventaParaCargarProvider.notifier).establecer(ventaBase);
    final id = 'ventas_registrar_${DateTime.now().millisecondsSinceEpoch}';
    ref.read(tabsProvider.notifier).abrirTab(
          TabItem(
            id: id,
            titulo: 'Registrar Venta',
            icono: Icons.point_of_sale_outlined,
            contenido: construirPantalla('ventas_registrar', 'Registrar Venta', Icons.point_of_sale_outlined, id),
          ),
        );
  }

  Future<void> _elegirFecha(bool esInicio) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = elegida;
      } else {
        _fechaFin = elegida;
      }
    });
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Completada':
        return const Color(0xFF16A34A);
      case 'Cancelada':
        return Colors.grey.shade500;
      default:
        return const Color(0xFF0F1B3D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citasAsync = ref.watch(citasStreamProvider);
    final barberosAsync = ref.watch(barberosStreamProvider);

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 800;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 14 : 26),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Text('Agenda de Citas', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(width: esMovil ? constraints.maxWidth : 150, child: _campoFecha('Desde', _fechaInicio, () => _elegirFecha(true))),
                      SizedBox(width: esMovil ? constraints.maxWidth : 150, child: _campoFecha('Hasta', _fechaFin, () => _elegirFecha(false))),
                      SizedBox(width: esMovil ? constraints.maxWidth : 200, child: _selectorBarbero(barberosAsync)),
                      SizedBox(width: esMovil ? constraints.maxWidth : 260, child: _buscador()),
                      FilledButton.icon(
                        onPressed: () => _abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Nueva Cita', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F1B3D),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 18)),
              ],
              body: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFAEB4C0), width: 1.3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 12))],
                ),
                child: citasAsync.when(
                  data: (citas) {
                    final inicio = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
                    final fin = DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day, 23, 59, 59);
                    var lista = citas.where((c) => !c.fechaHora.isBefore(inicio) && !c.fechaHora.isAfter(fin)).toList();
                    if (_idBarberoFiltro != null) {
                      lista = lista.where((c) => c.idBarbero == _idBarberoFiltro).toList();
                    }
                    if (_busqueda.isNotEmpty) {
                      lista = lista.where((c) => coincideFuzzy(c.textoBusqueda, _busqueda)).toList();
                    }

                    if (lista.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay citas en ese rango', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }
                    return esMovil ? _tarjetas(lista) : _tabla(lista);
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F1B3D))),
                  error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _campoFecha(String etiqueta, DateTime valor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(child: Text('$etiqueta: ${DateFormat('dd/MM').format(valor)}', style: GoogleFonts.poppins(fontSize: 12.5))),
          ],
        ),
      ),
    );
  }

  Widget _selectorBarbero(AsyncValue<List<dynamic>> barberosAsync) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _idBarberoFiltro,
          isExpanded: true,
          hint: Text('Todos los barberos', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Todos los barberos')),
            ...barberosAsync.value?.map((b) => DropdownMenuItem<String?>(value: b.id as String, child: Text(b.nombreCompleto as String))) ?? [],
          ],
          onChanged: (v) => setState(() => _idBarberoFiltro = v),
        ),
      ),
    );
  }

  Widget _buscador() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _busquedaController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar cliente, barbero...',
                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v.trim()),
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _opcionesMenu(CitaModel cita) {
    return [
      const PopupMenuItem(value: 'editar', height: 42, child: Text('Editar')),
      if (cita.esProgramada) const PopupMenuItem(value: 'completada', height: 42, child: Text('Marcar Completada')),
      if (cita.esProgramada) const PopupMenuItem(value: 'cancelada', height: 42, child: Text('Marcar Cancelada')),
      if (cita.idServicio.isNotEmpty) const PopupMenuItem(value: 'convertir', height: 42, child: Text('Convertir en venta')),
      const PopupMenuItem(value: 'eliminar', height: 42, child: Text('Eliminar')),
    ];
  }

  void _manejarAccion(String valor, CitaModel cita) {
    switch (valor) {
      case 'editar':
        _abrirFormulario(cita);
        break;
      case 'completada':
        _cambiarEstado(cita, 'Completada');
        break;
      case 'cancelada':
        _cambiarEstado(cita, 'Cancelada');
        break;
      case 'convertir':
        _convertirEnVenta(cita);
        break;
      case 'eliminar':
        _eliminar(cita);
        break;
    }
  }

  Widget _tabla(List<CitaModel> lista) {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFECEEF3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
          child: Row(
            children: [
              _celdaHeader('FECHA / HORA', 2),
              _celdaHeader('CLIENTE', 2),
              _celdaHeader('BARBERO', 2),
              _celdaHeader('SERVICIO', 2),
              _celdaHeader('ESTADO', 1),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: lista.length,
            separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, i) {
              final cita = lista[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _celda(2, '${DateFormat('dd/MM/yyyy').format(cita.fechaHora)}  ${DateFormat('hh:mm a').format(cita.fechaHora)}'),
                    _celda(2, cita.nombreCliente.isEmpty ? '-' : cita.nombreCliente, peso: FontWeight.w600),
                    _celda(2, cita.nombreBarbero.isEmpty ? '-' : cita.nombreBarbero, gris: true),
                    _celda(2, cita.nombreServicio.isEmpty ? 'Sin definir' : cita.nombreServicio, gris: true),
                    Expanded(flex: 1, child: _chipEstado(cita.estado)),
                    SizedBox(
                      width: 40,
                      child: PopupMenuButton<String>(
                        tooltip: 'Más acciones',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 19, color: Color(0xFF454950)),
                        onSelected: (v) => _manejarAccion(v, cita),
                        itemBuilder: (context) => _opcionesMenu(cita),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _celdaHeader(String texto, int flex) {
    return Expanded(
      flex: flex,
      child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF666A72), letterSpacing: 0.35)),
    );
  }

  Widget _celda(int flex, String texto, {bool gris = false, FontWeight peso = FontWeight.w400}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: peso, color: gris ? Colors.grey.shade600 : const Color(0xFF1A1A1A))),
      ),
    );
  }

  Widget _chipEstado(String estado) {
    final color = _colorEstado(estado);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(estado, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _tarjetas(List<CitaModel> lista) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: lista.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final cita = lista[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC7CBD3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(cita.nombreCliente.isEmpty ? 'Sin nombre' : cita.nombreCliente, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 19, color: Color(0xFF454950)),
                    onSelected: (v) => _manejarAccion(v, cita),
                    itemBuilder: (context) => _opcionesMenu(cita),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${DateFormat('dd/MM/yyyy').format(cita.fechaHora)} · ${DateFormat('hh:mm a').format(cita.fechaHora)}', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (cita.nombreBarbero.isNotEmpty) _chipInfo('Barbero', cita.nombreBarbero),
                  if (cita.nombreServicio.isNotEmpty) _chipInfo('Servicio', cita.nombreServicio),
                  if (cita.telefonoCliente.isNotEmpty) _chipInfo('Teléfono', cita.telefonoCliente),
                  _chipEstado(cita.estado),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipInfo(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $valor', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF3F434A))),
    );
  }
}
