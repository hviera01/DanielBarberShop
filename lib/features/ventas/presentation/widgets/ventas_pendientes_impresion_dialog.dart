import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/ventas_provider.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../screens/detalle_venta_screen.dart';

/// Lista de ventas guardadas pero sin imprimir (típicamente hechas desde el
/// celular sin la impresora térmica a mano). Tocar una abre su detalle,
/// desde donde se puede reimprimir o marcar como impresa.
class VentasPendientesImpresionDialog extends ConsumerWidget {
  const VentasPendientesImpresionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(ventasPendientesImpresionStreamProvider);
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 560;
    final anchoDialog = esMovil ? tamano.width - 24 : 520.0;
    final altoDialog = tamano.height < 640 ? tamano.height - 40 : 560.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: anchoDialog,
        height: altoDialog,
        padding: EdgeInsets.all(esMovil ? 16 : 22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Pendientes de Impresión', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ventasAsync.when(
                data: (ventas) {
                  if (ventas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.print_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text('No hay ventas pendientes de impresión', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: ventas.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final venta = ventas[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(fullscreenDialog: true, builder: (context) => DetalleVentaScreen(ventaIdInicial: venta.id)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFFFF8EC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0A63C))),
                          child: Row(
                            children: [
                              Icon(Icons.print_disabled_outlined, size: 20, color: Colors.amber.shade800),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      venta.nombreCliente.isEmpty ? 'Sin cliente' : venta.nombreCliente,
                                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${venta.tipoDocumento} · ${venta.numeroDocumento} · ${formatearMoneda(venta.totalAPagar)}',
                                      style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600),
                                    ),
                                    if (venta.fechaRegistro != null) ...[
                                      const SizedBox(height: 2),
                                      Text(formatoFecha.format(venta.fechaRegistro!), style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade400)),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC62828))),
                error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
