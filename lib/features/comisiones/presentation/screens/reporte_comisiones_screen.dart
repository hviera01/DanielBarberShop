import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/comision_model.dart';
import '../../data/comision_repository.dart';
import '../../../barberos/providers/barberos_provider.dart';
import '../../../../core/utils/formato_moneda.dart';

class ReporteComisionesScreen extends ConsumerStatefulWidget {
  const ReporteComisionesScreen({super.key});

  @override
  ConsumerState<ReporteComisionesScreen> createState() => _ReporteComisionesScreenState();
}

class _ReporteComisionesScreenState extends ConsumerState<ReporteComisionesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fin = DateTime.now();
  String? _idBarberoFiltro;

  List<ComisionCorteBarbero>? _cortes;
  List<ComisionProductoVendedor>? _productos;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ComisionRepository();
      final finInclusive = DateTime(_fin.year, _fin.month, _fin.day, 23, 59, 59);
      final inicioDelDia = DateTime(_inicio.year, _inicio.month, _inicio.day);
      final resultado = await repo.obtenerComisionesDelPeriodo(inicioDelDia, finInclusive, idBarbero: _idBarberoFiltro);
      if (!mounted) return;
      setState(() {
        _cortes = resultado.cortes;
        _productos = resultado.productos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // No dispara la búsqueda sola al elegir la fecha: hay que tocar "Buscar"
  // explícito (más predecible, sobre todo en celular con internet lento,
  // donde un cambio de fecha que dispara la consulta sola se puede sentir
  // como que "no pasó nada" si tarda).
  Future<void> _elegirFecha(bool esInicio) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: esInicio ? _inicio : _fin,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (elegida == null) return;
    setState(() {
      if (esInicio) {
        _inicio = elegida;
      } else {
        _fin = elegida;
      }
    });
  }

  // Vista de la tabla/tarjetas a pantalla completa, para cuando hay muchos
  // resultados y el espacio normal (compartido con los filtros y el
  // TabBar) se queda chico en el celular.
  void _expandirVista() {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: const Color(0xFFF2F3F7),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF0F1B3D),
                child: Row(
                  children: [
                    Expanded(child: Text('Comisiones', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF0F1B3D),
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: const Color(0xFF0F1B3D),
                  labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'Cortes'), Tab(text: 'Productos'), Tab(text: 'Global')],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_vistaCortes(true), _vistaProductos(true), _vistaGlobal(true)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 700;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 14 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Comisiones', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                    if (esMovil) ...[
                      const Spacer(),
                      IconButton(
                        tooltip: 'Ver la tabla más grande',
                        onPressed: _expandirVista,
                        icon: const Icon(Icons.open_in_full, size: 20, color: Color(0xFF0F1B3D)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('Elegí el rango de fechas y tocá Buscar', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: esMovil ? constraints.maxWidth : 150, child: _campoFecha('Desde', _inicio, () => _elegirFecha(true))),
                    SizedBox(width: esMovil ? constraints.maxWidth : 150, child: _campoFecha('Hasta', _fin, () => _elegirFecha(false))),
                    SizedBox(width: esMovil ? constraints.maxWidth : 200, child: _selectorBarbero()),
                    SizedBox(
                      width: esMovil ? constraints.maxWidth : null,
                      child: FilledButton.icon(
                        onPressed: _cargando ? null : _cargar,
                        icon: _cargando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search, size: 18),
                        label: Text('Buscar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F1B3D),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFAEB4C0))),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: esMovil,
                    tabAlignment: esMovil ? TabAlignment.start : null,
                    labelColor: const Color(0xFF0F1B3D),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF0F1B3D),
                    labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: esMovil ? 'Cortes' : 'Cortes por barbero'),
                      Tab(text: esMovil ? 'Productos' : 'Productos por vendedor'),
                      const Tab(text: 'Global'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFAEB4C0), width: 1.3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 12))],
                    ),
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F1B3D)))
                        : _error != null
                            ? Center(child: Text('Error: $_error', style: GoogleFonts.poppins(color: Colors.red)))
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  _vistaCortes(esMovil),
                                  _vistaProductos(esMovil),
                                  _vistaGlobal(esMovil),
                                ],
                              ),
                  ),
                ),
              ],
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
            Expanded(child: Text('$etiqueta: ${DateFormat('dd/MM/yyyy').format(valor)}', style: GoogleFonts.poppins(fontSize: 12.5))),
          ],
        ),
      ),
    );
  }

  Widget _selectorBarbero() {
    final barberosAsync = ref.watch(barberosStreamProvider);
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
            ...(barberosAsync.value ?? []).map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.nombreCompleto))),
          ],
          // El cambio de barbero sí actualiza al toque: es un filtro simple
          // (no una fecha que pida un diálogo aparte), no hace falta pasar
          // por el botón Buscar para sentirse responsivo.
          onChanged: (v) {
            setState(() => _idBarberoFiltro = v);
            _cargar();
          },
        ),
      ),
    );
  }

  Widget _encabezado(List<String> columnas, List<int> flexes) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFECEEF3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        children: List.generate(
          columnas.length,
          (i) => Expanded(
            flex: flexes[i],
            child: Text(columnas[i], style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF666A72), letterSpacing: 0.35)),
          ),
        ),
      ),
    );
  }

  Widget _celda(String texto, int flex, {FontWeight peso = FontWeight.w400, bool gris = false}) {
    return Expanded(
      flex: flex,
      child: Text(texto, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: peso, color: gris ? Colors.grey.shade600 : const Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _vacio(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.paid_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(mensaje, style: GoogleFonts.poppins(color: Colors.grey.shade500), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _totales(List<(String, String)> pares) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Wrap(
        spacing: 24,
        runSpacing: 6,
        children: pares
            .map((p) => Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${p.$1}: ', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade700)),
                    TextSpan(text: p.$2, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F1B3D))),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ---------- Tarjetas para móvil (una card por persona, en vez de una
  // fila de tabla angosta con 4-5 columnas apretadas) ----------

  Widget _tarjetaPersona({required String titulo, required List<(String, String)> filas, required String comision}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E2E8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: filas
                .map((f) => Text.rich(TextSpan(children: [
                      TextSpan(text: '${f.$1}: ', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
                      TextSpan(text: f.$2, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                    ])))
                .toList(),
          ),
          const SizedBox(height: 6),
          Text('Comisión: $comision', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F1B3D))),
        ],
      ),
    );
  }

  Widget _vistaCortes(bool esMovil) {
    final lista = _cortes ?? [];
    if (lista.isEmpty) return _vacio('No hay comisiones de cortes en este periodo');
    final totalCortes = lista.fold<double>(0, (s, c) => s + c.cantidadCortes);
    final totalMonto = lista.fold<double>(0, (s, c) => s + c.montoTotal);
    final totalComision = lista.fold<double>(0, (s, c) => s + c.comisionTotal);
    return Column(
      children: [
        if (!esMovil) _encabezado(['BARBERO', 'CORTES', 'MONTO', 'COMISIÓN'], [3, 2, 2, 2]),
        Expanded(
          child: esMovil
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return _tarjetaPersona(
                      titulo: c.nombreBarbero.isEmpty ? '-' : c.nombreBarbero,
                      filas: [('Cortes', c.cantidadCortes.toStringAsFixed(0)), ('Monto', formatearMoneda(c.montoTotal))],
                      comision: formatearMoneda(c.comisionTotal),
                    );
                  },
                )
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _celda(c.nombreBarbero.isEmpty ? '-' : c.nombreBarbero, 3, peso: FontWeight.w600),
                          _celda(c.cantidadCortes.toStringAsFixed(0), 2, gris: true),
                          _celda(formatearMoneda(c.montoTotal), 2, gris: true),
                          _celda(formatearMoneda(c.comisionTotal), 2, peso: FontWeight.w700),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _totales([('Total cortes', totalCortes.toStringAsFixed(0)), ('Total monto', formatearMoneda(totalMonto)), ('Total comisión', formatearMoneda(totalComision))]),
      ],
    );
  }

  Widget _vistaProductos(bool esMovil) {
    final lista = _productos ?? [];
    if (lista.isEmpty) return _vacio('No hay comisiones de productos en este periodo');
    final totalProductos = lista.fold<double>(0, (s, c) => s + c.cantidadProductos);
    final totalMonto = lista.fold<double>(0, (s, c) => s + c.montoTotal);
    final totalComision = lista.fold<double>(0, (s, c) => s + c.comisionTotal);
    return Column(
      children: [
        if (!esMovil) _encabezado(['VENDEDOR', 'PRODUCTOS', 'MONTO', 'TASA', 'COMISIÓN'], [3, 2, 2, 1, 2]),
        Expanded(
          child: esMovil
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return _tarjetaPersona(
                      titulo: '${c.nombre} (${c.tipo})',
                      filas: [('Productos', c.cantidadProductos.toStringAsFixed(0)), ('Monto', formatearMoneda(c.montoTotal)), ('Tasa', '${(c.tasa * 100).toStringAsFixed(0)}%')],
                      comision: formatearMoneda(c.comisionTotal),
                    );
                  },
                )
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _celda('${c.nombre} (${c.tipo})', 3, peso: FontWeight.w600),
                          _celda(c.cantidadProductos.toStringAsFixed(0), 2, gris: true),
                          _celda(formatearMoneda(c.montoTotal), 2, gris: true),
                          _celda('${(c.tasa * 100).toStringAsFixed(0)}%', 1, gris: true),
                          _celda(formatearMoneda(c.comisionTotal), 2, peso: FontWeight.w700),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _totales([('Total productos', totalProductos.toStringAsFixed(0)), ('Total monto', formatearMoneda(totalMonto)), ('Total comisión', formatearMoneda(totalComision))]),
      ],
    );
  }

  Widget _vistaGlobal(bool esMovil) {
    final cortes = _cortes ?? [];
    final productos = _productos ?? [];
    if (cortes.isEmpty && productos.isEmpty) return _vacio('No hay comisiones en este periodo');
    final totalComision = cortes.fold<double>(0, (s, c) => s + c.comisionTotal) + productos.fold<double>(0, (s, c) => s + c.comisionTotal);
    if (esMovil) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...cortes.map((c) => _tarjetaPersona(
                      titulo: '✂️ ${c.nombreBarbero.isEmpty ? '-' : c.nombreBarbero}',
                      filas: [('Cortes', c.cantidadCortes.toStringAsFixed(0)), ('Monto', formatearMoneda(c.montoTotal))],
                      comision: formatearMoneda(c.comisionTotal),
                    )),
                ...productos.map((c) => _tarjetaPersona(
                      titulo: '🛒 ${c.nombre} (${c.tipo})',
                      filas: [('Productos', c.cantidadProductos.toStringAsFixed(0)), ('Monto', formatearMoneda(c.montoTotal))],
                      comision: formatearMoneda(c.comisionTotal),
                    )),
              ],
            ),
          ),
          _totales([('Total a pagar en comisiones', formatearMoneda(totalComision))]),
        ],
      );
    }
    return Column(
      children: [
        _encabezado(['TIPO', 'PERSONA', 'CANTIDAD', 'MONTO', 'COMISIÓN'], [1, 3, 2, 2, 2]),
        Expanded(
          child: ListView(
            children: [
              ...cortes.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _celda('Corte', 1, gris: true),
                        _celda(c.nombreBarbero.isEmpty ? '-' : c.nombreBarbero, 3, peso: FontWeight.w600),
                        _celda(c.cantidadCortes.toStringAsFixed(0), 2, gris: true),
                        _celda(formatearMoneda(c.montoTotal), 2, gris: true),
                        _celda(formatearMoneda(c.comisionTotal), 2, peso: FontWeight.w700),
                      ],
                    ),
                  )),
              if (cortes.isNotEmpty && productos.isNotEmpty) Divider(height: 1, color: Colors.grey.shade300),
              ...productos.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _celda('Producto', 1, gris: true),
                        _celda('${c.nombre} (${c.tipo})', 3, peso: FontWeight.w600),
                        _celda(c.cantidadProductos.toStringAsFixed(0), 2, gris: true),
                        _celda(formatearMoneda(c.montoTotal), 2, gris: true),
                        _celda(formatearMoneda(c.comisionTotal), 2, peso: FontWeight.w700),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        _totales([('Total a pagar en comisiones', formatearMoneda(totalComision))]),
      ],
    );
  }
}
