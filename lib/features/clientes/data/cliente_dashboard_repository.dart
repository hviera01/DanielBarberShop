import '../../reportes/data/reporte_repository.dart';
import '../../reportes/data/reporte_venta_model.dart';

const _diasSemana = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];

class ClienteFrecuente {
  final String nombre;
  final int visitas;
  final DateTime? primeraVisita;
  final DateTime? ultimaVisita;

  ClienteFrecuente({required this.nombre, required this.visitas, required this.primeraVisita, required this.ultimaVisita});
}

class ClienteInactivo {
  final String nombre;
  final int visitasTotal;
  final DateTime ultimaVisita;
  final int diasSinVisitar;

  ClienteInactivo({required this.nombre, required this.visitasTotal, required this.ultimaVisita, required this.diasSinVisitar});
}

class PatronVisita {
  final String nombre;
  final String diaMasFrecuente;
  final int totalVisitas;

  PatronVisita({required this.nombre, required this.diaMasFrecuente, required this.totalVisitas});
}

class ClienteDashboardData {
  final List<ClienteFrecuente> frecuentes;
  final List<ClienteInactivo> inactivos;
  final List<PatronVisita> patrones;
  final List<String> recordatorios;

  ClienteDashboardData({required this.frecuentes, required this.inactivos, required this.patrones, required this.recordatorios});
}

/// Réplica del "Dashboard BI" del sistema viejo (modal dentro de la pantalla
/// de Clientes, con clientes frecuentes/inactivos, patrón de día de visita
/// y recordatorios), armada acá en memoria a partir de las ventas del
/// periodo en vez de con stored procedures.
class ClienteDashboardRepository {
  final _reporteRepository = ReporteRepository();

  String _clave(ReporteVentaModel v) {
    final doc = v.documentoCliente.trim();
    final nombre = v.nombreCliente.trim();
    return '${doc.isEmpty ? 'NO-DOC' : doc}|${nombre.isEmpty ? 'SIN NOMBRE' : nombre}';
  }

  String _nombreVisible(ReporteVentaModel v) => v.nombreCliente.trim().isEmpty ? 'SIN NOMBRE' : v.nombreCliente.trim();

  Future<ClienteDashboardData> obtenerDashboard({
    int mesesHistorial = 12,
    int topFrecuentes = 10,
    int semanasSinVisitar = 6,
    int minVisitasInactivo = 1,
    int minVisitasPatron = 3,
  }) async {
    final fin = DateTime.now();
    final inicio = DateTime(fin.year, fin.month - mesesHistorial, fin.day);
    final ventas = await _reporteRepository.obtenerReporteVentas(inicio, fin);
    final activas = ventas.where((v) => v.esActiva && !v.esCotizacion && v.fechaRegistro != null).toList();

    final porCliente = <String, List<ReporteVentaModel>>{};
    for (final v in activas) {
      porCliente.putIfAbsent(_clave(v), () => []).add(v);
    }

    final frecuentes = porCliente.entries.map((e) {
      final ventasCliente = e.value;
      final fechas = ventasCliente.map((v) => v.fechaRegistro!).toList()..sort();
      return ClienteFrecuente(
        nombre: _nombreVisible(ventasCliente.first),
        visitas: ventasCliente.length,
        primeraVisita: fechas.first,
        ultimaVisita: fechas.last,
      );
    }).toList()
      ..sort((a, b) => b.visitas.compareTo(a.visitas));

    final inactivos = porCliente.entries
        .map((e) {
          final ventasCliente = e.value;
          final ultimaVisita = ventasCliente.map((v) => v.fechaRegistro!).reduce((a, b) => a.isAfter(b) ? a : b);
          return ClienteInactivo(
            nombre: _nombreVisible(ventasCliente.first),
            visitasTotal: ventasCliente.length,
            ultimaVisita: ultimaVisita,
            diasSinVisitar: DateTime.now().difference(ultimaVisita).inDays,
          );
        })
        .where((c) => c.visitasTotal >= minVisitasInactivo && c.diasSinVisitar >= semanasSinVisitar * 7)
        .toList()
      ..sort((a, b) => b.diasSinVisitar.compareTo(a.diasSinVisitar));

    final patrones = porCliente.entries
        .map((e) {
          final ventasCliente = e.value;
          if (ventasCliente.length < minVisitasPatron) return null;
          final porDia = <int, int>{};
          for (final v in ventasCliente) {
            final dia = v.fechaRegistro!.weekday % 7; // weekday: 1=lunes..7=domingo -> 0=domingo..6=sábado
            porDia[dia] = (porDia[dia] ?? 0) + 1;
          }
          final diaTop = porDia.entries.reduce((a, b) => a.value >= b.value ? a : b);
          return PatronVisita(nombre: _nombreVisible(ventasCliente.first), diaMasFrecuente: _diasSemana[diaTop.key], totalVisitas: ventasCliente.length);
        })
        .whereType<PatronVisita>()
        .toList()
      ..sort((a, b) => b.totalVisitas.compareTo(a.totalVisitas));

    final recordatorios = <String>[
      ...patrones.take(10).map((p) => '${p.nombre} suele venir los ${p.diaMasFrecuente}.'),
      ...inactivos.take(10).map((c) => '${c.nombre} no visita desde hace ${c.diasSinVisitar} días.'),
    ];

    return ClienteDashboardData(
      frecuentes: frecuentes.take(topFrecuentes).toList(),
      inactivos: inactivos,
      patrones: patrones,
      recordatorios: recordatorios,
    );
  }
}
