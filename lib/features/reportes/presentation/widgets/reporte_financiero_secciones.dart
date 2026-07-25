import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/reporte_financiero_model.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../../../../core/widgets/pdf_preview_dialog.dart';
import '../../../caja/data/cierre_caja_model.dart';
import '../../../caja/data/caja_export_service.dart';
import '../../../negocio/providers/negocio_provider.dart';
import '../../../ventas/presentation/screens/detalle_venta_screen.dart';

void _abrirDetalleVenta(BuildContext context, String idVenta) {
  Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (context) => DetalleVentaScreen(ventaIdInicial: idVenta)),
  );
}

const colorVentasFinanciero = Color(0xFF0F1B3D);
const colorComprasFinanciero = Color(0xFFF59E0B);
const _paletaUsuarios = [Color(0xFF0F1B3D), Color(0xFF0EA5A4), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF22C55E)];
const _colorOtros = Color(0xFF64748B);

String formatoCantidadFinanciero(double cantidad) {
  if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
  return cantidad.toStringAsFixed(2);
}

Widget _tarjeta({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFC7CBD3)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: child,
  );
}

Widget _explicacion(String texto) {
  return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(texto, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)));
}

Widget _stat(String titulo, double valor, Color color, {String? sub}) {
  return Container(
    width: 210,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))]),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(formatearMoneda(valor), style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
        if (sub != null) Text(sub, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.85))),
      ],
    ),
  );
}

Widget _flechaOperacion(IconData icono) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Icon(icono, color: Colors.grey.shade400, size: 22),
  );
}

Widget _filaValor(String etiqueta, double valor) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(etiqueta.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.4)),
      Text(formatearMoneda(valor), style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
    ],
  );
}

Widget _leyenda(String texto, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(texto, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
    ],
  );
}

// ---------- Utilidad Bruta y Neta ----------

Widget seccionUtilidad(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final filaBruta = Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    runSpacing: 10,
    children: [
      _stat('Ventas', data.ventasPeriodo, colorVentasFinanciero),
      _flechaOperacion(Icons.remove),
      _stat('Costo de Ventas', data.costoVentas, const Color(0xFF64748B)),
      _flechaOperacion(Icons.drag_handle),
      _stat('Utilidad Bruta', data.utilidadBruta, const Color(0xFF16A34A), sub: '${data.margenBrutoPorcentaje.toStringAsFixed(1)}% margen'),
    ],
  );
  final filaNeta = Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    runSpacing: 10,
    children: [
      _stat('Utilidad Bruta', data.utilidadBruta, const Color(0xFF16A34A)),
      _flechaOperacion(Icons.remove),
      _stat('Gastos (Egresos)', data.gastosPeriodo, const Color(0xFF64748B)),
      _flechaOperacion(Icons.drag_handle),
      _stat('Utilidad Neta', data.utilidadNeta, data.utilidadNeta >= 0 ? const Color(0xFF16A34A) : const Color(0xFF0F1B3D)),
    ],
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Utilidad bruta: lo que dejan las ventas después de su costo. Utilidad neta: la utilidad bruta después de los gastos operativos registrados en Egresos.'),
      Text('VENTAS − COSTOS = UTILIDAD BRUTA', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3)),
      const SizedBox(height: 10),
      filaBruta,
      const SizedBox(height: 20),
      Text('UTILIDAD BRUTA − GASTOS = UTILIDAD NETA', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3)),
      const SizedBox(height: 10),
      filaNeta,
      const SizedBox(height: 24),
      _ServiciosProductosDetalle(resumen: data.resumenServiciosProductos, gananciaGeneral: data.gananciaPorVenta, esMovil: esMovil),
    ],
  );
}

// Recuadros de Servicios/Productos con venta, costo y utilidad explícitos
// (no solo "utilidad" como subtítulo), y tocables: por defecto la tabla de
// abajo muestra la Ganancia por Venta general (todas las ventas, como
// estaba); tocar un recuadro la filtra a solo las ventas que tuvieron ese
// tipo (servicio o producto), mostrando lo que dejó esa parte de la venta.
class _ServiciosProductosDetalle extends StatefulWidget {
  final ResumenServiciosProductos resumen;
  final List<GananciaPorVenta> gananciaGeneral;
  final bool esMovil;

  const _ServiciosProductosDetalle({required this.resumen, required this.gananciaGeneral, required this.esMovil});

  @override
  State<_ServiciosProductosDetalle> createState() => _ServiciosProductosDetalleState();
}

class _ServiciosProductosDetalleState extends State<_ServiciosProductosDetalle> {
  // null = sin filtro (ganancia general), true = solo servicios, false = solo productos.
  bool? _filtroServicio;

  @override
  Widget build(BuildContext context) {
    final resumen = widget.resumen;
    late final List<GananciaPorVenta> lista;
    late final String titulo;
    late final String explicacion;
    if (_filtroServicio == null) {
      lista = widget.gananciaGeneral;
      titulo = 'Ganancia por Venta';
      explicacion = 'Cada venta individual del periodo, con su costo y ganancia. Tocá una fila para ver el detalle.';
    } else if (_filtroServicio == true) {
      lista = _agruparPorVentaFiltrado(resumen.detalle, esServicio: true);
      titulo = 'Ventas de Servicios';
      explicacion = 'Solo lo que dejaron los servicios dentro de cada venta. Tocá una fila para ver el detalle.';
    } else {
      lista = _agruparPorVentaFiltrado(resumen.detalle, esServicio: false);
      titulo = 'Ventas de Productos';
      explicacion = 'Solo lo que dejaron los productos físicos dentro de cada venta. Tocá una fila para ver el detalle.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Servicios vs. Productos', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('Son dos negocios con márgenes muy distintos. Tocá una tarjeta para filtrar la tabla de abajo.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _statTriple(
              titulo: 'Servicios (cortes)',
              ventas: resumen.ventasServicios,
              costo: resumen.costoServicios,
              utilidad: resumen.utilidadServicios,
              color: const Color(0xFF14B8A6),
              seleccionado: _filtroServicio == true,
              onTap: () => setState(() => _filtroServicio = _filtroServicio == true ? null : true),
            ),
            _statTriple(
              titulo: 'Productos',
              ventas: resumen.ventasProductos,
              costo: resumen.costoProductos,
              utilidad: resumen.utilidadProductos,
              color: const Color(0xFF64748B),
              seleccionado: _filtroServicio == false,
              onTap: () => setState(() => _filtroServicio = _filtroServicio == false ? null : false),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(titulo, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(explicacion, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 10),
        _tabaGananciaPorVenta(context, lista, widget.esMovil),
      ],
    );
  }
}

Widget _statTriple({
  required String titulo,
  required double ventas,
  required double costo,
  required double utilidad,
  required Color color,
  required bool seleccionado,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: seleccionado ? Border.all(color: Colors.white, width: 2.5) : null,
        boxShadow: [BoxShadow(color: color.withOpacity(seleccionado ? 0.45 : 0.3), blurRadius: seleccionado ? 22 : 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 0.5))),
              Icon(seleccionado ? Icons.filter_alt : Icons.filter_alt_outlined, size: 14, color: Colors.white.withOpacity(0.85)),
            ],
          ),
          const SizedBox(height: 8),
          _filaStatTriple('Vendido', ventas),
          _filaStatTriple('Costo', costo),
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, color: Colors.white.withOpacity(0.3))),
          _filaStatTriple('Utilidad', utilidad, negrita: true),
        ],
      ),
    ),
  );
}

Widget _filaStatTriple(String etiqueta, double valor, {bool negrita = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.85))),
        Text(formatearMoneda(valor), style: GoogleFonts.poppins(fontSize: negrita ? 15 : 12.5, fontWeight: negrita ? FontWeight.w800 : FontWeight.w600, color: Colors.white)),
      ],
    ),
  );
}

// Colapsa el detalle línea-por-línea (servicio o producto) del tipo pedido
// a nivel de venta, sumando venta/costo de esas líneas por idVenta -mismas
// columnas que GananciaPorVenta, para poder reusar _tabaGananciaPorVenta.
List<GananciaPorVenta> _agruparPorVentaFiltrado(List<DetalleItemFinanciero> detalle, {required bool esServicio}) {
  final ventaPorId = <String, double>{};
  final costoPorId = <String, double>{};
  final infoPorId = <String, (String numeroDocumento, DateTime? fecha, String cliente)>{};
  for (final d in detalle.where((d) => d.esServicio == esServicio)) {
    ventaPorId[d.idVenta] = (ventaPorId[d.idVenta] ?? 0) + d.venta;
    costoPorId[d.idVenta] = (costoPorId[d.idVenta] ?? 0) + d.costo;
    infoPorId[d.idVenta] = (d.numeroDocumento, d.fecha, d.cliente);
  }
  final lista = ventaPorId.keys
      .map((id) {
        final info = infoPorId[id]!;
        return GananciaPorVenta(idVenta: id, numeroDocumento: info.$1, fecha: info.$2, cliente: info.$3, ventas: ventaPorId[id]!, costo: costoPorId[id]!);
      })
      .toList()
    ..sort((a, b) => (b.fecha ?? DateTime(2000)).compareTo(a.fecha ?? DateTime(2000)));
  return lista;
}

Widget _tabaGananciaPorVenta(BuildContext context, List<GananciaPorVenta> lista, bool esMovil) {
  if (lista.isEmpty) {
    return _tarjeta(child: Text('Sin ventas en el rango seleccionado.', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)));
  }
  final formatoFecha = DateFormat('dd/MM/yyyy');
  return _tarjeta(
    child: Column(
      children: [
        Row(
          children: [
            SizedBox(width: 90, child: Text('FECHA', style: _estiloHeaderTabla())),
            Expanded(flex: 2, child: Text('DOCUMENTO / CLIENTE', style: _estiloHeaderTabla())),
            if (!esMovil) Expanded(child: Text('VENTAS', textAlign: TextAlign.right, style: _estiloHeaderTabla())),
            if (!esMovil) Expanded(child: Text('COSTO', textAlign: TextAlign.right, style: _estiloHeaderTabla())),
            Expanded(child: Text('GANANCIA', textAlign: TextAlign.right, style: _estiloHeaderTabla())),
            SizedBox(width: 55, child: Text('MARGEN', textAlign: TextAlign.right, style: _estiloHeaderTabla())),
          ],
        ),
        Divider(height: 16, color: Colors.grey.shade300),
        for (final v in lista.take(50)) ...[
          InkWell(
            onTap: () => _abrirDetalleVenta(context, v.idVenta),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(v.fecha != null ? formatoFecha.format(v.fecha!) : '-', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600))),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(v.numeroDocumento, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(v.cliente, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (!esMovil) Expanded(child: Text(formatearMoneda(v.ventas), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12))),
                  if (!esMovil) Expanded(child: Text(formatearMoneda(v.costo), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600))),
                  Expanded(child: Text(formatearMoneda(v.ganancia), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: v.ganancia >= 0 ? const Color(0xFF16A34A) : const Color(0xFF0F1B3D)))),
                  SizedBox(width: 55, child: Text('${v.margenPorcentaje.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600))),
                ],
              ),
            ),
          ),
          if (v != lista.take(50).last) Divider(height: 1, color: Colors.grey.shade200),
        ],
        if (lista.length > 50) Padding(padding: const EdgeInsets.only(top: 10), child: Text('+ ${lista.length - 50} más...', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500))),
      ],
    ),
  );
}

TextStyle _estiloHeaderTabla() => GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3);

// ---------- Flujo de Efectivo ----------

Widget seccionFlujoEfectivo(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final flujo = data.flujoEfectivo;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Lo efectivamente cobrado y pagado en el periodo — no es lo mismo que la utilidad (esa mide lo vendido, esta mide lo cobrado).'),
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _filaValor('Ingresos (Efectivo)', flujo.ingresosEfectivo),
                _filaValor('Ingresos (Tarjeta)', flujo.ingresosTarjeta),
                _filaValor('Ingresos (Transferencia)', flujo.ingresosTransferencia),
                _filaValor('Egresos (Efectivo)', flujo.egresosEfectivo),
                _filaValor('Egresos (Transferencia)', flujo.egresosTransferencia),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(color: flujo.neto >= 0 ? const Color(0xFF16A34A) : const Color(0xFF0F1B3D), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FLUJO NETO', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(formatearMoneda(flujo.neto), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ---------- Comparación mensual ----------

Widget seccionComparacionMensual(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final serie = data.serieMensual;
  final maximo = serie.fold<double>(0, (m, p) => [m, p.totalVentas, p.totalCompras].reduce((a, b) => a > b ? a : b));
  final formatoMes = DateFormat('MMM yy', 'es');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Ventas y compras de los últimos 6 meses, terminando en el mes actual (independiente del rango de fechas de arriba).'),
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_leyenda('Ventas', colorVentasFinanciero), const SizedBox(width: 16), _leyenda('Compras', colorComprasFinanciero)]),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maximo <= 0 ? 100 : maximo * 1.15,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(formatearMoneda(rod.toY), GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= serie.length) return const SizedBox();
                          return Padding(padding: const EdgeInsets.only(top: 8), child: Text(formatoMes.format(serie[i].mes), style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade600)));
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < serie.length; i++)
                      BarChartGroupData(x: i, barsSpace: 4, barRods: [
                        BarChartRodData(toY: serie[i].totalVentas, color: colorVentasFinanciero, width: 12, borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: serie[i].totalCompras, color: colorComprasFinanciero, width: 12, borderRadius: BorderRadius.circular(4)),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final p in serie)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(formatoMes.format(p.mes), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Ventas: ${formatearMoneda(p.totalVentas)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700))),
                    Expanded(child: Text('Compras: ${formatearMoneda(p.totalCompras)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

// ---------- Ranking de productos ----------

Widget seccionRankingProductos(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final columnas = [
    _tablaRanking('Más vendidos (cantidad)', data.topVendidosPorCantidad, esCantidad: true),
    _tablaRanking('Más comprados (cantidad)', data.topCompradosPorCantidad, esCantidad: true),
    _tablaRanking('Mayor ganancia', data.topGananciaPorProducto, esCantidad: false),
  ];
  final grilla = esMovil
      ? Column(children: [for (final c in columnas) Padding(padding: const EdgeInsets.only(bottom: 14), child: c)])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in columnas) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))]);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_explicacion('Top 10 de todo el rango de fechas seleccionado.'), grilla],
  );
}

Widget _tablaRanking(String titulo, List<RankingProducto> lista, {required bool esCantidad}) {
  final maximo = lista.isEmpty ? 1.0 : (esCantidad ? lista.first.cantidad : lista.first.monto).abs();
  return _tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (lista.isEmpty) Text('Sin datos en el rango', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        for (final item in lista) _filaRanking(item, maximo, esCantidad: esCantidad),
      ],
    ),
  );
}

Widget _filaRanking(RankingProducto item, double maximo, {required bool esCantidad}) {
  final valor = esCantidad ? item.cantidad : item.monto;
  final proporcion = maximo <= 0 ? 0.0 : (valor.abs() / maximo).clamp(0.0, 1.0);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(item.nombreProducto, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Text(esCantidad ? formatoCantidadFinanciero(valor) : formatearMoneda(valor), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: proporcion, minHeight: 6, backgroundColor: const Color(0xFFF0F1F5), color: colorVentasFinanciero),
        ),
      ],
    ),
  );
}

// ---------- Productos sin venta ----------

Widget seccionProductosSinVenta(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final lista = data.productosSinVenta;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Productos activos que no tuvieron ninguna venta en el rango de fechas seleccionado.'),
      _tarjeta(
        child: lista.isEmpty
            ? Text('Todos los productos activos tuvieron al menos una venta en el rango.', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${lista.length} producto(s) sin movimiento — valor total en inventario: ${formatearMoneda(lista.fold<double>(0, (s, p) => s + p.valorInventario))}',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  for (final p in lista.take(30))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(p.nombreProducto, style: GoogleFonts.poppins(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                          SizedBox(width: 90, child: Text('Stock: ${formatoCantidadFinanciero(p.stock)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600))),
                          SizedBox(width: 110, child: Text(formatearMoneda(p.valorInventario), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  if (lista.length > 30) Padding(padding: const EdgeInsets.only(top: 8), child: Text('+ ${lista.length - 30} más...', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500))),
                ],
              ),
      ),
    ],
  );
}

// ---------- Ventas por usuario ----------

Widget seccionVentasPorUsuario(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final lista = data.ventasPorUsuario;
  if (lista.isEmpty) {
    return _tarjeta(child: Text('Sin ventas en el rango seleccionado.', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)));
  }
  final top = lista.take(5).toList();
  final resto = lista.skip(5).toList();
  final otrosTotal = resto.fold<double>(0, (s, u) => s + u.totalVentas);
  final total = lista.fold<double>(0, (s, u) => s + u.totalVentas);

  final segmentos = <MapEntry<String, double>>[
    for (final u in top) MapEntry(u.usuario, u.totalVentas),
    if (otrosTotal > 0) MapEntry('Otros', otrosTotal),
  ];

  final grafico = SizedBox(
    height: 180,
    width: 180,
    child: PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          for (var i = 0; i < segmentos.length; i++)
            PieChartSectionData(
              value: segmentos[i].value,
              color: i < top.length ? _paletaUsuarios[i % _paletaUsuarios.length] : _colorOtros,
              title: total <= 0 ? '' : '${(segmentos[i].value / total * 100).toStringAsFixed(0)}%',
              titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              radius: 55,
            ),
        ],
      ),
    ),
  );

  final tabla = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < lista.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: i < top.length ? _paletaUsuarios[i % _paletaUsuarios.length] : _colorOtros, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(lista[i].usuario, style: GoogleFonts.poppins(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
              Text('${lista[i].cantidadTransacciones} vtas.', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: Text(formatearMoneda(lista[i].totalVentas), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
    ],
  );

  return _tarjeta(
    child: esMovil
        ? Column(children: [Center(child: grafico), const SizedBox(height: 16), tabla])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [grafico, const SizedBox(width: 24), Expanded(child: tabla)]),
  );
}

// ---------- Abonos a compras crédito ----------

Widget seccionAbonosComprasCredito(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Total enviado a proveedores como abono de compras a crédito en el rango seleccionado.'),
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL ABONADO A PROVEEDORES', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(formatearMoneda(data.totalAbonosComprasCredito), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
            if (data.abonosPorProveedor.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final a in data.abonosPorProveedor)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(child: Text(a.proveedor, style: GoogleFonts.poppins(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                      Text(formatearMoneda(a.total), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

// ---------- Balance general ----------

Widget seccionBalanceGeneral(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final b = data.balanceGeneral;
  final activos = _tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACTIVOS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A), letterSpacing: 0.4)),
        const SizedBox(height: 10),
        _filaBalance('Inventario a costo', b.inventarioACosto),
        _filaBalance('Cuentas por cobrar', b.cuentasPorCobrar),
        _filaBalance('Efectivo estimado', b.efectivoEstimado),
        const Divider(height: 20),
        _filaBalance('Total Activos', b.totalActivos, negrita: true),
      ],
    ),
  );
  final pasivosYPatrimonio = _tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PASIVOS Y PATRIMONIO', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F1B3D), letterSpacing: 0.4)),
        const SizedBox(height: 10),
        _filaBalance('Cuentas por pagar', b.cuentasPorPagar),
        _filaBalance('Patrimonio (estimado)', b.patrimonio),
        const Divider(height: 20),
        _filaBalance('Total Pasivos + Patrimonio', b.totalPasivos + b.patrimonio, negrita: true),
      ],
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Aproximación con los datos disponibles: no reemplaza un balance contable formal (no incluye activos fijos ni capital aportado).'),
      esMovil
          ? Column(children: [activos, const SizedBox(height: 12), pasivosYPatrimonio])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: activos), const SizedBox(width: 12), Expanded(child: pasivosYPatrimonio)]),
    ],
  );
}

Widget _filaBalance(String etiqueta, double valor, {bool negrita = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: negrita ? FontWeight.w700 : FontWeight.w400)),
        Text(formatearMoneda(valor), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: negrita ? FontWeight.w800 : FontWeight.w600)),
      ],
    ),
  );
}

// ---------- Cierres de Caja ----------

Widget seccionCierresCaja(BuildContext context, ReporteFinancieroData data, bool esMovil) {
  final lista = data.cierresCaja;
  final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _explicacion('Cierres de caja registrados en el rango de fechas seleccionado (por fecha de cierre). Tocá uno para ver su detalle completo.'),
      if (lista.isEmpty)
        _tarjeta(child: Text('Sin cierres de caja en el rango seleccionado.', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)))
      else
        _tarjeta(
          child: Column(
            children: [
              for (final c in lista) ...[
                InkWell(
                  onTap: () => _abrirDetalleCierre(context, c),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatoFecha.format(c.fechaFin), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              Text(c.usuarioResponsable.isEmpty ? '-' : c.usuarioResponsable, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (!esMovil) Expanded(child: Text('Gran total: ${formatearMoneda(c.granTotal)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600))),
                        Expanded(
                          child: Text(
                            'Diferencia: ${formatearMoneda(c.diferencia)}',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: c.diferencia == 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                if (c != lista.last) Divider(height: 1, color: Colors.grey.shade200),
              ],
            ],
          ),
        ),
    ],
  );
}

Widget _filaTexto(String etiqueta, String valor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: GoogleFonts.poppins(fontSize: 12.5)),
        Text(valor, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

void _descargarPdfCierre(BuildContext context, CierreCajaModel c) {
  final negocioRepository = ProviderScope.containerOf(context, listen: false).read(negocioRepositoryProvider);
  showDialog(
    context: context,
    builder: (context) => PdfPreviewDialog(
      titulo: 'Vista previa · Cierre de Caja',
      nombreArchivo: 'cierre_caja.pdf',
      generarPdf: () async {
        final negocio = await negocioRepository.obtenerNegocioActual();
        return CajaExportService().generarPdfCierre(c, negocio);
      },
    ),
  );
}

void _abrirDetalleCierre(BuildContext context, CierreCajaModel c) {
  final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              decoration: const BoxDecoration(color: Color(0xFF0F1B3D), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Cierre de caja · ${formatoFecha.format(c.fechaFin)}', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  IconButton(
                    tooltip: 'Descargar PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
                    onPressed: () => _descargarPdfCierre(context, c),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filaTexto('Periodo desde', formatoFecha.format(c.fechaInicio)),
                    _filaTexto('Periodo hasta', formatoFecha.format(c.fechaFin)),
                    const Divider(height: 22),
                    _filaBalance('Monto inicial', c.montoInicial),
                    _filaBalance('Ingreso efectivo', c.ingresosEfectivo),
                    _filaBalance('Ingreso tarjeta', c.ingresosTarjeta),
                    _filaBalance('Ingreso transferencia', c.ingresosTransferencia),
                    _filaBalance('Egreso efectivo', c.egresosEfectivo),
                    _filaBalance('Egreso transferencia', c.egresosTransferencia),
                    const Divider(height: 22),
                    _filaBalance('Total calculado (efectivo)', c.totalCalculadoEfectivo),
                    _filaBalance('Total transferencia', c.totalTransferencia),
                    _filaBalance('Gran total', c.granTotal, negrita: true),
                    _filaBalance('Total real contado', c.totalReal, negrita: true),
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Diferencia', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(
                          formatearMoneda(c.diferencia),
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: c.diferencia == 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                    Text('Responsable: ${c.usuarioResponsable.isEmpty ? '-' : c.usuarioResponsable}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                    if (c.observaciones.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Observaciones', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                      Text(c.observaciones, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade700)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
