import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/cliente_dashboard_repository.dart';

/// Réplica del "Dashboard" que el sistema viejo mostraba desde dentro de la
/// pantalla de Clientes: clientes frecuentes, inactivos, patrón de día de
/// visita y recordatorios en texto — todo calculado sobre el último año de
/// ventas.
class ClienteDashboardDialog extends StatefulWidget {
  const ClienteDashboardDialog({super.key});

  @override
  State<ClienteDashboardDialog> createState() => _ClienteDashboardDialogState();
}

class _ClienteDashboardDialogState extends State<ClienteDashboardDialog> {
  late Future<ClienteDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = ClienteDashboardRepository().obtenerDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 720;
    final anchoDialog = esMovil ? tamano.width - 24 : 760.0;
    final altoDialog = tamano.height < 640 ? tamano.height - 40 : 620.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: anchoDialog,
        height: altoDialog,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Panel de Clientes', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Text('Calculado sobre el último año de ventas activas', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<ClienteDashboardData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0F1B3D)));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}', style: GoogleFonts.poppins(color: Colors.red)));
                  }
                  final data = snap.data!;
                  final tarjetas = [
                    _tarjetaFrecuentes(data),
                    _tarjetaInactivos(data),
                    _tarjetaPatrones(data),
                    _tarjetaRecordatorios(data),
                  ];
                  return GridView.count(
                    crossAxisCount: esMovil ? 1 : 2,
                    childAspectRatio: esMovil ? 1.6 : 1.3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    children: tarjetas,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta({required String titulo, required IconData icono, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E2E8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(icono, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(titulo, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)))),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _listaVacia(String mensaje) {
    return Center(child: Text(mensaje, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500), textAlign: TextAlign.center));
  }

  Widget _tarjetaFrecuentes(ClienteDashboardData data) {
    return _tarjeta(
      titulo: 'Clientes frecuentes',
      icono: Icons.star_outline,
      color: const Color(0xFFF59E0B),
      child: data.frecuentes.isEmpty
          ? _listaVacia('Sin datos suficientes todavía')
          : ListView.builder(
              itemCount: data.frecuentes.length,
              itemBuilder: (context, i) {
                final c = data.frecuentes[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.nombre, style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      Text('${c.visitas} visitas', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _tarjetaInactivos(ClienteDashboardData data) {
    return _tarjeta(
      titulo: 'Clientes inactivos',
      icono: Icons.person_off_outlined,
      color: const Color(0xFFDC2626),
      child: data.inactivos.isEmpty
          ? _listaVacia('No hay clientes que dejaron de venir')
          : ListView.builder(
              itemCount: data.inactivos.length,
              itemBuilder: (context, i) {
                final c = data.inactivos[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.nombre, style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      Text('${c.diasSinVisitar} días', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _tarjetaPatrones(ClienteDashboardData data) {
    return _tarjeta(
      titulo: 'Patrón de visita',
      icono: Icons.calendar_month_outlined,
      color: const Color(0xFF3B82F6),
      child: data.patrones.isEmpty
          ? _listaVacia('Todavía no hay suficientes visitas repetidas')
          : ListView.builder(
              itemCount: data.patrones.length,
              itemBuilder: (context, i) {
                final p = data.patrones[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.nombre, style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      Text(p.diaMasFrecuente, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _tarjetaRecordatorios(ClienteDashboardData data) {
    return _tarjeta(
      titulo: 'Recordatorios',
      icono: Icons.notifications_outlined,
      color: const Color(0xFF14B8A6),
      child: data.recordatorios.isEmpty
          ? _listaVacia('Sin recordatorios por ahora')
          : ListView.builder(
              itemCount: data.recordatorios.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• ${data.recordatorios[i]}', style: GoogleFonts.poppins(fontSize: 11.5)),
              ),
            ),
    );
  }
}
