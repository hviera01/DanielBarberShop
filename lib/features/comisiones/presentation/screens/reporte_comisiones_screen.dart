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
      final resultados = await Future.wait([
        repo.obtenerComisionCortes(inicioDelDia, finInclusive, idBarbero: _idBarberoFiltro),
        repo.obtenerComisionProductos(inicioDelDia, finInclusive),
      ]);
      if (!mounted) return;
      setState(() {
        _cortes = resultados[0] as List<ComisionCorteBarbero>;
        _productos = resultados[1] as List<ComisionProductoVendedor>;
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
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 800;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 14 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comisiones', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: esMovil ? constraints.maxWidth : 150, child: _campoFecha('Desde', _inicio, () => _elegirFecha(true))),
                    SizedBox(width: esMovil ? constraints.maxWidth : 150, child: _campoFecha('Hasta', _fin, () => _elegirFecha(false))),
                    SizedBox(width: esMovil ? constraints.maxWidth : 200, child: _selectorBarbero()),
                    OutlinedButton.icon(
                      onPressed: _cargando ? null : _cargar,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('Actualizar', style: GoogleFonts.poppins(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(color: Color(0xFFB6BCC7)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFAEB4C0))),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF0F1B3D),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF0F1B3D),
                    labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Cortes por barbero'),
                      Tab(text: 'Productos por vendedor'),
                      Tab(text: 'Global'),
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
      child: Text(texto, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: peso, color: gris ? Colors.grey.shade600 : const Color(0xFF1A1A1A))),
    );
  }

  Widget _vacio(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.paid_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(mensaje, style: GoogleFonts.poppins(color: Colors.grey.shade500)),
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

  Widget _vistaCortes(bool esMovil) {
    final lista = _cortes ?? [];
    if (lista.isEmpty) return _vacio('No hay comisiones de cortes en este periodo');
    final totalCortes = lista.fold<double>(0, (s, c) => s + c.cantidadCortes);
    final totalMonto = lista.fold<double>(0, (s, c) => s + c.montoTotal);
    final totalComision = lista.fold<double>(0, (s, c) => s + c.comisionTotal);
    return Column(
      children: [
        _encabezado(['BARBERO', 'CORTES', 'MONTO', 'COMISIÓN'], [3, 2, 2, 2]),
        Expanded(
          child: ListView.separated(
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
        _encabezado(['VENDEDOR', 'PRODUCTOS', 'MONTO', 'TASA', 'COMISIÓN'], [3, 2, 2, 1, 2]),
        Expanded(
          child: ListView.separated(
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
